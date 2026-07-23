# 深度休眠请求 — 测试设计文档

> 功能: request deep sleep via `comms_control_handler()` in `board/main_comms.h`
> 被测接口: USB control request 0xb5 (DEBUG: enter silent + stop mode)
> 条件: `#ifdef ALLOW_DEBUG`（e2e 构建已启用）

## 1. 被测功能流程图

```
request deep sleep (0xb5):
  [controlWrite(0xb5, 0, 0)]
           │
           ▼
  set_safety_mode(SAFETY_SILENT, 0)
           │
           ▼
  set_power_save_state(true)
           │
           ▼
  stop_mode_requested = true
           │
           ▼
  [processStopMode()]  ← 模拟 main.c 主循环
           │
           ▼
  enter_stop_mode()    ← 从 board/sys/power_saving.h 逐字提取
           │
     ┌─────┼─────────────────────────────────────┐
     ▼     ▼     ▼     ▼     ▼     ▼     ▼     ▼
   GPIO  ADC   RCC  SYSCFG EXTI  PWR   SCB   NVIC
  MODER   CR   LPENR EXTICR IMR1 CPUCR  SCR  ICER
  =0xFF  =DEEPPWD =0  配置  唤醒   STOP SLEEPDEEP 禁用
           │
           ▼
  NVIC_SystemReset()
```

代码路径: 0xb5 触发三段操作 → 主循环检查 `stop_mode_requested` → `enter_stop_mode()` 执行 12 个硬件操作组 → 系统复位。

## 2. `enter_stop_mode()` 硬件操作序列

| 步骤 | 操作 | 假寄存器 | 预期值 |
|------|------|---------|--------|
| 1 | GPIOA-G MODER 设为全模拟 | `gpioAModer`-`gpioGModer` | `0xFFFFFFFF` |
| 2 | set_bootkick(BOOT_STANDBY) | `bootkick_state` (桩) | `0` |
| 3 | set_amp_enabled(false) | `amp_enabled` (桩) | `false` |
| 4 | enable_can_transceiver(1..4, false) | `can_transceiver_disable_count` (桩) | `4` |
| 5 | ADC1/2 深度掉电 (DEEPPWD) | `adc1Cr` / `adc2Cr` | `0x20000000` |
| 6 | 禁用 HSI48 USB 时钟 | `rccCr` (bit 12) | bit12=0 |
| 7 | 禁用 SRAM 保留 (全部域) | `rccAhb2lpenr` / `ahb3` / `ahb4` | `0` |
| 8 | 配置 SBU EXTI 唤醒 | `syscfgExticr[0-1]`, `extiImr1`(bit1,4), `extiRtsr1`(bit1,4), `extiFtsr1`(bit1,4) | 见 TC5 |
| 9 | 配置 CAN EXTI 唤醒 | `syscfgExticr[1-3]`, `extiImr1`(bit5,8,12), `extiFtsr1`(bit5,8,12) | 见 TC5 |
| 10 | 清除 EXTI 挂起 | `extiPr1` (写 1 清零) | 存写入值 |
| 11 | 点火检测 (提前复位) | `harness_check_ignition()` → `NVIC_SystemReset` | 桩返回 false，跳过 |
| 12 | PWR STOP 模式 + SVOS5 + FLPS | `pwrCpucr` / `pwrCr1` | `0` / `0x4200` |
| 13 | SCB SLEEPDEEP | `scbScr` | `0x4` |
| 14 | NVIC 全部禁用 + 使能唤醒 EXTI | `nvicIcer0` | `0xFFFFFFFF` |
| 15 | WFI → NVIC_SystemReset | `nvicResetCount` | `1` |

## 3. 输入因子

| 因子 | 类型 | 等价类 | 取值 |
|------|------|--------|------|
| `request` | uint8 | 0xb5 (唯一) | 0xb5 |
| `stop_mode_requested` | boolean | true → 进 enter_stop_mode | true |
| `stop_mode_requested` | boolean | false → 跳过 | false |

## 4. 输出因子

