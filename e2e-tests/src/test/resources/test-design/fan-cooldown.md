# 风扇冷却保持 — 测试设计文档

> 功能: `fan_state.cooldown_counter` in `board/drivers/fan.h`
> 被测路径: `fan_tick()` → cooldown_counter 递减 → `set_fan_enabled()`
> 实现来源: 真实 `board/drivers/fan.h` 逻辑（e2e include 生产代码）

## 1. 被测功能数据流

```
fan_set_power(50)                    fan_set_power(0)
      │                                    │
      ▼                                    ▼
fan_state.power = 50                fan_state.power = 0
      │                                    │
      ▼ fan_tick() (8Hz)                   ▼ fan_tick() (8Hz)
power > 0 → true                     power > 0 → false
      │                                    │
cooldown_counter = 3*8 = 24         cooldown_counter > 0 ?
      │                              ┌──Y──┐ └──N──┐
      ▼                              │递减  │       │
set_fan_enabled(true)               │↓     │ set_fan_enabled(false)
                                    └──────┘       │
                                    (重复24 tick)   ▼
                                      │          fan 真正关闭
                                      ▼
                                set_fan_enabled(true)
                                (cooldown 期间保持)
```

## 2. 关键变量

| 变量 | 类型 | 作用域 | 读路径 | 写路径 |
|------|------|--------|--------|--------|
| `fan_state.power` | `uint8_t` | fan.h extern | `fan_tick():36` (比较); `jna_get_fan_power()` (JNA) | `fan_set_power()` |
| `fan_state.cooldown_counter` | `uint8_t` | fan.h extern | `fan_tick():39` (比较 >0); `fan_tick():46` (影响 set_fan_enabled); `jna_get_fan_cooldown_counter()` (JNA) | `fan_init():16` (=24); `fan_tick():37` (=24 重置); `fan_tick():40` (--) |
| `current_board->fan_enable_cooldown_time` | `const uint8_t` | board struct | `fan_init():16`; `fan_tick():37` | — (常量, cuatro=3) |
| `FAN_TICK_FREQ` | `static const uint8_t` | fan.h | `fan_init():16`; `fan_tick():24,37` | — (常量=8) |

## 3. 输入因子

| 因子 | 类型 | 等价类 | 说明 |
|------|------|--------|------|
| `fan_state.power` (fan_set_power) | uint8 | 0 (关闭), >0 (运行) | 通过 USB control write 0xb1 设置 |
| tick 次数 | int | 1 (重置验证), <24 (递减中), ≥24 (冷却期满) | 通过 `jna_call_tick_handler` 触发 |

## 4. 输出因子

| 输出 | 类型 | 说明 |
|------|------|------|
| `fanCooldownCounter` | int | 通过 `jna_get_fan_cooldown_counter()` 读取 `fan_state.cooldown_counter` |
| `fanPower` | int | 通过 `jna_get_fan_power()` 读取 `fan_state.power` |

## 5. 测试用例

### TC1: 风扇上电时 cooldown 重置为最大值
- 前置: `fan_init()` 设置 cooldown_counter=24
- 输入: `fan_set_power(50)` → `jna_call_tick_handler` × 1
- 输出: `fanCooldownCounter = 24`, `fanPower = 50`
- 路径: power>0 → cooldown_counter = 3×8 = 24 → fan enabled
- 场景: `fan_cooldown.feature:14`

### TC2: 风扇断电后 cooldown 逐 tick 递减
- 前置: `fan_init()` 设置 cooldown_counter=24
- 输入: `fan_set_power(0)` → `jna_call_tick_handler` × 10
- 输出: `fanCooldownCounter = 14`, `fanPower = 0`
- 路径: power==0 → cooldown_counter 24→23→...→14 (递减10次)
- 场景: `fan_cooldown.feature:30`

### TC3: 冷却期满后 cooldown 到达 0
- 前置: `fan_init()` 设置 cooldown_counter=24
- 输入: `fan_set_power(0)` → `jna_call_tick_handler` × 24
- 输出: `fanCooldownCounter = 0`, `fanPower = 0`
- 路径: power==0 → cooldown_counter 递减至0 → `set_fan_enabled(false)`
- 场景: `fan_cooldown.feature:46`

## 6. 覆盖检查

| 条件 | TC1 | TC2 | TC3 |
|------|-----|-----|-----|
| `fan_state.power > 0` — true | ✅ | — | — |
| `fan_state.power > 0` — false | — | ✅ | ✅ |
| `cooldown_counter = 3*8` (重置) | ✅ | — | — |
| `cooldown_counter > 0` — true (递减) | — | ✅ | ✅ (前23次) |
| `cooldown_counter > 0` — false (期满) | — | — | ✅ (第24次) |
| `cooldown_counter--` 执行 | — | ✅ | ✅ |
| `set_fan_enabled(true)` (power>0) | ✅ | — | — |
| `set_fan_enabled(true)` (cooldown>0) | — | ✅ | — |
| `set_fan_enabled(false)` (both=0) | — | — | ✅ |

✅ 所有分支、边界条件和关键输出已覆盖。

## 覆盖率

> 数据来源: `run_all_coverage.sh` 合并报告 (cuatro + tres + red)

| 被测行 | 源文件 | 说明 |
|--------|--------|------|
| `fan.h:16` | `cooldown_counter = ... * FAN_TICK_FREQ` | fan_init 初始化, TC2/TC3 间接验证 |
| `fan.h:22` | `if (current_board->has_fan)` | has_fan=true 分支覆盖 |
| `fan.h:36` | `if (fan_state.power > 0U)` | true(TC1) / false(TC2,TC3) 全覆盖 |
| `fan.h:37` | `cooldown_counter = ...` (重置) | TC1 覆盖 |
| `fan.h:39` | `if (fan_state.cooldown_counter > 0U)` | true(TC2) / false(TC3最终) 全覆盖 |
| `fan.h:40` | `cooldown_counter--` | TC2(10次), TC3(24次) 覆盖 |
| `fan.h:46` | `set_fan_enabled(...)` | 三个分支全路径覆盖 |
