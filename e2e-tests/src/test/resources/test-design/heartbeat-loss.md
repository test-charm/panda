# 心跳丢失自动行为 — 测试设计文档

> 功能: 心跳丢失 → controls_allowed 撤回 → SILENT 模式 + 省电 + 警笛 + IR 关闭 + 风扇控制
> 被测路径: `board/main.c:185-244` (1Hz tick)
> 常量: `HEARTBEAT_IGNITION_CNT_ON=5`, `HEARTBEAT_IGNITION_CNT_OFF=2`

## 1. 被测功能流程图

```
1Hz tick (每 8 次 jna_call_tick_handler)
    │
    ├── siren_countdown-- (≥0 递减)
    ├── controls_allowed || heartbeat_engaged → countdown=5
    │   └── 否则 countdown--
    │
    ├── controls_allowed && !heartbeat_engaged → mismatches++
    │   └── mismatches ≥ 3 → controls_allowed=false  ← TC1
    │
    └── !heartbeat_disabled?
        └── heartbeat_counter ≥ threshold?
            │  ignition_off: 2s, ignition_on: 5s
            ├── siren_countdown=3 (if controls_allowed_countdown>0)
            ├── heartbeat_lost=true (car safety mode)
            ├── heartbeat_engaged=false
            ├── set_safety_mode(SILENT)      ← TC2,3
            ├── set_power_save_state(true)   ← TC2,3
            ├── set_ir_power(0)              ← TC6
            └── fan_set_power(30 or 0)       ← TC7,8
```

## 2. 关键常量

| 常量 | 值 | 含义 |
|------|----|------|
| `HEARTBEAT_IGNITION_CNT_ON` | 5 | 点火开启时心跳超时门限 (秒) |
| `HEARTBEAT_IGNITION_CNT_OFF` | 2 | 点火关闭时心跳超时门限 (秒) |

## 3. 输入因子

| 因子 | 类型 | 等价类 | 说明 |
|------|------|--------|------|
| controlsAllowed | bool | true, false | 是否允许控制 |
| ignitionLine | bool | true, false | 点火线状态（影响超时门限 5s/2s） |
| heartbeatDisabled | bool | true, false | 禁用心跳检测 |
| somGpio | bool | true, false | SOM GPIO 状态（影响风扇功率） |
| safetyMode | int | car mode (如 2), non-car (如 17) | 影响 heartbeat_lost 标记 |
| tick 次数 | int | < threshold, ≥ threshold | N × 8 次 tick_handler 调用 |

## 4. 输出因子

| 输出 | 类型 | 说明 |
|------|------|------|
| `safetyState.controlsAllowed` | int | 是否已撤回 controls_allowed |
| `safetyState.safetyMode` | int | 0 = SAFETY_SILENT |
| `safetyState.sirenWasActive` | int | 警笛是否曾激活 |
| `powerSaveEnabled` | bool | 是否进入省电模式 |
| `heartbeat.lost` | int | 心跳丢失标志 |
| `powerSaveTracking.irPowerValue` | int | IR 功率（0 = 关闭） |
| `fanPower` | int | 风扇功率（0 或 30） |

## 5. 测试用例

### TC1: controls_allowed 在 3 次 heartbeat_engaged 不匹配后撤回
- 前置: safetyMode=2, controlsAllowed=1
- 执行: tick handler × 24 (3 次 1Hz)
- 预期: controlsAllowed=0
- 路径: mismatches 递增 → ≥3 → controls_allowed=false
- 场景: `heartbeat_loss.feature:20`

### TC2: 点火关闭时 2 秒心跳超时 → SILENT + 省电
- 前置: safetyMode=2, controlsAllowed=1, ignitionLine=0
- 执行: tick handler × 16 (2 次 1Hz)
- 预期: safetyMode=0, powerSaveEnabled=true, heartbeat.lost=1
- 路径: heartbeat_counter ≥ 2 → SILENT
- 场景: `heartbeat_loss.feature:29`

### TC3: 点火开启时 5 秒心跳超时 → SILENT + 省电
- 前置: safetyMode=2, controlsAllowed=1, ignitionLine=1
- 执行: tick handler × 40 (5 次 1Hz)
- 预期: safetyMode=0, powerSaveEnabled=true, heartbeat.lost=1
- 路径: heartbeat_counter ≥ 5 → SILENT
- 场景: `heartbeat_loss.feature:44`

