# LED PWM 初始化 — 测试设计文档

> 功能: `led_init()` / `led_set()` / `pwm_init()` / `pwm_set()` — LED PWM 定时器配置
> 被测接口: 寄存器验证 (TIM3 CR1/ARR/CCMR/CCER/CCR)
> 覆盖目标: `board/drivers/pwm.h` (37/45) + `board/drivers/led.h` (24/25)
> Phase H: e2e 包装器已删除，真实 `board/drivers/pwm.h` 和 `board/drivers/led.h` 直接使用（与生产代码完全一致）。
> Phase: G — pwm.h/led.h 去桩化

## 1. 被测功能流程图

### 1.1 `led_init()` 调用链

```
jna_panda_init()                    ← 每次场景启动时调用
        │
        ▼
  detect_board_type()               ← 设置 current_board
        │
        ▼
  led_init()                        ← Phase G 新增 (模拟 main.c:281)
        │
        ▼
  for (i=0; i<3; i++):
        │
   ┌────┴─────────────────────────────┐
   │ set_gpio_pullup(pin, PULL_NONE)  │   所有板型通用
   │ set_gpio_output_type(pin, OD)    │
   │                                  │
   │ if (led_pwm_channels[i] != 0):   │
   │   ├── PWM 路径 (cuatro)          │
   │   │   set_gpio_alternate(pin, AF2_TIM3)
   │   │   pwm_init(TIM3, channel)   │
   │   │                              │
   │   └── GPIO 路径 (tres, red)     │
   │       set_gpio_mode(pin, OUTPUT) │
   │                                  │
   │ led_set(i, false)  ← 初始关断   │
   └──────────────────────────────────┘
```

### 1.2 `pwm_init(TIM3, channel)` 寄存器操作

```
pwm_init(TIM3, channel):
        │
        ├── register_set(CR1, CEN|ARPE, 0x3F)    → CR1 |= 0x01 (ARPE 被 0x3F 掩码截断)
        │
        ├── switch(channel):
        │     case 1: CCMR1 |= ch1_PWM_mode1 | OC1PE, CCER |= CC1E
        │     case 2: CCMR1 |= ch2_PWM_mode1 | OC2PE, CCER |= CC2E
        │     case 3: CCMR2 |= ch3_PWM_mode1 | OC3PE, CCER |= CC3E
        │     case 4: CCMR2 |= ch4_PWM_mode1 | OC4PE, CCER |= CC4E
        │
        ├── register_set(ARR, 4800, 0xFFFF)      → ARR = 4800 (PWM_COUNTER_OVERFLOW)
        │
        └── EGR |= UG                              → 更新寄存器
```

### 1.3 `pwm_set(TIM3, channel, percentage)`

```
pwm_set(TIM3, channel, percentage):
        │
        ├── comp_value = percentage * 4800 / 100
        │
        └── switch(channel):
              case 1: register_set(CCR1, comp_value, 0xFFFF)
              case 2: register_set(CCR2, comp_value, 0xFFFF)
              case 3: register_set(CCR3, comp_value, 0xFFFF)
              case 4: register_set(CCR4, comp_value, 0xFFFF)
```

## 2. 输入因子

| 因子 | 类型 | 等价类 | 取值 |
|------|------|--------|------|
| 板型 | enum | cuatro (PWM), tres/red (GPIO) | CUATRO, TRES, RED |
| led_pwm_channels | uint8_t[3] | 全非0 (PWM), 全0 (GPIO) | {1,2,4} / {0,0,0} |

唯一运行时输入是板型选择，决定 LED 驱动路径 (PWM vs GPIO)。

## 3. 输出因子

### 3.1 LedPwmState (9 字段)

| 输出 | 类型 | 说明 |
|------|------|------|
| tim3Cr1 | int | TIM3 控制寄存器 1 (CEN 位) |
| tim3Arr | int | TIM3 自动重载值 (4800) |
| tim3Ccmr1 | int | TIM3 捕获/比较模式 1 (ch1+ch2 PWM配置) |
| tim3Ccmr2 | int | TIM3 捕获/比较模式 2 (ch4 PWM配置) |
| tim3Ccer | int | TIM3 捕获/比较使能 (CC1E/CC2E/CC4E) |
| tim3Ccr1 | int | TIM3 通道1 比较值 |
| tim3Ccr2 | int | TIM3 通道2 比较值 |
| tim3Ccr3 | int | TIM3 通道3 比较值 (未使用) |
| tim3Ccr4 | int | TIM3 通道4 比较值 |

### 3.2 板级预期值

