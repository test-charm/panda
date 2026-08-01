# Body 主中断路径 — 测试设计文档

> 功能: `tick_handler()` + `exti15_10_handler()` + `bldc_tim8_handler()` in `board/body/main.c`
> 被测接口: `jna_body_call_tick_handler()` / `jna_body_trigger_charging_exti()` / `jna_body_trigger_ignition_exti()` / `jna_body_trigger_tim8_irq()`
> 固件目标: body (`board/body/main.c`)
> 已完成: B18 + B19 + B20 (2026-08-01)

## 1. 被测功能流程图

```
B18: body tick handler
  jna_body_set_can0_ile(0)
    + jna_body_set_can0_transmit_error_cnt(128)
    + jna_body_call_tick_handler()
      │
      ▼
  TICK_TIMER->SR = 1
    └─ tick_handler()
         ├─ transmit_error_cnt >= 128 → llcan_init(CAN0)
         ├─ led_set(LED_RED, led_on)
         ├─ led_on = !led_on
         ├─ tick_count++
         └─ TICK_TIMER->SR = 0

B19: EXTI15_10 charging + ignition debounce
  jna_body_set_charging_detect(true)
    + jna_body_trigger_charging_exti()
      └─ plug_charging = 1

  jna_body_set_microsecond_timer(250001)
    + jna_body_set_ignition_pressed(true)
    + jna_body_trigger_ignition_exti()
      │
      ▼
  exti15_10_handler()
    ├─ now = microsecond_timer_get()
    ├─ pressed = (GPIO == 0)
    ├─ elapsed > 200ms ? yes
    ├─ ignition = !ignition
    ├─ ignition_press_timestamp_us = now
    └─ set_gpio_output(OBDC_IGNITION_ON, ignition)

  jna_body_set_microsecond_timer(300000)
    + jna_body_trigger_ignition_exti()
      └─ elapsed = 49999us < 200ms → debounce, state unchanged

B20: TIM8 update IRQ → BLDC step
  bldc_skip_calibration()
    + set_motor_speeds(100, 200, true)
    + jna_body_trigger_tim8_irq()
      │
      ▼
  LEFT_TIM->SR = TIM_SR_UIF
    └─ bldc_tim8_handler()
         ├─ clear UIF (LEFT_TIM->SR = ~TIM_SR_UIF)
         └─ bldc_step() → TIM8/TIM1 CCRx 写入 PWM
```

## 2. 输入因子

| 因子 | 类型 | 等价类 | 取值 |
|------|------|--------|------|
| `can0Ile` | uint32 | 已关闭中断 | 0 |
| `transmit_error_cnt` | uint8 | 触发 CAN core reset 阈值 | 128 |
| `charging_detect` | bool | barrel jack 插入 | true |
| `ignition_pressed` | bool | 按键按下（低电平） | true |
| `now_us` | uint32 | 大于防抖阈值 / 小于防抖阈值 | 250001, 300000 |
| `rpm_left` / `rpm_right` | int | 有效目标转速 | 100, 200 |
| `enable_motors` | bool | 电机使能 | true |

## 3. 输出因子

| 输出 | 类型 | 说明 |
|------|------|------|
| `tickCount` | int | `tick_handler()` 调用后应递增 |
| `can0Ile` | int | `llcan_init()` 后应重新置为 `3` |
| `redLedOn` | bool | 第一次 tick 后红灯点亮 |
| `plugCharging` | bool | 充电检测状态 |
| `ignition` | bool | 点火逻辑状态 |
| `ignitionPressTimestampUs` | int | 最近一次通过防抖检查的按下时间 |
| `ignitionOutputOn` | bool | `OBDC_IGNITION_ON_PIN` 输出状态 |
| `leftPwmActive` | bool | `bldc_step()` 后 TIM8/TIM1 CCR 有非零 PWM |
| `tim8Sr` | int | UIF 清除后为 `~TIM_SR_UIF`，DAL 中显示 `-2` |

## 4. 测试用例

### TC1 (B18): tick_handler 遇到 CAN0 transmit error 时重置 CAN core
- 前置:
  1. `body set CAN0 ILE to 0`
  2. `body set CAN0 transmit error count to 128`
- 步骤: `body tick handler`
- 输出:
  - `tickCount=1`
  - `can0Ile=3`
  - `redLedOn=true`
