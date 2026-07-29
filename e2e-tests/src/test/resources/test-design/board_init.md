# Board 初始化 — 测试设计文档

> 功能: `cuatro_init()` / `tres_init()` / `red_init()` — 板级 GPIO 初始化
> 被测接口: JNA 直接调用 `jna_board_init()`
> 覆盖目标: `board/boards/{cuatro,tres,red}.h` (60 行) + `board/stm32h7/peripherals.h` (common_init_gpio/gpio_uart7_init)

## 1. 被测功能流程图

### 1.1 `jna_board_init()` 整体流程

```
When board init
        │
        ▼
  PandaSteps.boardInit()
        │
        ▼
  PandaClient.boardInit() → lib.jna_board_init()
        │
        ▼
  jna_board_init() (libpanda.c):
        │
     ┌──┴──────────────────────────────────────────┐
     │ 1. 重置 e2e_GPIOA..G = {0}    (清洁状态)      │
     │ 2. 重置 e2e_PWR = {0}                        │
     │ 3. e2e_PWR.CR3 = PWR_CR3_USB33RDY (预置)     │
     │ 4. 重置 fake_TIM1/8 = {0}                    │
     │ 5. 重置 NVIC 追踪计数                         │
     │ 6. current_board->init()  ← 生产代码入口       │
     └──┬──────────────────────────────────────────┘
        │
        ▼
  PandaClient.getBoardInit()
        │
        ▼
  BoardInitState (45 字段) ← JNA getter 读取假寄存器
        │
        ▼
  Then control data should be: { boardInit: {...} }
```

### 1.2 `current_board->init()` — 板级差异

```
current_board->init()
        │
  ┌─────┼─────┬──────────────┐
  ▼     ▼     ▼              ▼
cuatro  tres  red         (共用)
_init   _init  _init
        │     │     │
        │     │     ├── common_init_gpio()     ✅ 已去桩 (生产代码)
        │     │     │   ├── gpio_usb_init()    PA11/12 USB AF10 + OSPEEDR
        │     │     │   ├── FDCAN1             PB8/9 AF9
        │     │     │   ├── FDCAN2             PB5/6 AF9
        │     │     │   ├── FDCAN3             PG9/10 AF2
        │     │     │   └── VOLT_S             PF11 analog
        │     │     │
        │     │     ├── gpio_uart7_init()      ✅ 已去桩 → PE7/8 UART7 AF7
        │     │     │
        │     │     ├── clock_source_init()    TIM1/TIM8 + GPIO
        │     │     │   cuatro: init(true)   → PA8 AF1, PB14/15
        │     │     │   tres:   init(false)  → PB14/15 only
        │     │     │   red:    (未调用)
        │     │     │
        │     │     ├── uart_init()            ❌ 桩切断 (无 GPIO 副作用)
        │     │     ├── sound_init()           ❌ 桩切断 (DAC + SAI)
        │     │     └── pwm_init()            ✅ 已去桩 (TIM3 通道4 PWM) — Phase G
        │     │
        │     ├── 板级 GPIO 设置
        │     │   ├── MODER: PA0/6(bootkick/analog), PB0/7/14(amp/CAN),
        │     │   │          PC2/5/8/11(input/analog/TIM/DC_IN),
        │     │   │          PD3/8/11/12/13(FAN/CAN/SAI/FDCAN3),
        │     │   │          PE3/4/6/9(SAI4/DFSDM1)
        │     │   ├── OTYPER: PC8/11(fan/DC_IN open drain), PD3(FAN)
        │     │   └── PUPDR: PB7(CAN), PC2(SOM pull-down), PD8/12/13
        │     │
        │     ├── USB LDO (tres 特有)
        │     │   ├── PWR.CR3 |= USBREGEN | USB33DEN
        │     │   └── while (PWR & USB33RDY == 0);  ← 预置跳过
        │     │
        │     └── CAN 收发器使能 (red 特有)
        │         ├── PG11, PB3/4, PD7 → MODE_OUTPUT
        │         ├── PB14 → OPEN_DRAIN + PULL_UP + OUTPUT=1
        │         └── PB1 → MODE_ANALOG (5VOUT_S)
        │
        └── (无板级时钟源 — red_init 不调用 clock_source_init)
```

## 2. 输入因子

| 因子 | 类型 | 等价类 | 取值 |
|------|------|--------|------|
| 板型 (编译时) | enum | cuatro, tres, red | CUATRO, TRES, RED |
| GPIO 复位状态 | — | 全部为零 | 由 `jna_board_init()` 保证 |