| 寄存器 | Cuatro (PWM {1,2,4}) | Tres (GPIO, tres_init ch4 IR) |
|--------|----------------------|------------------------------|
| tim3Cr1 | 1 | 1 |
| tim3Arr | 4800 | 4800 |
| tim3Ccmr1 | 26728 (ch1+ch2 PWM) | 0 |
| tim3Ccmr2 | 26624 (ch4 PWM) | 26624 (ch4 PWM from tres_init) |
| tim3Ccer | 4113 (CC1E\|CC2E\|CC4E) | 4096 (CC4E only) |
| tim3Ccr1 | 4800 (100% duty = off) | 0 |
| tim3Ccr2 | 4800 (100% duty = off) | 0 |
| tim3Ccr3 | 0 | 0 |
| tim3Ccr4 | 4800 (100% duty = off) | 0 (tres_set_ir_power(0)) |

> ARPE (bit 7) 被 `register_set` 的 `0x3F` 掩码截断，实际 CR1 = 1 (仅 CEN)。

## 4. 测试用例

### TC1: Cuatro — TIM3 CR1/ARR 初始化 (led_pwm.feature:9)
- 板型: `@cuatro`
- 输入: 无 (led_init 在 jna_panda_init 中自动调用)
- 验证: tim3Cr1=1, tim3Arr=4800
- 覆盖: `pwm_init()` CR1/ARR 配置

### TC2: Cuatro — TIM3 CCMR PWM 模式 (led_pwm.feature:22)
- 板型: `@cuatro`
- 输入: 无
- 验证: tim3Ccmr1=26728, tim3Ccmr2=26624
- 覆盖: `pwm_init()` ch1/ch2/ch4 PWM mode 1 + preload 配置

### TC3: Cuatro — TIM3 CCER 输出使能 (led_pwm.feature:34)
- 板型: `@cuatro`
- 输入: 无
- 验证: tim3Ccer=4113 (CC1E | CC2E | CC4E)
- 覆盖: `pwm_init()` 输出使能

### TC4: Cuatro — TIM3 CCR 占空比值 (led_pwm.feature:47)
- 板型: `@cuatro`
- 输入: 无 (led_set(false) → 100% duty)
- 验证: tim3Ccr1=4800, tim3Ccr2=4800, tim3Ccr3=0, tim3Ccr4=4800
- 覆盖: `pwm_set()` + `led_set(false)` 全通道初始值

### TC5: Tres — TIM3 ch4 IR 配置 (led_pwm.feature:62)
- 板型: `@tres`
- 输入: `When board init` (触发 tres_init → pwm_init(TIM3, 4))
- 验证: tim3Cr1=1, tim3Arr=4800, tim3Ccmr1=0, tim3Ccmr2=26624, tim3Ccer=4096, tim3Ccr4=0
- 覆盖: tres_init 中的 `pwm_init(TIM3, 4)` + `tres_set_ir_power(0)`

### TC6: Tres — TIM3 未使用通道保持清零 (led_pwm.feature:79)
- 板型: `@tres`
- 输入: 无 (led_init 不配置 PWM 通道)
- 验证: tim3Ccr1=0, tim3Ccr2=0, tim3Ccr3=0
- 覆盖: GPIO-only LED 路径不误触 PWM

## 5. 覆盖检查

### 5.1 `pwm_init()` — 39 行

| 行 | 代码 | TC1 | TC2 | TC3 | TC5 | 状态 |
|----|------|-----|-----|-----|-----|------|
| 8 | 函数入口 | ✅ | — | — | ✅ | |
| 10 | `register_set(CR1, CEN\|ARPE, 0x3F)` | ✅ | — | — | ✅ | |
| 13 | `switch(channel)` | ✅ | — | — | ✅ | |
| 14-17 | `case 1U`: CCMR1, CCER | ✅ | ✅ | ✅ | — | ch1 PWM 模式 |
| 18-21 | `case 2U`: CCMR1, CCER | ✅ | ✅ | ✅ | — | ch2 PWM 模式 |
| 22-25 | `case 3U`: CCMR2, CCER | — | — | — | — | ❌ llfan.h (硬件) |
| 26-29 | `case 4U`: CCMR2, CCER | ✅ | ✅ | ✅ | ✅ | ch4 PWM 模式 |
| 30-31 | `default`: break | — | — | — | — | ❌ 防御代码 |
| 35 | `register_set(ARR, 4800)` | ✅ | — | — | ✅ | |
| 38 | `EGR \|= UG` | ✅ | — | — | ✅ | |

### 5.2 `pwm_set()` — 16 行

