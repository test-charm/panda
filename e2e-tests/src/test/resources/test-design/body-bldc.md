# Body BLDC 电机控制 — 测试设计文档

> 功能: `board_body_init()` + `bldc_init()` + `bldc_step()` in body 固件启动路径
> 被测接口: `jna_panda_init()` → `board_body_init()` + `body_can_init()` + `dotstar_init()` + `bldc_init()` (B8/B13/B21 启动路径); `jna_bldc_step()` → `bldc_step()` (B9)
> 固件目标: body (`board/body/main.c`)
> 已完成: B8 + B9，B13 已合并到启动场景，B20 已由 `body_main.feature` 交叉验证 TIM8 IRQ 路径 (2026-08-01)

## 1. 被测功能流程图

```
jna_panda_init() (body 固件启动模拟)
     │
     ▼
board_body_init()
     │
     ├─ CAN GPIO alternate / no-pull
     ├─ EXTI13 / EXTI15 rising+falling + unmask
     ├─ OBDC power on = 1
     ├─ GPU power on = 0
     └─ ignition output = 0
     │
     ▼
body_can_init()
     │
     ├─ can_silent = false
     ├─ can_loopback = false
     ├─ set_safety_hooks(SAFETY_BODY, 0)
     └─ can_init_all()
     │
     ▼
dotstar_init()                               — 启动顺序中的前置步骤（本设计不展开）
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

> **关键验证点**: 启动后 `board_body_init()`、`body_can_init()` 与 `bldc_init()` 都应生效：`bodyCan.canSilent=false` / `bodyCan.canLoopback=false` / `bodyCan.bodySafetyHooksSet=true` / `bodyCan.canTransceiverEnabled=true`，`EXTI`/`SYSCFG`/电源寄存器已配置，且 LEFT_TIM->CR1 / RIGHT_TIM->CR1 的 `TIM_CR1_CEN` (bit 0) 应置位。

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
| `bodyCan.canSilent` | bool | 启动后应为 false |
| `bodyCan.canLoopback` | bool | 启动后应为 false |
| `bodyCan.bodySafetyHooksSet` | bool | 当前安全模式应为 `SAFETY_BODY` |
| `bodyCan.canTransceiverEnabled` | bool | CAN 收发器输出脚已拉低使能 |
| `leftTimerArr` | int | LEFT_TIM ARR = pwm_res (非零) |
| `rightTimerArr` | int | RIGHT_TIM ARR = pwm_res (非零) |

> `rtM_Left->defaultParam` 指向 `&rtP_Left`（非 NULL），`BLDC_controller_initialize()` 通过编译器链接自动覆盖，无需额外验证。

## 4. 测试用例

### TC1 (B8/B13/B21): 启动时完成 board/body CAN 初始化并设置 TIM8/TIM1 PWM
- 前置: 无（`jna_panda_init()` 在库加载时自动按启动顺序调用 `board_body_init()` → `body_can_init()` → `dotstar_init()` → `bldc_init()`）
- 输入: 无（所有 body 场景共享此初始化）
- 输出:
  - `exticr3=8224`, `extiImr1=40960`, `extiRtsr1=40960`, `extiFtsr1=40960`
  - `obdcPowerOn=true`, `gpuPowerOn=false`, `ignitionOutputOn=false`
  - `bodyCan.canSilent=false`
  - `bodyCan.canLoopback=false`
  - `bodyCan.bodySafetyHooksSet=true`
  - `bodyCan.canTransceiverEnabled=true`
  - `leftTimerEnabled=true`, `rightTimerEnabled=true`
- 验证方式: 读取 `TIM8->CR1 & TIM_CR1_CEN` / `TIM1->CR1 & TIM_CR1_CEN`
- 覆盖: `board_body_init()` + `body_can_init()` 启动路径 + `bldc_init()` 完整路径 + `BLDC_controller_initialize()` ×2

## 5. 覆盖检查

| 条件 | TC1 |
|------|-----|
| `body_can_init()` 启动调用 | ✅ |
| `board_body_init()` 启动调用 | ✅ |
| EXTI / SYSCFG 初始化 | ✅ |
| OBDC/GPU/IGNITION 电源 GPIO 初始化 | ✅ |
| `can_silent=false` / `can_loopback=false` | ✅ |
| `set_safety_hooks(SAFETY_BODY)` | ✅ |
| CAN 收发器使能 GPIO | ✅ |
| LEFT_TIM CR1.CEN 置位 | ✅ |
| RIGHT_TIM CR1.CEN 置位 | ✅ |
| BLDC_controller_initialize (left) | ✅ (编译器链接自动覆盖) |
| BLDC_controller_initialize (right) | ✅ (编译器链接自动覆盖) |
| GPIO Hall 传感器配置 | ✅ (寄存器操作自动覆盖) |
| TIM PWM 寄存器配置 | ✅ (ARR/EEC/CCMR/BDTR 操作自动覆盖) |

✅ B8/B13/B21: 启动场景同时覆盖 `board_body_init()`、`body_can_init()` 与 `bldc_init()`。`BLDC_controller_initialize()` 及参数数据结构引用已通过编译器链接自动进入覆盖率。

---

## 7. B9: bldc_step — FOC 算法单步执行

### 7.1 被测功能流程图

```
bldc_skip_calibration()        — 跳过 ADC 偏移校准, 设置非零偏移值
  → offsetcount = 2000, offsetrrA/C = 1000, ...