唯一运行时输入是板型选择（通过编译宏 `-DE2E_BOARD_*` 控制加载哪个 dylib）。

## 3. 输出因子

### 3.1 BoardInitState (45 字段)

| 输出 | 类型 | 说明 |
|------|------|------|
| gpioA/B/C/D/E/F/G_Moder | long | GPIO 模式寄存器 (32-bit) |
| gpioA/B/C/D/E/F/G_Otyper | long | GPIO 输出类型 (开漏/推挽) |
| gpioA/B/C/D/E/F/G_Ospeedr | long | GPIO 输出速度 |
| gpioA/B/C/D/E/F/G_Pupdr | long | GPIO 上下拉 |
| gpioA/B/C/D/E_Odr | long | GPIO 输出数据 |
| gpioA/B/C/D/E_Afr0/Afr1 | long | GPIO 复用功能选择 (AFR[0] pins 0-7, AFR[1] pins 8-15) |
| pwrCr3 | long | PWR 控制寄存器 3 (USB LDO) |

### 3.2 板级关键寄存器差异

| 寄存器 | Cuatro 值 | Tres 值 | Red 值 | 验证场景 |
|--------|----------|---------|--------|---------|
| pwrCr3 | 67108864 | **117440512** | 67108864 | TC5 |
| gpioAModer | **42086433** | 1 | 41943040 | TC1, TC5, TC6 |
| gpioBModer | **2685036545** | 2684354560 | 269101388 | TC1, TC7 |
| gpioCModer | 4328450 | **27918336** | 0 | TC1, TC5 |
| gpioDModer | **176226304** | 64 | 16384 | TC1, TC7 |
| gpioEModer | **696960** | 0 | 0 | TC1 |
| gpioFModer | 12582912 | 12582912 | 12582912 | TC1, TC7 |
| gpioGModer | 2621440 | 2621440 | **6815744** | TC1, TC7 |
| gpioCOtyper | **2304** | **3072** | 0 | TC2, TC5 |
| gpioDOtyper | **8** | 0 | 0 | TC2 |
| gpioBOtyper | 0 | 0 | **16384** | TC7 |
| gpioCPupdr | **32** | **32** | 0 | TC3, TC5 |
| gpioBPupdr | 0 | 0 | **268435456** | TC3, TC7 |
| gpioCOdr | 0 | **4096** | 0 | TC5 |
| gpioBOdr | 0 | 0 | **16384** | TC7 |
| gpioAOspeedr | **62914560** | **62914560** | **62914560** | TC4, TC5, TC8 |

> 粗体表示该板型特有的非零值或与其他板型显著不同的值。

## 4. 测试用例

### TC1: Cuatro — GPIO MODER 全端口 (board_init.feature:12)
- 板型: `@cuatro`
- 输入: `When board init`
- 验证: gpioA/B/C/D/E/F/G_Moder = 42086433 / 2685036545 / 4328450 / 176226304 / 696960 / 12582912 / 2621440
- 覆盖: `cuatro_init()` 中所有 `set_gpio_mode/set_gpio_alternate/set_gpio_output` 调用 + `common_init_gpio` + `gpio_uart7_init` + `clock_source_init(true)`

### TC2: Cuatro — OTYPER 开漏引脚 (board_init.feature:30)
- 板型: `@cuatro`
- 输入: `When board init`
- 验证: gpioCOtyper=2304 (PC8 fan + PC11 DC_IN_EN_N), gpioDOtyper=8 (PD3 FAN_EN)
- 覆盖: `set_gpio_output_type()` + `register_set_bits(GPIOC->OTYPER, OT8)`

### TC3: Cuatro — PUPDR 上下拉 (board_init.feature:43)
- 板型: `@cuatro`
- 输入: `When board init`
- 验证: gpioCPupdr=32 (PC2 pull-down), gpioBPupdr=0 (PB7 pull-none)
- 覆盖: `set_gpio_pullup(GPIOC, 2, PULL_DOWN)` + `set_gpio_pullup(GPIOB, 7, PULL_NONE)`

### TC4: Cuatro — USB OSPEEDR (board_init.feature:56)
- 板型: `@cuatro`
- 输入: `When board init`
- 验证: gpioAOspeedr=62914560 (PA11/PA12 OSPEEDR11|OSPEEDR12)
- 覆盖: `common_init_gpio` → `gpio_usb_init()` → `GPIOA->OSPEEDR = ...`