| 输出 | 类型 | 说明 |
|------|------|------|
| relayCall.a / relayCall.b | boolean | SILENT 模式关断继电器 |
| powerSaveEnabled | boolean | 省电模式已启用 |
| stopModeRequested | boolean | 标志已置位 |
| enterStopModeCallCount | int | `enter_stop_mode()` 调用次数 |
| stopModeRegs.* (25 个寄存器) | long | 假外设寄存器值 |
| nvicResetCount | int | `NVIC_SystemReset()` 调用次数 |

## 5. 测试用例

### TC1: 触发深度休眠请求
- 输入: request=0xb5
- 验证: `relayCall={a:false, b:false}`, `powerSaveEnabled=true`, `stopModeRequested=true`, `irqDisableCount=2`

### TC2: GPIO 全模拟模式
- 前置: TC1
- 输入: processStopMode()
- 验证: `gpioAModer`-`gpioGModer` = `0xFFFFFFFF`

### TC3: ADC 深度掉电
- 前置: TC1
- 输入: processStopMode()
- 验证: `adc1Cr`=`adc2Cr`=`0x20000000` (DEEPPWD=1, ADEN=0)

### TC4: HSI48 时钟禁用
- 前置: TC1
- 输入: processStopMode()
- 验证: `rccCr` bit12=0 (HSI48ON 已清除)

### TC5: SRAM 保留全部禁用
- 前置: TC1
- 输入: processStopMode()
- 验证: `rccAhb2lpenr`=`rccAhb3lpenr`=`rccAhb4lpenr`=`0`

### TC6: EXTI 唤醒配置
- 前置: TC1
- 输入: processStopMode()
- 验证:
  - `syscfgExticr0`=0 (EXTI1_PA), `syscfgExticr1`=0x12 (EXTI4_PC|EXTI5_PB), `syscfgExticr2`=1 (EXTI8_PB), `syscfgExticr3`=3 (EXTI12_PD)
  - `extiImr1`=4402 (bits 1,4,5,8,12), `extiRtsr1`=18 (bits 1,4), `extiFtsr1`=4402

### TC7: PWR STOP 模式配置
- 前置: TC1
- 输入: processStopMode()
- 验证: `pwrCpucr`=0 (PDDS 全清, STOP 模式), `pwrCr1`=16896 (SVOS_0|FLPS)

### TC8: SCB SLEEPDEEP + NVIC 系统复位
- 前置: TC1
- 输入: processStopMode()
- 验证: `scbScr`=4 (SLEEPDEEP), `nvicIcer0`=0xFFFFFFFF, `nvicResetCount`=1

## 6. 覆盖检查

| 条件 | 覆盖 |
|------|------|
| request == 0xb5 (set_safety_mode SILENT) | TC1 |
| request == 0xb5 (set_power_save_state) | TC1 |
| request == 0xb5 (stop_mode_requested=true) | TC1 |
| stop_mode_requested==true → enter_stop_mode() | TC2-TC8 |
| GPIO MODER analog (7 个寄存器) | TC2 |
| ADC1/2 DEEPPWD | TC3 |
| HSI48 disable | TC4 |
| SRAM retention disable (3 域) | TC5 |
| SBU EXTI 配置 (SYSCFG + EXTI) | TC6 |
| CAN EXTI 配置 (SYSCFG + EXTI) | TC6 |
| PWR STOP 模式 + 电压缩放 | TC7 |
| SCB SLEEPDEEP | TC8 |
| NVIC 禁用 + 唤醒 EXTI | TC8 |
| NVIC_SystemReset | TC8 |
| stop_mode_requested==false → 跳过 | TC1 (仅验证标志, 不进 enter_stop_mode) |

✅ 全部 15 个代码路径已覆盖。

## 7. 架构说明

`enter_stop_mode()` 从 `board/sys/power_saving.h` 逐字提取（`generate_enter_stop_mode_stubs.py`），直接操作假硬件寄存器实例（`e2e_GPIOA.MODER`、`e2e_RCC.CR` 等）。`register_set` / `register_clear_bits` / `register_set_bits` 将真实固件的寄存器写入重定向到这些假实例上，测试通过 JNA 读取寄存器值进行验证。

覆盖率报告 (`coverage-report.sh`) 已将 `enter_stop_mode_e2e.gen.c` 排除，避免自动生成代码影响覆盖率统计。