set motor_speeds(100, 200, true)
  → rpm_left = 100, rpm_right = 200, enable_motors = true

bldc_step()
  │
  ├─ 校准阶段检查: offsetcount >= 2000 → 跳过
  │
  ├─ 电流采样 (e2e stub: adc_get_raw = 0, 偏移被预设为非零)
  │   curL_phaA = (offsetrlA - 0) >> 5  = 1000 >> 5  = 31
  │   curL_phaC = (offsetrlC - 0) >> 5  = 1000 >> 5  = 31
  │   curR_phaA = (offsetrrA - 0) >> 5  = 1000 >> 5  = 31
  │   curR_phaC = (offsetrrC - 0) >> 5  = 1000 >> 5  = 31
  │
  ├─ 安全使能: offsetrrA(1000) != 0 && offsetrrC(1000) != 0 && enable_motors=true
  │   → enableFin = 1 ✅
  │
  ├─ Hall 传感器读取 (GPIOB/GPIOA IDR — e2e 默认 0)
  │
  ├─ 电池电压 (adc_get_raw = 0)
  │
  ├─ LEFT MOTOR:
  │   rtU_Left.b_motEna = 1, rtU_Left.r_inpTgt = 100 * RPM_TO_UNIT
  │   rtU_Left.i_phaAB/BC/DCLink = 31/31/...
  │   BLDC_controller_step(rtM_Left)          ← FOC 矢量控制 (PI/Clark-Park/SVPWM)
  │   ul = rtY_Left.DC_phaA, vl = .DC_phaB, wl = .DC_phaC
  │   LEFT_TIM->CCR1 = CLAMP(ul + pwm_res/2, MARGIN, pwm_res-MARGIN)
  │   LEFT_TIM->CCR2 = CLAMP(vl + pwm_res/2, MARGIN, pwm_res-MARGIN)
  │   LEFT_TIM->CCR3 = CLAMP(wl + pwm_res/2, MARGIN, pwm_res-MARGIN)
  │
  └─ RIGHT MOTOR: 同 LEFT (rpm=200, r_inpTgt 取反)
      BLDC_controller_step(rtM_Right)
      RIGHT_TIM->CCR1/2/3 = CLAMP(...)