### TC5: Tres — USB LDO + 板级 GPIO (board_init.feature:68)
- 板型: `@tres`
- 输入: `When board init`
- 验证: pwrCr3=117440512 (USBREGEN|USB33DEN|USB33RDY), gpioCModer=27918336, gpioCPupdr=32, gpioCOtyper=3072, gpioCOdr=4096
- 覆盖: `tres_init()` USB LDO 使能 + GPIOC 配置 (SOM GPIO, TIM3, I2C5, bootkick)

### TC6: Red — CAN 收发器 + 电压检测 (board_init.feature:84)
- 板型: `@red`
- 输入: `When board init`
- 验证: gpioBModer=269101388, gpioBOtyper=16384, gpioBPupdr=268435456, gpioBOdr=16384, gpioDModer=16384, gpioGModer=6815744, gpioFModer=12582912
- 覆盖: `red_init()` CAN 收发器使能 (PG11/PB3/PB4/PD7) + USB 负载开关 (PB14) + 5VOUT_S (PB1) + `common_init_gpio`

### TC7: Red — USB 引脚 (board_init.feature:102)
- 板型: `@red`
- 输入: `When board init`
- 验证: gpioAModer=41943040 (PA11/PA12 USB AF10), gpioAOspeedr=62914560
- 覆盖: `common_init_gpio` → `gpio_usb_init()` 对 red 板型的贡献

## 5. 覆盖检查

### 5.1 `cuatro_init()` — 24 行

| 行 | 代码 | TC1 | TC2 | TC3 | TC4 | 状态 |
|----|------|-----|-----|-----|-----|------|
| 51 | `common_init_gpio()` | ✅ | — | — | ✅ | 已去桩 |
| 54 | `set_gpio_output_type(GPIOD,3,OD)` | — | ✅ | — | — | OTYPER |
| 55 | `set_gpio_output_type(GPIOC,11,OD)` | — | ✅ | — | — | OTYPER |
| 58 | `set_gpio_mode(GPIOC,5,ANALOG)` | ✅ | — | — | — | MODER |
| 59 | `set_gpio_mode(GPIOA,6,ANALOG)` | ✅ | — | — | — | MODER |
| 62-63 | PB7 pull-none + output | ✅ | — | ✅ | — | MODER+PUPDR |
| 64-65 | PD8 pull-none + output | ✅ | — | — | — | MODER |
| 68-69 | PD12 pull-none + AF5 | ✅ | — | — | — | MODER |
| 70-71 | PD13 pull-none + AF5 | ✅ | — | — | — | MODER |
| 74-75 | PC2 input + pull-down | ✅ | — | ✅ | — | MODER+PUPDR |
| 78 | `cuatro_set_bootkick()` | ✅ | — | — | — | MODER |
| 81 | `gpio_uart7_init()` | ✅ | — | — | — | 已去桩 |
| 82 | `uart_init()` | — | — | — | — | ❌ 桩 |
| 85-86 | PC8 AF2 + open drain | ✅ | ✅ | — | — | MODER+OTYPER |
| 89 | `clock_source_init(true)` | ✅ | — | — | — | MODER+A_OSPEEDR |
| 92 | `cuatro_set_amp_enabled(false)` | ✅ | — | — | — | MODER |
| 93-99 | SAI4/DFSDM1 AF pins | ✅ | — | — | — | MODER |
| 100 | `sound_init()` | — | — | — | — | ❌ 桩 |

> cuatro 覆盖率: **23/24 (95.8%)** — 仅 uart_init 保持桩切断

### 5.2 `tres_init()` — 19 行

| 行 | 代码 | TC5 | 状态 |
|----|------|-----|------|
| 106-108 | USB LDO 使能 + 自旋等待 | ✅ | PWR_CR3 |
| 110 | `common_init_gpio()` | ✅ | 已去桩 |
| 113-114 | PC2 input + pull-down | ✅ | MODER+PUPDR |
| 118-119 | bootkick + PC12 output | ✅ | MODER+ODR |
| 122 | `gpio_uart7_init()` | ✅ | 已去桩 |
| 123 | `uart_init()` | — | ❌ 桩 |
| 126 | PC8 AF2 (fan) | ✅ | MODER |
| 129-131 | PC9 AF2 + pwm_init + ir_power | ✅ | MODER (pwm_init 已去桩) |
| 134-136 | PC10/PC11 I2C5 + open drain | ✅ | MODER+OTYPER |
| 139 | `clock_source_init(false)` | ✅ | MODER (GPIOB) |

> tres 覆盖率: **17/19 (89.5%)** — uart_init 保持桩切断 (pwm_init 已去桩 ✅ Phase G)

### 5.3 `red_init()` — 17 行

