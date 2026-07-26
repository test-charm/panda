# Tick 路径边缘行为 — 测试设计文档

> 功能: `fan_tick()` has_fan=false 分支、`heartbeat_counter` 溢出封顶、`safety_mode_cnt` 溢出回绕、harness reinit 路径
> 被测路径: `board/drivers/fan.h:22`, `board/main.c:144-152` (8Hz), `board/main.c:179-181,257` (1Hz)
> 实现来源: 真实 `board/main.c` + `board/drivers/fan.h` (e2e include 生产代码)
> 新增 JNA: `jna_set_heartbeat_counter`, `jna_set_safety_mode_cnt`, `jna_get_safety_mode_cnt`

## 1. 被测功能数据流

### 1.1 has_fan=false → fan_tick() 体被跳过

```
fan_tick()  (8Hz, 每 tick 调用)
    │
    ▼
current_board->has_fan?
    ├── true  (cuatro/tres) → RPM 测量、cooldown 递减、PWM 输出
    └── false (red)         → 全部跳过, fan_state 不变  ← TC1
```

### 1.2 heartbeat_counter 溢出封顶

```
1Hz tick (每 8 次 jna_call_tick_handler)
    │
    ▼
heartbeat_counter < UINT32_MAX?
    ├── true  → heartbeat_counter += 1  (正常递增)  ← TC3
    └── false → 不递增, 封顶在 UINT32_MAX           ← TC2
```

### 1.3 safety_mode_cnt 溢出回绕

```
1Hz tick (每 8 次 jna_call_tick_handler)
    │
    ▼
safety_mode_cnt += 1U   (无符号回绕, UINT32_MAX + 1 → 0)  ← TC4
```

### 1.4 harness reinit 路径

```
tick_handler()  (8Hz)
    │
    ▼
harness.status != prev_harness_status?
    ├── false → 无操作
    └── true  →                                        ← TC5, TC6
         │
         ├── prev_harness_status = harness.status
         ├── can_set_orientation(...)
         ├── can_init_all()
         ├── set_safety_mode(current_safety_mode, ...)  → 重置 heartbeat_counter = 0
         │                                                (car safety mode 下)
         └── set_power_save_state(power_save_enabled)   → 幂等调用
              (power_save 未变 → 无硬件操作)
              (power_save 已变 → 触发 CAN IRQ 控制)
```

## 2. 关键变量

| 变量 | 类型 | 作用域 | 读路径 | 写路径 |
|------|------|--------|--------|--------|
| `current_board->has_fan` | `const bool` | board struct | `fan_tick():22` | — (板级常量: cuatro/true, red/false) |
| `fan_state.power` | `uint8_t` | fan.h extern | `jna_get_fan_power()` (JNA) | `fan_set_power()` |
| `fan_state.cooldown_counter` | `uint8_t` | fan.h extern | `jna_get_fan_cooldown_counter()` (JNA) | `fan_tick()` |
| `heartbeat_counter` | `uint32_t` | main_definitions.h | `main.c:179`; `jna_get_heartbeat_counter()` (JNA) | `main.c:180` (++); `jna_set_heartbeat_counter()` (JNA 注入) |
| `safety_mode_cnt` | `uint32_t` | opendbc extern | `jna_get_safety_mode_cnt()` (JNA) | `main.c:257` (++); `jna_set_safety_mode_cnt()` (JNA 注入) |
| `power_save_enabled` | `bool` | power_saving.h | `main.c:151`; `jna_get_power_save_enabled()` (JNA) | `set_power_save_state()` |
| `harness.status` | `uint8_t` | harness.h | `main.c:144`; `jna_get_harness_status()` | `harness_detect_orientation()` |
| `prev_harness_status` | `uint8_t` (static) | main.c tick_handler | `main.c:144` (比较) | `main.c:145` (赋值) |
| `loop_counter` | `uint8_t` (static) | main.c tick_handler | `main.c:155` (==0 判断) | tick_handler 末尾 (++ / 回绕) |

## 3. 输入因子

| 因子 | 类型 | 等价类 | 说明 |
|------|------|--------|------|
| `has_fan` (板级) | bool | true (cuatro/tres), false (red) | `@red` 标签选择 red 板 |
| `heartbeat_counter` 初始值 | long (uint32) | 正常值, UINT32_MAX-1, UINT32_MAX | 通过 `ControlSetup.heartbeatCounter` 注入 |
| `heartbeatDisabled` | bool | true, false | 阻止心跳超时触发 SILENT 模式 |
| `safety_mode_cnt` 初始值 | long (uint32) | 正常值, UINT32_MAX | 通过 `ControlSetup.safetyModeCnt` 注入 |
| `power_save_enabled` | bool | true, false | 测试 harness reinit 时幂等调用 |
| `harness.status` | uint8 | 0 (NC), 1 (normal), 2 (flipped) | 通过 SBU 电压 + `detectHarnessOrientation` 改变 |
| tick 次数 | int | 1, 8, 24 | 通过 `jna_call_tick_handler` N 次触发 |

## 4. 输出因子

| 输出 | 类型 | 说明 |
|------|------|------|
| `fanPower` | int | `jna_get_fan_power()` — 风扇功率 (0=关闭) |
| `fanCooldownCounter` | int | `jna_get_fan_cooldown_counter()` — 冷却倒计时 |
| `heartbeat.counter` | int | `jna_get_heartbeat_counter()` — 心跳计数器值 |
| `safetyModeCnt` | int | `jna_get_safety_mode_cnt()` — 安全模式运行秒数 |
| `powerSaveEnabled` | bool | `jna_get_power_save_enabled()` — 省电模式状态 |

