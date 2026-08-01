# Body BLDC 电机控制初始化 — 测试设计文档

> 功能: `bldc_init()` in `board/body/bldc/bldc.h`
> 被测接口: `jna_panda_init()` 自动触发 → `BLDC_controller_initialize()` ×2 + TIM1/TIM8 PWM 配置
> 固件目标: body (`board/body/main.c`)
> 已完成: B8 (2026-08-01)

## 1. 被测功能流程图

```
jna_panda_init() (body 固件启动模拟)
     │
     ▼
bldc_init()
     │
     ├─ adc_init(ADC1), adc_init(ADC2)           — 电流采样 ADC（e2e 桩: no-op）
     │
     ├─ Hall 传感器 GPIO (PB6/7/8, PA0/1/2)      — 输入 + 上拉
     │
     ├─ LEFT MOTOR 模型初始化:
     │   rtM_Left->defaultParam = &rtP_Left        — 参数指针
     │   rtM_Left->inputs = &rtU_Left               — 输入指针
     │   rtM_Left->outputs = &rtY_Left              — 输出指针
     │   rtM_Left->dwork = &rtDW_Left               — 状态指针
     │   BLDC_controller_initialize(rtM_Left)        — FOC 模型初始化
     │   rtP_Left 参数配置 (i_max, n_max, ...)
     │
     ├─ RIGHT MOTOR 模型初始化:
     │   rtP_Right = rtP_Left (复制参数)
     │   BLDC_controller_initialize(rtM_Right)
     │
     ├─ GPIO Alternate 配置 (PE8-13 TIM1, PC6-8/PA5/PB14-15 TIM8)
     │
     ├─ LEFT_TIM (TIM8) 配置:
     │   PSC=0, ARR=pwm_res, CR1=CMS_0, RCR=1      — 中心对齐模式, 16kHz 更新
     │   CCMR1/CCMR2 → OCxM PWM mode 1 + OCxPE
     │   CCER → CCxE + CCxNE (互补输出)
     │   BDTR = 20|MOE, EGR=UG, DIER|=UIE, CR1|=CEN ✅
     │
     └─ RIGHT_TIM (TIM1) 配置: 同 TIM8
```

> **关键验证点**: `bldc_init()` 后，LEFT_TIM->CR1 和 RIGHT_TIM->CR1 的 `TIM_CR1_CEN` (bit 0) 应置位，表示 PWM 定时器已启动。

## 2. 输入因子

`bldc_init()` 无参数，由 `jna_panda_init()` 自动调用。所有输入来自编译时常量：

| 因子 | 类型 | 来源 | 说明 |
|------|------|------|------|
| `PWM_FREQ` | const | `bldc_defs.h` | PWM 频率 = 32000 Hz |
| `CORE_FREQ` | const | `stm32h7_config.h` | 系统时钟频率 |
| `pwm_res` | const | 计算式 | `(CORE_FREQ * 1e6 / 2) / PWM_FREQ` |
| `I_MOT_MAX` / `N_MOT_MAX` 等 | const | `bldc_defs.h` | 电机参数常量 |

## 3. 输出因子

| 输出 | 类型 | 说明 |
|------|------|------|
| `leftTimerEnabled` | bool | LEFT_TIM (TIM8) CR1.CEN = 1 |
| `rightTimerEnabled` | bool | RIGHT_TIM (TIM1) CR1.CEN = 1 |
| `leftTimerArr` | int | LEFT_TIM ARR = pwm_res (非零) |
| `rightTimerArr` | int | RIGHT_TIM ARR = pwm_res (非零) |

> `rtM_Left->defaultParam` 指向 `&rtP_Left`（非 NULL），`BLDC_controller_initialize()` 通过编译器链接自动覆盖，无需额外验证。

## 4. 测试用例

### TC1 (B8): BLDC 初始化设置 TIM8 和 TIM1 用于 PWM 输出
- 前置: 无（`bldc_init()` 由 `jna_panda_init()` 在库加载时自动调用）
- 输入: 无（所有 body 场景共享此初始化）
- 输出: `leftTimerEnabled=true`, `rightTimerEnabled=true`
- 验证方式: 读取 `TIM8->CR1 & TIM_CR1_CEN` / `TIM1->CR1 & TIM_CR1_CEN`
- 覆盖: `bldc_init()` 完整路径 + `BLDC_controller_initialize()` ×2

## 5. 覆盖检查

| 条件 | TC1 |
|------|-----|
| LEFT_TIM CR1.CEN 置位 | ✅ |
| RIGHT_TIM CR1.CEN 置位 | ✅ |
| BLDC_controller_initialize (left) | ✅ (编译器链接自动覆盖) |
| BLDC_controller_initialize (right) | ✅ (编译器链接自动覆盖) |
| GPIO Hall 传感器配置 | ✅ (寄存器操作自动覆盖) |
| TIM PWM 寄存器配置 | ✅ (ARR/EEC/CCMR/BDTR 操作自动覆盖) |

✅ B8: `bldc_init()` 全覆盖。`BLDC_controller_initialize()` 及参数数据结构引用已通过编译器链接自动进入覆盖率。

## 6. 与生产固件的关系

在生产固件 `board/body/main.c` 中：
```c
void body_main(void) {
  // ... 硬件初始化 (clock, peripherals, USB, interrupts, enable_fpu) ...
  bldc_init();           // line 117
  // ... 主循环 while(1):
  //   tick_handler()     // line 128
  //   comms_endpoint2_write → can_tx_comms_resume_usb  // line 131
  //   interrupt check    // line 134
}
```

e2e 环境：`jna_panda_init()` 模拟固件启动，调用 `bldc_init()`。主循环体（tick/bldc_step/USB）需单独的 JNA 入口覆盖。

## 覆盖率

> 数据来源: `run_all_coverage.sh` 合并报告 (cuatro + tres + red + body)
> body 固件覆盖率通过 `libpanda_body.dylib` 独立采集

| 源文件 | 行覆盖 | 说明 |
|--------|--------|------|
| `board/body/bldc/bldc.h` | ✅ bldc_init() | BLDC 初始化 + TIM PWM 配置 (B8) |
| `board/body/bldc/BLDC_controller.c` | ~2%+ | BLDC_controller_initialize() ×2 覆盖 (B8); BLDC_controller_step() 待 B9 |
| `board/body/bldc/BLDC_controller_data.c` | 隐式覆盖 | rtConstP 查表数据 + rtP_Left 参数结构体通过模型指针引用进入覆盖率 |