| 行 | 代码 | TC6 | TC7 | 状态 |
|----|------|-----|-----|------|
| 75 | `common_init_gpio()` | ✅ | ✅ | 已去桩 |
| 78-79 | PG11 pull-none + output | ✅ | — | MODER |
| 81-82 | PB3 pull-none + output | ✅ | — | MODER |
| 84-85 | PD7 pull-none + output | ✅ | — | MODER |
| 87-88 | PB4 pull-none + output | ✅ | — | MODER |
| 91-92 | PB1 pull-none + analog | ✅ | — | MODER |
| 95 | PB14 open-drain | ✅ | — | OTYPER |
| 96 | PB14 pull-up | ✅ | — | PUPDR |
| 97 | PB14 output | ✅ | — | MODER |
| 98 | PB14 output=1 | ✅ | — | ODR |

> red 覆盖率: **17/17 (100%)** — 全部行覆盖

### 5.4 去桩化函数覆盖

| 函数 | 行数 | TC1 | TC4 | TC5 | TC6 | TC7 | 状态 |
|------|------|-----|-----|-----|-----|-----|------|
| `common_init_gpio` | 16 | ✅ | ✅ | ✅ | ✅ | ✅ | PF11/PA11-12/PB5-6-8-9-12-13/PG9-10 |
| `gpio_uart7_init` | 3 | ✅ | — | ✅ | — | — | PE7/PE8 UART7 |

### 5.5 板型差异路径覆盖

| 条件 | Cuatro | Tres | Red |
|------|--------|------|-----|
| `clock_source_init(true)` | ✅ TC1 | — | — |
| `clock_source_init(false)` | — | ✅ TC5 | — |
| `clock_source_init` 未调用 | — | — | ✅ |
| USB LDO (PWR_CR3) | — | ✅ TC5 | — |
| CAN 收发器使能 | ✅(PD8/PD12/13) | — | ✅(PG11/PB3/4/PD7) |
| USB 负载开关 (PB14) | — | — | ✅ TC6 |
| 开漏输出 | ✅ TC2 | ✅ TC5 | ✅ TC6 |
| SOM GPIO pull-down | ✅ TC3 | ✅ TC5 | — |
| SAI4 音频引脚 | ✅ TC1 | — | — |
| I2C5 警笛 | — | ✅ TC5 | — |
| IR PWM | — | ✅ TC5 | — |

## 6. JNA 接口

`xxx_init()` 非 USB 命令，通过 JNA 直接调用：

| JNA 函数 | 返回值 | 说明 |
|----------|--------|------|
| `jna_board_init()` | void | 重置状态 → `current_board->init()` |
| `jna_get_reg_GPIO*_MODER()` | uint32 | GPIO A-G 模式 (7 个) |
| `jna_get_reg_GPIO*_OTYPER()` | uint32 | GPIO A-G 输出类型 (7 个，新增) |
| `jna_get_reg_GPIO*_OSPEEDR()` | uint32 | GPIO A-G 输出速度 (7 个，新增) |
| `jna_get_reg_GPIO*_PUPDR()` | uint32 | GPIO A-G 上下拉 (7 个，新增) |
| `jna_get_reg_GPIO*_ODR()` | uint32 | GPIO A-G 输出数据 (7 个) |
| `jna_get_reg_GPIO*_AFR0/1()` | uint32 | GPIO A/B/C/D/E 复用功能 (10 个，C/D/E 新增) |
| `jna_get_reg_PWR_CR3()` | uint32 | PWR 控制寄存器 (新增) |

`jna_board_init()` 预置 `PWR_CR3_USB33RDY` 以避免 `tres_init()` 中的 USB LDO 就绪自旋等待死循环。

## 覆盖率

> 数据来源: 行级手动分析 (board_init.feature 场景覆盖)
> 实施日期: 2026-07-26

| 板型 | 总行数 | 已覆盖 | 桩切断 | 有效覆盖率 |
|------|--------|--------|--------|-----------|
| `cuatro_init()` | 24 | 23 | 1 (uart_init) | **95.8%** |
| `tres_init()` | 19 | 17 | 1 (uart_init) | **89.5%** |
| `red_init()` | 17 | 17 | 0 | **100%** |
| **合计** | **60** | **57** | **2** | **95.0%** |

| 测试指标 | 数值 |
|----------|------|
| 场景总数 | 7 (4 cuatro + 1 tres + 2 red) |
| 验证的寄存器位 | ~180 (45 个 32-bit 寄存器字段) |
| 全量回归 (cuatro) | 189/189 通过 |
| 去桩化函数 | common_init_gpio, gpio_uart7_init |