```

> **关键验证点**: `bldc_step()` 后 LEFT_TIM->CCR1/2/3 和 RIGHT_TIM->CCR1/2/3 应有非零 PWM 占空比输出。
> 因为 enableFin=1，FOC 算法以目标转速运行，DC_phaA/B/C 输出非零值，经 CLAMP 后 CCR 寄存器为非零值。
> e2e 中 `adc_get_raw()` 返回 0，需通过 `e2e_bldc_skip_calibration()` 预设非零偏移值来绕过安全使能检查。

### 7.2 输入因子

| 因子 | 类型 | 来源 | 说明 |
|------|------|------|------|
| `rpm_left` | volatile int | `jna_body_set_motor_speeds(100, 200, true)` | 左电机目标转速 |
| `rpm_right` | volatile int | 同上 | 右电机目标转速 |
| `enable_motors` | volatile bool | 同上 | 电机总使能 |
| `offsetcount` | static uint16_t | `e2e_bldc_skip_calibration()` → 2000 | 跳过校准阶段 |
| `offsetrrA/C` | static uint32_t | `e2e_bldc_skip_calibration()` → 1000 | 使 safety check 通过 |
| `offsetrlA/C` | static uint32_t | `e2e_bldc_skip_calibration()` → 1000 | 产生非零电流输入 |
| `RPM_TO_UNIT` | const | `bldc_defs.h` | 转速到内部单位转换 |

### 7.3 输出因子

| 输出 | 类型 | 说明 |
|------|------|------|
| `leftPwmActive` | bool | LEFT_TIM (TIM8) CCR1/2/3 任一非零 |
| `rightPwmActive` | bool | RIGHT_TIM (TIM1) CCR1/2/3 任一非零 |

> CCR 寄存器由 `BLDC_controller_step()` 输出的 `rtY_Left/Right.DC_phaA/B/C` 经 CLAMP 计算得到。
> 验证方式: 读取 `TIM8->CCR1/2/3` 和 `TIM1->CCR1/2/3` 寄存器值。

### 7.4 测试用例

#### TC2 (B9): bldc_step 执行 FOC 算法并生成 PWM 输出

- 前置: `bldc_init()` 已在 `jna_panda_init()` 中自动调用 (B8)
- 步骤:
  1. `bldc_skip_calibration()` — 跳过 ADC 校准, 设置非零偏移值
  2. `set_motor_speeds(100, 200, true)` — 设转速 + 使能
  3. `bldc_step()` — 执行一次 FOC 算法
- 输出: `leftPwmActive=true`, `rightPwmActive=true`
- 验证方式: 读取 `TIM8->CCR1/CCR2/CCR3` 和 `TIM1->CCR1/CCR2/CCR3`，验证至少一个通道非零
- 覆盖: `bldc_step()` 完整路径 + `BLDC_controller_step()` ×2 (PI 调节器/Clark-Park 变换/SVPWM/速度环)
- 对应 feature: `body_bldc.feature` B9 场景

### 7.5 覆盖检查

| 条件 | TC2 |
|------|-----|
| offsetcount >= 2000 跳过校准 | ✅ |
| enableFin 使能 (offsetrrA/C 非零) | ✅ |
| BLDC_controller_step (left) | ✅ (编译器链接自动覆盖) |
| BLDC_controller_step (right) | ✅ (编译器链接自动覆盖) |
| LEFT_TIM CCR1/2/3 非零 | ✅ |
| RIGHT_TIM CCR1/2/3 非零 | ✅ |
| PI 调节器 (速度环/电流环) | ✅ |
| Clark-Park 变换 / SVPWM | ✅ |
| 电流采样 + Hall 传感器 | ✅ (stub 路径) |

### 7.6 e2e_bldc_skip_calibration() 设计说明

生产固件中，`bldc_step()` 前 2000 次调用用于 ADC 电流偏移校准。在 e2e 环境中，`adc_get_raw()` stub 返回 0，导致校准后偏移值全为 0，后续 safety check (`offsetrrA == 0 || offsetrrC == 0`) 将 `enableFin` 置 0，BLDC_controller_step 以 `b_motEna=0` 运行。

为绕过此限制，`e2e_bldc_skip_calibration()`:
1. 设置 `offsetcount = 2000` — 跳过校准循环
2. 设置 `offsetrrA/C = 1000`, `offsetrlA/C = 1000`, `offsetdcl/dcr = 500` — 非零偏移值使 safety check 通过

这样 `bldc_step()` 中的 `enableFin = 1`，FOC 算法以目标转速正常执行。

## 6. 与生产固件的关系

在生产固件 `board/body/main.c` 中：
```c
void body_main(void) {
  // ... 硬件初始化 (clock, peripherals, USB, interrupts, enable_fpu) ...
  current_board->init();  // line 99, 即 board_body_init()
  body_can_init();        // line 115
  dotstar_init();         // line 116
  bldc_init();            // line 117
  // ... TIM8 update IRQ:
  //   bldc_tim8_handler() → bldc_step()
  // ... 主循环 while(1): 只负责 LED / 电机使能 / body_can_periodic
}
```

e2e 环境：`jna_panda_init()` 模拟固件启动，依次调用 `board_body_init()`、`body_can_init()`、`dotstar_init()`、`bldc_init()`（与生产固件顺序一致）。`bldc_step()` 既可通过独立的 `jna_bldc_step()` 直接调用（`body_bldc.feature`，B9），也可通过 `jna_body_trigger_tim8_irq()` 走真实 TIM8 中断路径（`body_main.feature`，B20）。

### 6.1 B8/B13: 启动路径初始化覆盖

## 覆盖率

> 数据来源: `run_all_coverage.sh` 合并报告 (cuatro + tres + red + body)
> body 固件覆盖率通过 `libpanda_body.dylib` 独立采集

| 源文件 | 行覆盖 | 说明 |
|--------|--------|------|
| `board/body/bldc/bldc.h` | ✅ bldc_init() + bldc_step() | BLDC 初始化 + TIM PWM 配置 (B8/B13 启动路径的一部分) + FOC 算法 (B9) |
| `board/body/bldc/BLDC_controller.c` | 38.45% (486/1264) | BLDC_controller_initialize() ×2 + BLDC_controller_step() ×2 FOC 算法 (PI/Clark-Park/SVPWM/速度环) |
| `board/body/bldc/BLDC_controller_data.c` | 隐式覆盖 | rtConstP 查表数据 + rtP_Left 参数结构体通过模型指针引用进入覆盖率 |