### TC4: 心跳超时时 controls_allowed 最近活跃 → 警笛激活
- 前置: safetyMode=2, controlsAllowed=1, ignitionLine=1
- 执行: tick handler × 40 (5 次 1Hz)
- 预期: sirenWasActive=1
- 路径: controls_allowed_countdown>0 → siren_countdown=3
- 场景: `heartbeat_loss.feature:65`

### TC5: controls_allowed_countdown 过期后心跳超时不触发警笛
- 前置: controlsAllowed=0 (countdown 不再刷新), ignitionLine=1
- 执行: tick handler × 80 (10 次 1Hz, countdown 先过期)
- 预期: sirenWasActive=0, safetyMode=0
- 路径: countdown→0 → 超时时 countdown=0 → 不触发警笛
- 场景: `heartbeat_loss.feature:80`

### TC6: 心跳丢失时 IR 功率置 0
- 前置: safetyMode=2, controlsAllowed=1, ignitionLine=1
- 执行: tick handler × 40
- 预期: irPowerValue=0
- 场景: `heartbeat_loss.feature:101`

### TC7: 心跳丢失时 SOM GPIO 高 → 风扇 30
- 前置: safetyMode=2, controlsAllowed=1, ignitionLine=1, somGpio=1
- 执行: tick handler × 40
- 预期: fanPower=30
- 场景: `heartbeat_loss.feature:116`

### TC8: 心跳丢失时 SOM GPIO 低 → 风扇 0
- 前置: safetyMode=2, controlsAllowed=1, ignitionLine=1, somGpio=0
- 执行: tick handler × 40
- 预期: fanPower=0
- 场景: `heartbeat_loss.feature:130`

### TC9: heartbeat_disabled 阻止心跳超时 → 保持原安全模式
- 前置: safetyMode=17 (non-car), heartbeatDisabled=1, ignitionLine=1
- 执行: tick handler × 48 (6 次 1Hz)
- 预期: safetyMode=17, powerSaveEnabled=false, heartbeat.lost=0
- 路径: heartbeat_disabled → 跳过所有超时逻辑
- 场景: `heartbeat_loss.feature:143`

## 6. 覆盖检查

| 条件 | TC1 | TC2 | TC3 | TC4 | TC5 | TC6 | TC7 | TC8 | TC9 |
|------|-----|-----|-----|-----|-----|-----|-----|-----|-----|
| controls_allowed 撤回 (mismatch≥3) | ✅ | — | — | — | — | — | — | — | — |
| 心跳超时 (ignition off, 2s) | — | ✅ | — | — | — | — | — | — | — |
| 心跳超时 (ignition on, 5s) | — | — | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | — |
| 警笛触发 (countdown>0) | — | — | — | ✅ | — | — | — | — | — |
| 警笛抑制 (countdown=0) | — | — | — | — | ✅ | — | — | — | — |
| IR 功率置 0 | — | — | — | — | — | ✅ | — | — | — |
| 风扇=SOM GPIO×30 | — | — | — | — | — | — | ✅ | ✅ | — |
| heartbeat_disabled 旁路 | — | — | — | — | — | — | — | — | ✅ |
| heartbeat_lost 标记 | — | ✅ | ✅ | — | — | — | — | — | — |
| power_save 进入 | — | ✅ | ✅ | — | — | — | — | — | — |

✅ 所有分支路径、边界条件和副作用已覆盖。

## 覆盖率

> 数据来源: `run_all_coverage.sh` 合并报告

| 被测行 | 源文件 | 说明 |
|--------|--------|------|
| `main.c:188-189` | `siren_countdown--` | TC4/TC5 |
| `main.c:192-198` | `controls_allowed_countdown` 刷新/递减 | TC4/TC5 |
| `main.c:201-208` | `controls_allowed` 撤回 | TC1 |
| `main.c:210` | `!heartbeat_disabled` 守卫 | TC9 |
| `main.c:212` | 心跳超时判断 | TC2-8 |
| `main.c:217-220` | 警笛倒计时设置 | TC4 |
| `main.c:223-225` | `heartbeat_lost` 标记 | TC2/3 |
| `main.c:230-232` | `set_safety_mode(SILENT)` | TC2/3 |
| `main.c:234-236` | `set_power_save_state(true)` | TC2/3 |
| `main.c:239` | `set_ir_power(0)` | TC6 |
| `main.c:243` | `fan_set_power` | TC7/8 |