- 覆盖: `tick_handler()` 的 CAN 健康检查、LED 翻转和 `tick_count++`

### TC2 (B19): charging EXTI 更新 `plug_charging`
- 步骤:
  1. `body set charging detect to true`
  2. `body trigger charging EXTI`
- 输出: `plugCharging=true`
- 覆盖: `exti15_10_handler()` 的 `CHARGING_DETECT_PIN` 分支

### TC3 (B19): ignition EXTI 通过 200ms 防抖后翻转点火状态
- 前置:
  1. `body set microsecond timer to 250001`
  2. `body set ignition pressed to true`
- 步骤: `body trigger ignition EXTI`
- 输出:
  - `ignition=true`
  - `ignitionPressTimestampUs=250001`
  - `ignitionOutputOn=true`
- 覆盖: `pressed=true` 且 `elapsed > debounce_us` 分支

### TC4 (B19): ignition EXTI 在 200ms 内再次触发时被防抖拦截
- 前置: TC3 已执行，状态已翻转到 `ignition=true`
- 步骤:
  1. `body set microsecond timer to 300000`
  2. `body trigger ignition EXTI`
- 输出保持不变:
  - `ignition=true`
  - `ignitionPressTimestampUs=250001`
  - `ignitionOutputOn=true`
- 覆盖: `elapsed <= debounce_us` 的防抖跳过路径

### TC5 (B20): TIM8 update IRQ 触发 `bldc_step()` 并清除 UIF
- 前置:
  1. `bldc skip calibration`
  2. `set motor speeds: left = 100 rpm, right = 200 rpm, enable = true`
- 步骤: `body trigger TIM8 update interrupt`
- 输出:
  - `leftPwmActive=true`
  - `tim8Sr=-2`
- 覆盖: `bldc_tim8_handler()` → `bldc_step()` 中断路径

## 5. 覆盖检查

| 条件 | TC1 | TC2 | TC3 | TC4 | TC5 |
|------|-----|-----|-----|-----|-----|
| `tick_handler()` CAN reset 阈值 | ✅ | — | — | — | — |
| `tick_handler()` LED 翻转 | ✅ | — | — | — | — |
| `tick_count++` | ✅ | — | — | — | — |
| charging EXTI 分支 | — | ✅ | — | — | — |
| ignition EXTI 翻转分支 | — | — | ✅ | — | — |
| ignition 200ms 防抖分支 | — | — | — | ✅ | — |
| `set_gpio_output(OBDC_IGNITION_ON)` | — | — | ✅ | ✅ | — |
| `bldc_tim8_handler()` | — | — | — | — | ✅ |
| `bldc_step()` 经中断路径触发 | — | — | — | — | ✅ |
| UIF 清除 | — | — | — | — | ✅ |

## 6. 与生产固件的关系

在生产固件 `board/body/main.c` 中，这三条路径都属于 `body_main()` 的外围中断逻辑，而不是 USB 命令路径：

```c
REGISTER_INTERRUPT(EXTI15_10_IRQn, exti15_10_handler, ...)
REGISTER_INTERRUPT(TIM8_UP_TIM13_IRQn, bldc_tim8_handler, ...)
REGISTER_INTERRUPT(TICK_TIMER_IRQ, tick_handler, ...)
```

e2e 环境不执行 `while (true)` 主循环，但通过独立 JNA 入口直接驱动这些中断处理函数，因此可以在不引入无限循环的前提下验证 `board/body/main.c` 的可测逻辑。`board_body_init()` 已并入 `jna_panda_init()` 启动路径，由 `body_bldc.feature` 的启动场景覆盖；当前剩余空白主要是 `body_main()` 初始化序列与 while 主循环。

## 覆盖率

> 数据来源: `COVERAGE=1 ./gradlew cucumberCoverage -Pboard=body -Ptags='@body'` (2026-08-01, 已包含 `body_main.feature`)

| 源文件 | 行覆盖 | 函数覆盖 | 说明 |
|--------|--------|---------|------|
| `board/body/main.c` | 40.62% (39/96) | 42.86% (3/7) | ✅ B18-B20 覆盖 `tick_handler()` / `exti15_10_handler()` / `bldc_tim8_handler()`；未覆盖仍集中在 `body_main()`、`enable_fpu()`、`__initialize_hardware_early()`、`debug_ring_callback()` |