## 5. 测试用例

### TC1: has_fan=false 时 fan_state 完全不变化
- 前置: red 板 (has_fan=false), safetyMode=2
- 执行: `jna_call_tick_handler` × 24
- 预期: `fanPower=0`, `fanCooldownCounter=0`
- 路径: fan_tick() → has_fan=false → 跳过体 → fan_state 不变
- 场景: `tick_paths.feature:18`

### TC2: heartbeat_counter 到达 UINT32_MAX 后封顶不递增
- 前置: heartbeatCounter=-1 (UINT32_MAX), heartbeatDisabled=1
- 执行: `jna_call_tick_handler` × 8 (1 次 1Hz)
- 预期: `heartbeat.counter=-1` (仍为 UINT32_MAX, 未递增)
- 路径: `heartbeat_counter < UINT32_MAX` → false → 不执行 ++
- 场景: `tick_paths.feature:34`

### TC3: heartbeat_counter 在 UINT32_MAX-1 时正常递增到 UINT32_MAX
- 前置: heartbeatCounter=-2 (UINT32_MAX-1), heartbeatDisabled=1
- 执行: `jna_call_tick_handler` × 8 (1 次 1Hz)
- 预期: `heartbeat.counter=-1` (UINT32_MAX)
- 路径: `heartbeat_counter < UINT32_MAX` → true → ++
- 场景: `tick_paths.feature:50`

### TC4: safety_mode_cnt 从 UINT32_MAX 溢出回绕到 0
- 前置: safetyModeCnt=-1 (UINT32_MAX)
- 执行: `jna_call_tick_handler` × 8 (1 次 1Hz)
- 预期: `safetyModeCnt=0`
- 路径: `safety_mode_cnt += 1U` → UINT32_MAX + 1 → 0 (无符号自然回绕)
- 场景: `tick_paths.feature:70`

### TC5: harness 状态变更触发 reinit — 省电=true 幂等 + 心跳复位
- 前置: safetyMode=2, sbu1=200mV, sbu2=700mV, power_save 先启用
- 执行: `SetPowerSaveState(1)` → `detectHarnessOrientation` → `jna_call_tick_handler` × 1
- 预期: `powerSaveEnabled=true`, `heartbeat.counter=1` (set_safety_mode 复位→0, 1Hz 块 +1)
- 路径: harness.status≠prev → set_safety_mode(2) → heartbeat_counter=0 → set_power_save_state(true) 幂等
- 场景: `tick_paths.feature:90`

### TC6: harness 状态变更触发 reinit — 省电=false 幂等
- 前置: sbu1=700mV, sbu2=200mV, 未启用 power_save
- 执行: `detectHarnessOrientation` → `jna_call_tick_handler` × 1
- 预期: `powerSaveEnabled=false`, `heartbeat.counter=1`
- 路径: harness.status≠prev → set_safety_mode(2) → heartbeat_counter=0 → set_power_save_state(false) 幂等
- 场景: `tick_paths.feature:117`

## 6. 覆盖检查

| 条件 | TC1 @red | TC2 | TC3 | TC4 | TC5 | TC6 |
|------|----------|-----|-----|-----|-----|-----|
| `has_fan` — false (fan_tick 体跳过) | ✅ | — | — | — | — | — |
| `heartbeat_counter < UINT32_MAX` — false (封顶) | — | ✅ | — | — | — | — |
| `heartbeat_counter < UINT32_MAX` — true (递增) | — | — | ✅ | — | — | — |
| `heartbeat_counter += 1U` 执行 | — | — | ✅ | — | — | — |
| `safety_mode_cnt += 1U` 自然回绕 | — | — | — | ✅ | — | — |
| `harness.status != prev_harness_status` — true | — | — | — | — | ✅ | ✅ |
| `set_safety_mode()` 心跳复位 (car mode) | — | — | — | — | ✅ | ✅ |
| `set_power_save_state(true)` 幂等 | — | — | — | — | ✅ | — |
| `set_power_save_state(false)` 幂等 | — | — | — | — | — | ✅ |
| fan_state 读验证 (power, cooldown) | ✅ | — | — | — | — | — |

✅ 所有目标分支、边界条件和边缘路径已覆盖。

## 覆盖率

> 数据来源: `run_all_coverage.sh` 合并报告 (cuatro + tres + red)

| 被测行 | 源文件 | 说明 |
|--------|--------|------|
| `fan.h:22` | `if (current_board->has_fan)` | false 分支: TC1 (@red) 覆盖 |
| `fan.h:23-47` | fan_tick() 体 | true 分支: fan_cooldown.feature 覆盖 |
| `main.c:144` | `if (harness.status != prev_harness_status)` | true 分支: TC5/TC6 覆盖 |
| `main.c:145` | `prev_harness_status = harness.status` | TC5/TC6 覆盖 |
| `main.c:149` | `can_init_all()` | TC5/TC6 覆盖 |
| `main.c:150` | `set_safety_mode(current_safety_mode, ...)` | TC5/TC6 覆盖 |
| `main.c:151` | `set_power_save_state(power_save_enabled)` | true 路径(TC5) / false 路径(TC6) 全覆盖 |
| `main.c:179` | `if (heartbeat_counter < UINT32_MAX)` | false(TC2) / true(TC3) 全覆盖 |
| `main.c:180` | `heartbeat_counter += 1U` | TC3 覆盖, TC2 跳过 |
| `main.c:257` | `safety_mode_cnt += 1U` | TC4 覆盖 (溢出回绕) |