| 行 | 代码 | TC4 | TC5 | 状态 |
|----|------|-----|-----|------|
| 41-42 | 函数入口 + comp_value 计算 | ✅ | ✅ | |
| 44-46 | `case 1U`: register_set(CCR1) | ✅ | — | |
| 47-49 | `case 2U`: register_set(CCR2) | ✅ | — | |
| 50-52 | `case 3U`: register_set(CCR3) | ✅ | — | fan.h 覆盖 |
| 53-55 | `case 4U`: register_set(CCR4) | ✅ | ✅ | |
| 56-57 | `default`: break | — | — | ❌ 防御代码 |

### 5.3 `led_init()` — 15 行

| 行 | 代码 | TC1-4 | TC5-6 | 状态 |
|----|------|-------|-------|------|
| 21 | 函数入口 | ✅ | ✅ | |
| 22 | `for (i=0; i<3; i++)` | ✅ | ✅ | |
| 23-24 | set_gpio_pullup + output_type | ✅ | ✅ | GPIO 寄存器 |
| 26 | `if (led_pwm_channels[i] != 0)` | ✅ (true) | ✅ (false) | PWM vs GPIO 分支 |
| 27-28 | PWM: set_alternate + pwm_init | ✅ | — | cuatro only |
| 29-30 | GPIO: set_gpio_mode | — | ✅ | tres/red only |
| 33 | `led_set(i, false)` | ✅ | ✅ | 初始关断 |

### 5.4 `led_set()` — 7 行

| 行 | 代码 | 状态 |
|----|------|------|
| 11-12 | 函数入口 + `color < 3` 检查 | ✅ 全板覆盖 |
| 13 | `if (led_pwm_channels != 0)` | ✅ PWM 路径 (cuatro) |
| 14 | pwm_set(TIM3, ...) | ✅ |
| 16 | set_gpio_output(...) | ✅ GPIO 路径 (tres/red) |

> 总计: pwm.h 37/45 (82.2%), led.h 24/25 (96.0%)

## 6. JNA 接口

| JNA 函数 | 返回值 | 说明 |
|----------|--------|------|
| `jna_get_TIM3_CR1()` | uint32 | TIM3 控制寄存器 1 |
| `jna_get_TIM3_ARR()` | uint32 | TIM3 自动重载值 |
| `jna_get_TIM3_CCMR1()` | uint32 | TIM3 捕获/比较模式 1 |
| `jna_get_TIM3_CCMR2()` | uint32 | TIM3 捕获/比较模式 2 |
| `jna_get_TIM3_CCER()` | uint32 | TIM3 捕获/比较使能 |
| `jna_get_TIM3_CCR1()` | uint32 | TIM3 通道 1 比较值 |
| `jna_get_TIM3_CCR2()` | uint32 | TIM3 通道 2 比较值 |
| `jna_get_TIM3_CCR3()` | uint32 | TIM3 通道 3 比较值 |
| `jna_get_TIM3_CCR4()` | uint32 | TIM3 通道 4 比较值 |

`jna_panda_init()` 在场景启动时自动调用 `led_init()`（Phase G 新增，模拟 `main.c:281`）。

## 覆盖率

> 数据来源: `e2e-tests/run_all_coverage.sh` 合并报告
> 实施日期: 2026-07-29

| 文件 | 总行数 | 已覆盖 | 未覆盖 | 覆盖率 |
|------|--------|--------|--------|--------|
| `board/drivers/pwm.h` | 45 | 37 | 8 (ch3 llfan + default ×2 + 行末) | **82.2%** |
| `board/drivers/led.h` | 25 | 24 | 1 (LED_RED define) | **96.0%** |

| 测试指标 | 数值 |
|----------|------|
| 场景总数 | 6 (4 cuatro + 2 tres) |
| 验证的 TIM3 寄存器 | 9 (CR1/ARR/CCMR1/CCMR2/CCER/CCR1-4) |
| 验证的寄存器位 | ~60 |
| 去桩化文件 | pwm.h, led.h |
| 新增 JNA 函数 | 9 (TIM3 读取) |

## 发现

去桩化过程中发现两个生产代码行为细节：

1. **`register_set` 掩码截断 ARPE**: `pwm_init()` 调用 `register_set(CR1, CEN|ARPE, 0x3F)`。掩码 `0x3F` 仅覆盖位 0-5，ARPE 位于位 7 超出掩码范围，实际 CR1 = 1（仅 CEN）。这使 TIM3 自动重装预载功能未使能，验证捕获了此行为。

2. **`led_init()` 调用链断裂**: 生产代码中 `led_init()` 仅由 `main.c:281` 的 `main()` 调用。e2e 测试从不执行 `panda_main()`，导致 `led_init()` 从未被调用。修复方式：在 `jna_panda_init()` 中 `detect_board_type()` 之后显式调用 `led_init()`，模拟真实固件启动流程。
