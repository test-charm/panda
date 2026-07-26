# 自定义时钟源 — 测试设计文档

> 功能: `clock_source_set_timer_params()` + `clock_source_init()`
> 被测接口: USB control request 0xe6 (`set_timer_params`) + JNA 直接调用 (`clock_source_init`)
> 覆盖目标: `board/drivers/clock_source.h` (67 行)

## 1. 被测功能流程图

### 1.1 `clock_source_set_timer_params()`

```
set clock source (0xe6):
  [controlWrite(0xe6, param1, param2)]
           │
           ▼
  clock_source_set_timer_params(param1, param2)
           │
     ┌─────┴──────────────────────────┐
     │  register_set(TIM1->CCR1,       │
     │    ((param1 & 0xFF00)>>8)*10)   │
     │  register_set(TIM1->CCR2,       │
     │    (param1 & 0xFF)*10)          │
     │  register_set(TIM8->CCR3,       │
     │    ((param2 & 0xFF00)>>8)*10)   │
     │  register_set(TIM1->ARR,        │
     │    ((param2 & 0xFF)*10)-1)      │
     │  register_set(TIM1->CCR4,       │
     │    (ARR+1)/2)                   │
     └─────────────────────────────────┘
```

### 1.2 `clock_source_init(enable_channel1)`

```
  clock_source_init(enable_channel1)
           │
     ┌─────┴──────────────────────────────────────────┐
     │ TIM1 基础配置 (L18-25):                         │
     │  PSC=(APB2*100-1)&0xFFFF=51199                │
     │  ARR=499  CCMR1=0  CCER=5  CCR1=CCR2=20       │
     │  CCR4=250  DIER|=3                               │
     ├────────────────────────────────────────────────┤
     │ NVIC 禁用 (L29-30):                              │
     │  TIM1_UP_TIM10_IRQn=25, TIM1_CC_IRQn=27       │
     ├────────────────────────────────────────────────┤
     │ GPIO 通道 (L33-36):                              │
     │  if enable_channel1: GPIOA8 AF1_TIM1            │
     │  always: GPIOB14 AF1_TIM1                        │
     ├────────────────────────────────────────────────┤
     │ PWM 模式 + 输出使能 (L39-43):                    │
     │  CCMR1=0x6060  CCMR2=0x7060  BDTR|=MOE         │
     ├────────────────────────────────────────────────┤
     │ 主-从同步 (L46-48):                              │
     │  TIM1 SMCR=0  CR2=0x70  TIM8 SMCR=4            │
     ├────────────────────────────────────────────────┤
     │ TIM8 从定时器 (L51-55):                          │
     │  PSC=TIM1.PSC  ARR=TIM1.ARR  CCMR2=0x60        │
     │  CCR3=20  CCER=0x10                              │
     ├────────────────────────────────────────────────┤
     │ TIM8 输出 + GPIO (L58-61):                       │
     │  BDTR|=MOE  GPIOB15 AF3_TIM8                    │
     ├────────────────────────────────────────────────┤
     │ 启动 (L64-65):                                    │
     │  TIM1 CR1|=CEN  TIM8 CR1|=CEN                   │
     └────────────────────────────────────────────────┘
```

e2e 环境使用假 TIM 寄存器 + 假 GPIO 寄存器 + NVIC 追踪 stub，`register_set` 直接写入 fake_TIM1/fake_TIM8，`set_gpio_alternate` 写入 e2e_GPIO，`NVIC_DisableIRQ` 记录到追踪数组。

## 2. 输入因子

### 2.1 `clock_source_set_timer_params`

| 因子 | 类型 | 等价类 | 取值 |
|------|------|--------|------|
| `request` | uint8 | 0xe6 (唯一) | 0xe6 |
| `param1` | uint16 | 0, 100, 32767 | 0, 100, 32767 |
| `param2` | uint16 | 0, 50, 32767 | 0, 50, 32767 |

### 2.2 `clock_source_init`

| 因子 | 类型 | 等价类 | 取值 |
|------|------|--------|------|
| `enable_channel1` | bool | true, false | true, false |

## 3. 输出因子

### 3.1 `clock_source_set_timer_params` 输出 (clockSource)

| 输出 | 类型 | 说明 |
|------|------|------|
| clockSource.ccr1 | int | TIM1->CCR1 |
| clockSource.ccr2 | int | TIM1->CCR2 |
| clockSource.ccr3 | int | TIM8->CCR3 |
| clockSource.arr | int | TIM1->ARR |
| clockSource.ccr4 | int | TIM1->CCR4 |

### 3.2 `clock_source_init` 输出 (clockSourceInit, 26 fields)

| 输出 | 类型 | 说明 |
|------|------|------|
| tim1Psc | int | TIM1->PSC = 51199 |
| tim1Arr | int | TIM1->ARR = 499 |
| tim1Ccmr1 | int | TIM1->CCMR1 = 0x6060 |
| tim1Ccmr2 | int | TIM1->CCMR2 = 0x7060 |
| tim1Ccer | int | TIM1->CCER = 5 |
| tim1Ccr1 | int | TIM1->CCR1 = 20 |
| tim1Ccr2 | int | TIM1->CCR2 = 20 |
| tim1Ccr4 | int | TIM1->CCR4 = 250 |
| tim1Dier | int | TIM1->DIER = 3 |
| tim1Smcr | int | TIM1->SMCR = 0 |
| tim1Cr1 | int | TIM1->CR1 = 1 |
| tim1Cr2 | int | TIM1->CR2 = 0x70 |
| tim1Bdtr | int | TIM1->BDTR = 0x8000 |
| tim8Psc | int | TIM8->PSC = 51199 |
| tim8Arr | int | TIM8->ARR = 499 |
| tim8Ccmr2 | int | TIM8->CCMR2 = 0x60 |
| tim8Ccr3 | int | TIM8->CCR3 = 20 |
| tim8Ccer | int | TIM8->CCER = 0x10 |
| tim8Smcr | int | TIM8->SMCR = 4 |
| tim8Cr1 | int | TIM8->CR1 = 1 |
| tim8Bdtr | int | TIM8->BDTR = 0x8000 |
| gpioAModer | long | GPIOA MODER (pin 8 → alternate=2) |
| gpioAAfr1 | long | GPIOA AFR[1] (pin 8 → AF1) |
| gpioBModer | long | GPIOB MODER (pins 14+15 → alternate) |
| gpioBAfr1 | long | GPIOB AFR[1] (pin14→AF1, pin15→AF3) |
| nvicDisableIrqCount | int | NVIC_DisableIRQ 调用次数 = 2 |
| nvicDisableIrq0 | int | 第一个 IRQ = 25 |
| nvicDisableIrq1 | int | 第二个 IRQ = 27 |

## 4. 测试用例

### TC1-3: `clock_source_set_timer_params` (clock_source.feature)

#### TC1: param1=100, param2=50
- 输出: ccr1=0, ccr2=1000, ccr3=0, arr=499, ccr4=250
- 验证高低字节拆分逻辑

#### TC2: param1=0, param2=0
- 输出: ccr1=0, ccr2=0, ccr3=0, arr=65535, ccr4=32768
- 验证 ARR 溢出 mask 到 0xFFFF

#### TC3: param1=32767, param2=32767 (max short)
- 输出: ccr1=1270, ccr2=2550, ccr3=1270, arr=2549, ccr4=1275
- 验证 16-bit 边界拆分

### TC4-9: `clock_source_init` (clock_source_init.feature)

#### TC4: enable_channel1=true (全量寄存器)
- 输入: `clock_source_init(true)`
- 验证: 全部 24 个 TIM 寄存器 + 4 个 GPIO 寄存器 + 2 个 NVIC 计数 = 30 条断言
- 特征: `=` 精确匹配，覆盖所有字段

#### TC5: enable_channel1=false (GPIOA8 未使能)
- 输入: `clock_source_init(false)`
- 验证: gpioAModer=0, gpioAAfr1=0 (确认 channel1 分支未执行)

#### TC6: enable_channel1=false (GPIOB14/15 仍使能)
- 输入: `clock_source_init(false)`
- 验证: gpioBModer=2684354560, gpioBAfr1=822083584

#### TC7: BDTR MOE (TIM1 + TIM8)
- 输入: `clock_source_init(true)`
- 验证: tim1Bdtr=32768, tim8Bdtr=32768

#### TC8: CR1 CEN 启动位 (TIM1 + TIM8)
- 输入: `clock_source_init(true)`
- 验证: tim1Cr1=1, tim8Cr1=1

#### TC9: NVIC IRQ 禁用
- 输入: `clock_source_init(true)`
- 验证: nvicDisableIrqCount=2, Irq0=25, Irq1=27

## 5. 覆盖检查

### `clock_source_set_timer_params`

| 条件 | TC1 | TC2 | TC3 |
|------|-----|-----|-----|
| 正常值 | ✅ | — | — |
| 零值/溢出 | — | ✅ | — |
| 边界值 | — | — | ✅ |

### `clock_source_init`

| 路径 | TC4 | TC5 | TC6 | TC7 | TC8 | TC9 |
|------|-----|-----|-----|-----|-----|-----|
| enable_channel1=true | ✅ | — | — | ✅ | ✅ | ✅ |
| enable_channel1=false | — | ✅ | ✅ | — | — | — |
| TIM1 寄存器 (12 个) | ✅ | — | — | ✅ | ✅ | — |
| TIM8 寄存器 (8 个) | ✅ | — | — | ✅ | ✅ | — |
| GPIOA alternate | ✅ | ✅ | — | — | — | — |
| GPIOB alternate | ✅ | — | ✅ | — | — | — |
| NVIC_DisableIRQ | ✅ | — | — | — | — | ✅ |

✅ 所有等价类 + 路径已覆盖。28/28 可执行行已断言。

## 6. JNA 接口

`clock_source_init` 非 USB 命令，通过 JNA 直接调用：

| JNA 函数 | 返回值 | 说明 |
|----------|--------|------|
| `jna_clock_source_init(int)` | void | 调用 `clock_source_init(enable)` |
| `jna_get_TIM1_PSC/ARR/...` | uint32 | TIM1 寄存器 (12 个) |
| `jna_get_TIM8_PSC/ARR/...` | uint32 | TIM8 寄存器 (8 个) |
| `jna_get_reg_GPIOA_AFR1()` | uint32 | GPIOA AFR[1] |
| `jna_get_reg_GPIOB_AFR1()` | uint32 | GPIOB AFR[1] |
| `jna_get_nvic_disable_irq_count()` | int | NVIC 调用计数 |
| `jna_get_nvic_disable_irq_at(i)` | int | 第 i 次调用的 IRQ 号 |

其中 `NVIC_DisableIRQ` 从 no-op stub 改为追踪 stub，在 `jna_reset_power_save_tracking()` 中清零。

## 覆盖率

> 数据来源: `run_all_coverage.sh` 合并报告 (cuatro + tres + red)
> 综合行覆盖率: **95.0%**, `clock_source.h` 本文件 28/28 可执行行已断言 (2 行为 NVIC no-op 现已追踪)

| 源文件 | 行覆盖 | 说明 |
|--------|--------|------|
| `main_comms.h` | 93.3% (251/269) | USB 命令处理 |
| `clock_source.h` | **95.0%** (38/40) | ✅ 时钟源选择 (set_timer_params + init) |

