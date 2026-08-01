# 端到端测试机制说明

## 概览

`e2e-tests/` 是基于 Cucumber JVM + test-charm 框架的端到端测试项目，**不需要 panda 硬件**。

核心思路：将 `board/main.c` 编译为宿主共享库 (`.dylib`)，通过 JNA 在 Java 中调用真实生产代码。采用**假硬件寄存器 + 生产代码**模式：为 STM32H7 外设创建假寄存器实例，让生产代码直接操作这些假寄存器，测试断言寄存器位模式。

```
board/main.c (生产代码，逐字编译)
  │  register_set / register_set_bits / register_clear_bits
  │  set_gpio_output / set_gpio_mode (board/drivers/gpio.h 生产代码)
  │  current_board->set_bootkick / enable_can_transceiver (生产代码)
  ▼
假硬件寄存器 (libpanda.c 中的 e2e_GPIOA.MODER, e2e_RCC.CR, ...)
  │
  ▼ JNA 访问器
PandaClient.java → StopModeRegs DTO
  │
  ▼
Cucumber BDD 断言: gpioAModer: 0xFFFFFFF1, rccCr: 0x0, ...
```

## 多板支持

```bash
./gradlew cucumber -Pboard=cuatro  # 默认
./gradlew cucumber -Pboard=tres
./gradlew cucumber -Pboard=red
./gradlew cucumber -Pboard=body    # Body 固件
```

构建输出 `libpanda_${board}.dylib`，编译宏 `-DE2E_BOARD_CUATRO/TRES/RED` 控制板级 GPIO 引脚选择，`-DPANDA_BODY` 激活 body 固件路径。`@cuatro/@tres/@red/@body` 标签过滤板特定场景。

body 固件使用独立的 C 入口 `libpanda_body.c`（而非 `libpanda.c`），因为 body 依赖不同的硬件外设（BLDC 电机、DotStar LED）且不包含 panda 的 harness/SPI/风扇等。

## 自动生成代码

以下文件由 Python 脚本从生产代码提取，`build.sh` 在编译前自动生成：

| 生成文件 | 来源 | 内容 |
|---------|------|------|
| _(已全部消除)_ | — | C1/C2/C3 完成后已不再有 gen 文件 |

> ✅ B1/B2/B4/B5/C1/C2/C3 全部完成。所有 gen 脚本和桩文件已消除，生产代码直接编译。

## 假硬件寄存器

`libpanda.c` 中为 `enter_stop_mode()` 涉及的外设创建假寄存器实例：

| 外设 | 假实例 | 访问的生产代码 |
|------|--------|--------------|
| GPIO A-G | `e2e_GPIOA`..`e2e_GPIOG` | `board/drivers/gpio.h` (set_gpio_output, set_gpio_mode) |
| ADC1/2 | `e2e_ADC1`, `e2e_ADC2` | 寄存器直接操作。lladc.h stub 拦截 ch4/ch17 (SBU) + ch8/ch3 (电压/电流)，返回可配置全局变量 |
| RCC | `e2e_RCC` | 时钟控制 |
| SYSCFG | `e2e_SYSCFG` | EXTI 配置 |
| EXTI | `e2e_EXTI` | 中断/唤醒 |
| PWR | `e2e_PWR` | 电源模式 |
| NVIC | `e2e_NVIC` | 中断控制 |
| SCB | `e2e_SCB` | 系统控制 |
| TIM1 | `fake_TIM1` | IR PWM, 时钟源 |
| TIM3 | `fake_TIM3` | LED PWM (led_init / led_set) |
| TIM8 | `fake_TIM8` | 时钟源从定时器 |
| FDCAN1/2/3 | `fake_fdcan[3]` | FDCAN 寄存器（CCCR/IE/NBTP/DBTP/TXBC/RXF0C/TXESC/RXESC/GFC/ILE/IR/TXFQS/TXBAR） ✅ C3 |
| FDCAN SRAM | `fake_fdcan_sram[0x4000]` | FDCAN 消息 RAM ✅ C3 |

`GPIO_TypeDef` 在 `fake_stm.h` 中定义为完整结构体（匹配 STM32H7 字段偏移），`board/drivers/gpio.h` 的生产代码可直接使用。

## Tick 模拟

部分硬件操作由 `main.c` 的 tick handler 触发，测试通过显式 JNA 调用模拟：

| 函数 | 模拟的操作 |
|------|-----------|
| `jna_call_tick_handler()` | 完整 `tick_handler()`（8Hz + 1Hz 块）。8 次调用 = 1 个 1Hz tick |
| `jna_process_stop_mode()` | 主循环检查 `stop_mode_requested` → `enter_stop_mode()` |
| `jna_process_wfi_idle()` | 主循环 WFI 空闲路径 (power_save + 非 CUATRO 深度休眠) → `__WFI()` + SLEEPDEEP 清除 |
| `jna_tick_siren()` | tick handler 读 `siren_enabled` → `current_board->set_siren()` |
| `jna_set_microsecond_timer()` | 预设微秒定时器值 |
| `jna_set_mcu_uid()` / `jna_set_serial()` / `jna_set_provision()` | 预设 OTP 内存区域 |
| `jna_set_interrupt_call_rate()` | 预设中断调用率 |
| `jna_set_signature_chunk()` / `jna_set_app_code_len()` | 预设固件签名数据 |
| `jna_uart_push()` | 向 UART debug ring 推送字符 |
| `jna_handle_interrupt()` | 模拟中断触发 → `handle_interrupt()` ✅ Phase H |
| `jna_interrupt_timer_tick()` | 触发 1 秒定时器中断 → `interrupt_timer_handler()` ✅ Phase H |
| `jna_get_interrupt_load()` | 读取 `interrupt_load` ✅ Phase H |
| `jna_get_interrupt_call_counter()` | 读取中断调用计数器 ✅ Phase H |
| `jna_is_unused_handler()` | 检查中断 handler 是否为 `unused_interrupt_handler` ✅ Phase H |
| `jna_board_init()` | 重置 GPIO/PWR/TIM，预置 USB33RDY → `current_board->init()` (N2) |
| `jna_get_TIM3_*` 系列 (9) | 读取 TIM3 CR1/ARR/CCMR1/CCMR2/CCER/CCR1-4 (LED PWM 验证) |
| `jna_reset_*` 系列 (15+) | 每次 `@Before` 中重置所有假状态 |
| `jna_fdcan_write_rx_fifo(n, idx, ext, addr, fd, brs, dlc, data)` | 向假 FDCAN SRAM 注入 CAN 帧 |
| `jna_set_fdcan_rxf0s/ir(n, val)` | 设置 RXF0S/IR 寄存器（F0FL/F0F/F0GI / RF0N/PED/PEA） |
| `jna_get_can_health_total_rx_cnt/fwd_cnt(bus)` | 读取 `can_health[]` 计数器 |
| `jna_get_direct_safety_rx_invalid()` | 读取 `safety_rx_invalid` 原始值 |
| `jna_set_bus_forwarding_bus(bus, fwd)` | 设置 `bus_config[].forwarding_bus` |
| `jna_get_bus_config_canfd_enabled/brs_enabled(bus)` | 读取 CAN-FD/BRS 自动检测标志 |
| `jna_pwm_init_channel_3()` | 调用 `pwm_init(TIM3, 3)` (llfan stub 路径) ✅ J12b |
| `jna_enter_stop_mode_ignition_on()` | 模拟 ignition ON → `enter_stop_mode()` → `NVIC_SystemReset` ✅ J12c |
| `jna_spi_init()` | 调用 `spi_init()` (覆盖 DMA 初始化) ✅ J13 |

## 目录结构

```
e2e-tests/
├── build.gradle
├── run_all_coverage.sh               # 全板覆盖率合并（含 body）
├── scripts/coverage-report.sh        # 覆盖率报告（支持多板）
├── src/test/
│   ├── c/
│   │   ├── build.sh                  # 编译（支持 BOARD=body）
│   │   ├── fake_stm.h                # GPIO_TypeDef 完整结构体 + CMSIS 桩
│   │   ├── fdcan_regs.h              # FDCAN 寄存器类型定义
│   │   ├── libpanda.c                # 假寄存器实例 + JNA 访问器 (panda)
│   │   ├── libpanda_body.c           # 假寄存器实例 + JNA 访问器 (body)
│   │   ├── stm32h7xx.h               # 最小 CMSIS 桩（body 编译用）
│   │   ├── board/
│   │   │   ├── drivers/              # 仅 2 个必须桩 (fake_siren.h, usb.h)
│   │   │   ├── stm32h7/              # board.h / lladc.h ADC 拦截桩
│   │   │   ├── obj/gitversion.h      # 固件版本桩
│   │   │   └── body/bldc/bldc.h      # BLDC Simulink 桩（body）
│   │   └── bldc/                     # （已清理，实际使用 board/body/bldc/）
│   ├── java/com/panda/e2e/
│   │   ├── PandaClient.java          # JNA 接口 (panda)
│   │   ├── BodyPandaClient.java      # JNA 接口 (body)
│   │   ├── PandaSteps.java           # BDD 步骤定义 (panda)
│       │   ├── BodyCommandsStepDefs.java # BDD 步骤定义 (body: control write, setup write, verify)
│   │   ├── ApplicationSteps.java     # @Before setUp
│   │   └── spec/
│   │       ├── UsbControlRequests.java   # 33 个 USB 控制请求 spec (panda)
│       │       ├── BodyUsbControlRequests.java # 5 个 USB 控制请求 spec + BodyControlSetup (body)
│   │       ├── ControlSetups.java    # 前置数据 spec (panda)
│   │       ├── CanSendRequests.java  # CAN 发送 spec
│   │       └── ...
│   └── resources/
│       ├── features/                 # 38 个 feature 文件（含 body_commands/body_shared_commands）
│       └── test-design/              # 测试设计文档
```

## 被测功能覆盖

| 功能 | Feature | 场景 | 验证方式 |
|------|---------|------|---------|
| 安全模式 | `safety_mode.feature` | 10 | FDCAN CCCR, gpioAOdr |
| CAN 回环 | `can_loopback.feature` | 4 | FDCAN TEST/MON |
| 心跳 | `heartbeat.feature` | 6 | heartbeat_* 变量 |
| 心跳丢失 | `heartbeat_loss.feature` | 9 | safetyState + powerSaveTracking 通过 jna_call_tick_handler |
| 健康/版本数据包 | `health.feature` | 11 | 合并了 health + get_version + packet_versions + signature (第十三节 B2+B4+B7)，电压/电流通过真实 `cuatro_read_voltage_mV`/`cuatro_read_current_mA` 验证 |
| CAN 模式 | `can_mode.feature` | 6 | stopModeRegs (gpioBModer/gpioBOdr/gpioBPupdr) |
| 继电器 | `relay.feature` | 6 | stopModeRegs.gpioAOdr (PA3/PA9) |
| 省电模式 | `power_save.feature` | 16 | powerSaveTracking + stopModeRegs (gpioBOdr/gpioDOdr/gpioGOdr) + flipped harness disable |
| 替代体验 | `alternative_experience.feature` | 5 | alternativeExperience |
| 警笛 | `siren.feature` | 4 | stopModeRegs.gpioBOdr (PB14) via tick_handler + @red unused 验证 ✅ D.2 |
| 系统复位与 Bootloader | `system_reset_bootloader.feature` | 4 | 合并了 reset_st + bootloader (第十三节 D4+D5) |
| CAN 通信序列化 | `can_comms.feature` | 14 | USB ep3 out → comms_can_write → rxQueue, USB ep1 in → comms_can_read → usbEp1InBytes (含 overflow 分片 5 场景 + 队列指针回绕 5 场景, Phase D.3 + C1 ✅) |
| CAN 环形缓冲 | `can_ring_clear.feature` | 4 | rxQueue/txQueue |
| FDCAN 中断处理 | `fdcan_interrupt.feature` | 15 | process_can → TXBAR/IR/rxQueue, 0xff 守卫, can_rx 全路径 (标准帧/扩展帧/CAN-FD/BRS/FIFO满/转发/IRQ错误/safety_rx_invalid/checksum error), interrupt_rate 合并, Phase J: J3 bad checksum + J4 all FDCAN handlers ✅ |
| 中断处理与频率限制 | `interrupt_rate.feature` | 5 | handle_interrupt → unused_handler fault + rate-limit fault, interrupt_timer_handler 重置计数器 + rate print ✅ Phase J: J6 |
| GPIO 与线束初始化 | `gpio_harness.feature` | 3 | gpio PUSH_PULL (J1) + harness_init relay (J2) + detect_with_pull (J10) ✅ Phase J |
| UART Ring Buffer | `uart_overwrite.feature` | 2 | put_char + injectc overwrite 模式 ring buffer 覆盖 ✅ Phase J: J5 |
| libc 工具函数 | `libc.feature` | 4 | lastMemcmpResult / delay 不挂死 |
| IR 功率 | `ir_power.feature` | 4 | irPwm (TIM1 CCR1) + @red unused 验证 ✅ D.2 |
| CAN 波特率 | `can_bitrate.feature` | 4 | FDCAN NBTP/CCCR/IE/TXBC/RXF0C (Phase J: J7 低速 prescaler + J8 修复 0xde) |
| CAN FD 配置 | `can_fd_data_bitrate.feature` | 10 | 合并了 FD 数据波特率 + Non-ISO + 自动切换 (Phase J: J9 5Mbps 数据速率) |
| 时钟源 | `clock_source.feature` | 9 | clockSource (TIM1/TIM8 CCR) + clockSourceInit (第十三节 C2) |
| 板级初始化 | `board_init.feature` | 7 | boardInit (GPIO MODER/OTYPER/OSPEEDR/PUPDR/AFR/ODR ×45, PWR_CR3) — N2 完成 |
| LED PWM 初始化 | `led_pwm.feature` | 7 | ledPwmState (TIM3 CR1/ARR/CCMR1/CCMR2/CCER/CCR1-4) — pwm.h/led.h 去桩化 ✅ + pwm_init ch3 ✅ |
| 定时器/风扇 | `timer_fan.feature` | 2 | 合并覆盖 microsecond_timer (第十三节 A1) |
| 风扇功率 | `fan_power.feature` | 10 | fanPower + stopModeRegs.gpioDOdr (PD3 板级验证 + unused JNA ✅ D.2) |
| 风扇冷却 | `fan_cooldown.feature` | 3 | fanCooldownCounter + fanPower 通过 jna_call_tick_handler |
| 深度休眠 | `deep_sleep.feature` | 14 | stopModeRegs (25+ 假寄存器: GPIO/ADC/RCC/SYSCFG/EXTI/PWR/SCB/NVIC) + ignition ON NVIC_SystemReset |
| SOM GPIO | `som_gpio.feature` | 2 | respBuffer + @red unused 验证 ✅ D.2 |
| CAN 健康 | `can_health.feature` | 7 | canHealth0 (PSR/ECR 提取 + DLEC lastDataStoredError) |
| UART 读取 | `spi_state_machine.feature` (已合并) | 3 | respBuffer (字符读取 / 空) — 第十三节 B8 合并 ✅ |
| Bootkick SOM 复位 | `bootkick.feature` | 14 | tick_handler FSM (state/waitingCountdown/resetCountdown/resetTriggered) + stopModeRegs (gpioAOdr/gpioCOdr) 通过 jna_call_tick_handler |
| 继电器故障 | `relay_malfunction.feature` | 3 | readFaults (FAULT_RELAY_MALFUNCTION 边沿检测) |
| 永久故障 | `permanent_fault.feature` | 2 | readFaults + faultStatus (FAULT_STATUS_PERMANENT 不可恢复) |
| WFI 空闲路径 | `wfi_idle.feature` | 3 | stopModeRegs (wfiEntered + scbScr, 通过 `jna_process_wfi_idle`) |
| ignition_can 自动复位 | `ignition_can.feature` | 2 | ignitionCan (通过 `jna_set_ignition_can` + `jna_call_tick_handler`) |
| 线束翻转检测 | `harness_detect.feature` | 8 | harnessStatus (生产 `harness_detect_orientation()` ✅ B5 + ADC 拦截桩) |
| Tick 路径 | `tick_paths.feature` | 12 | has_fan=false, heartbeat_counter 溢出, safety_mode_cnt 溢出, harness reinit + register_divergence + watchdog (P1 + C4+C5) |
| SPI Version Packet + Device ID | `spi_version_packet.feature` | 7 | spiVersionResult + serial/provision + USB 0xc3 MCU UID (Phase J) |
| SPI 状态机 | `spi_state_machine.feature` | 31 | spiStateResult (生产 `spi_rx_done()` + `spi_tx_done()` + `spi_init()` ✅ J13 全状态覆盖 + endpoint2_write 合并 (第十三节 C6) + uart_read 合并 (第十三节 B8) ✅ Phase F.5) |
| **Body 固件** | | | |
| Body 电机命令 | `body_commands.feature` | 5 | rpmLeft/rpmRight/motorEnabled (0xb3/0xb4 通过 `board/body/main_comms.h`) |
| Body 共享命令 | `body_shared_commands.feature` | 8 | hwType/respBuffer/nvicResetCount/enterBootloaderMode (0xc1/0xd1/0xd3/0xd4/0xd6/0xd8/0xdd, B1-B7 全部覆盖) |

## C 代码覆盖率

> 数据来源: `e2e-tests/run_all_coverage.sh` 合并报告 (cuatro + tres + red + body)
> 生成时间: 2026-08-01 (B1-B7: body 共享命令全覆盖)
> IGNORE_REGEX: 已排除 e2e stub (`bldc.h`, `stm32h7xx.h`)

| 源文件 | 行覆盖 | 函数覆盖 | 说明 |
|--------|--------|---------|------|
| `board/main_comms.h` | **97.0%** (261/269) | 3/3 | USB 命令处理 (Phase J: 新增 0xc3 MCU UID + 修复 0xde) |
| `board/main.c` | **64.2%** (145/226) | 4/7 | 主循环 + 初始化 |
| `board/body/main_comms.h` | **86.4%** (57/66) | — | ✅ body 共享命令 B1-B7 完成 (8/9 case 覆盖) |
| `board/body/main.c` | **0%** (0/96) | — | ⏳ body 主循环待覆盖 (B18-B20) |
| `board/body/can.h` | **0%** (0/92) | — | ⏳ body CAN 待覆盖 (B13-B17) |
| `board/body/dotstar.h` | **0%** (0/158) | — | ⏳ body DotStar LED 待覆盖 (B10-B12) |
| `board/body/bldc/BLDC_controller.c` | **0%** (0/1274) | — | ⏳ BLDC FOC 控制器待覆盖 (B8-B9) |
| `board/drivers/can_common.h` | **100%** (107/107) | 10/12 | CAN 通用操作 |
| `board/drivers/gpio.h` | **100%** (72/72) | 6/7 | ✅ Phase J: J1 PUSH_PULL + J10 detect_with_pull 全覆盖 |
| `board/sys/faults.h` | **100%** (20/20) | 2/2 | 故障设置 |
| `board/libc.h` | **83.9%** (52/62) | 3/5 | memcmp 全覆盖 ✅；delay + assert_fatal(false) 不可覆盖 |
| `board/drivers/fan.h` | **100%** (27/27) | 3/3 | 风扇 PWM + 冷却 |
| `board/can_comms.h` | **100%** (76/76) | 4/4 | ✅ Phase D.3 完成 (overflow buffer 分片) |
| `board/config.h` | **100%** (4/4) | — | ✅ Phase D.1 |
| `board/boards/unused_funcs.h` | **91.3%** (21/23) | — | unused_init_bootloader 空函数体未调用 |
| `board/drivers/clock_source.h` | **100%** (40/40) | 2/2 | ✅ N1 完成 |
| `board/utils.h` | **100%** (10/10) | 1/1 | 工具函数 |
| `board/sys/power_saving.h` | **97.4%** (90/92) | — | ✅ B1 + J14 + J12c |
| `board/drivers/bootkick.h` | **97.9%** (47/48) | — | ✅ B2 |
| `board/drivers/can_health_pkt.h` | **100%** (37/37) | — | ✅ B4 + J11 DLEC (共享文件) |
| `board/drivers/harness.h` | **100%** (70/70) | — | ✅ Phase J: J2 harness_init 全覆盖 |
| `board/drivers/pwm.h` | **100%** (45/45) | 2/2 | ✅ J12b: pwm_init ch3, 全覆盖 |
| `board/drivers/led.h` | **96.0%** (24/25) | 2/2 | ✅ 去桩化 (仅 LED_RED define 未覆盖) |
| `board/stm32h7/llfdcan.h` | **85.1%** (137/161) | — | ✅ Phase J: J7 低速 + J9 5M (timeout 路径不可覆盖) |
| `board/drivers/fdcan.h` | **100%** (158/158) | — | ✅ Phase J: J3 checksum error + J4 all FDCAN handlers 全覆盖 |
| `board/boards/cuatro.h` | **98.5%** (65/66) | — | ✅ N2 完成，ADC 电压/电流通过 stub 覆盖 |
| `board/boards/tres.h` | **92.4%** (85/92) | — | ✅ N2 完成 |
| `board/boards/red.h` | **90.0%** (63/70) | — | ✅ N2 完成 |
| `board/drivers/spi.h` | **99.4%** (155/156) | — | ✅ Phase F.5 + J13 (spi_init) |
| `board/drivers/timers.h` | **100%** (27/27) | 4/4 | ✅ Phase H |
| `board/drivers/interrupts.h` | **100%** (53/53) | 4/4 | ✅ Phase J: J6 rate print 全覆盖 |
| `board/drivers/uart.h` | **100%** (77/77) | — | ✅ Phase J: J5 injectc overwrite 全覆盖 |
| `board/stm32h7/llfdcan_declarations.h` | **95.7%** (22/23) | — | CAN_NAME_FROM_CANIF FDCAN3 分支不可覆盖 |
| **合计 (panda)** | **92.7%** (2340/2525, 40 files) | — | panda 固件 (cuatro+tres+red) |
| **合计 (body)**  | **3.3%** (58/1762, 9 files)  | — | body 固件 (B1-B7 完成) |
| **合计 (全)**    | **55.9%** (2398/4287, 49 files) | — | 全板合并 |

## 设计原则

测试优先验证**寄存器级别**的行为（firmware 写入外设的实际位模式），而非中间函数的调用次数或传入参数。
寄存器验证已覆盖函数行为时，不再重复验证调用计数。例如：

* `deep_sleep.feature`：`stopModeRegs.gpio*Moder` 寄存器直接证明 `enter_stop_mode()` 正确配置了 GPIO，无需 `enterStopModeCallCount`
* `can_mode.feature`：`stopModeRegs.gpioBModer/gpioBOdr` 寄存器直接证明 `set_can_mode()` 切换了 CAN 引脚
* `safety_mode.feature`：`fdcanRegs[N].cccr` 寄存器直接证明 `can_init_all()` 初始化了 CAN 硬件
* `relay.feature`：`stopModeRegs.gpioAOdr` 寄存器直接证明 `set_intercept_relay()` 设置了 GPIO

**所有功能均已通过寄存器级别验证覆盖**，无需函数调用计数或参数追踪。

> B1/B2/N2/B5/G 完成后，`enable_can_transceivers` / `bootkick_tick` / `xxx_init()` / `set_intercept_relay` / `harness_check_ignition` / `harness_tick` / `harness_init` / `harness_detect_orientation` / `pwm_init` / `pwm_set` / `led_init` / `led_set` 使用纯生产代码。
> 冗余跟踪变量（`canTransceivers*`, `irPowerCallCount`, `last_siren_state`）已移除，
> 改为 `stopModeRegs` / `boardInit` 和 TIM1.CCR1 寄存器直接验证。
> B4: `update_can_health_pkt()` 提取为共享文件 `can_health_pkt.h`。

## C 代码编译

Panda 固件：
```bash
BOARD=cuatro cc -std=gnu11 -fPIC -shared -O0 -g \
  -I src/test/c \
  -I . -I board/ -I .venv/.../opendbc \
  -D main=panda_main \
  -D ALLOW_DEBUG \
  -D E2E_BOARD_CUATRO \
  -o libpanda_cuatro.dylib src/test/c/libpanda.c
```

Body 固件：
```bash
cc -std=gnu11 -fPIC -shared -O0 -g \
  -I src/test/c \
  -I . -I board/ -I board/body/ -I .venv/.../opendbc \
  -D PANDA_BODY -D ALLOW_DEBUG \
  -D HEALTH_PACKET_VERSION=0x...U -D CAN_PACKET_VERSION_HASH=0x...U \
  -o libpanda_body.dylib src/test/c/libpanda_body.c
```

`-I src/test/c` 中的 stub 头文件提供板级适配。panda 使用 `board/stm32h7/board.h`（引入真实 `board/boards/*.h` 生产代码），body 使用 `board/body/bldc/bldc.h`（BLDC Simulink 桩）和 `stm32h7xx.h`（CMSIS 最小桩）。

## 运行命令

```bash
cd e2e-tests

# 默认 (cuatro)
./gradlew cucumber

# 指定板卡
./gradlew cucumber -Pboard=tres
./gradlew cucumber -Pboard=body

# 覆盖率 (单板)
COVERAGE=1 ./gradlew cucumberCoverage

# 全量测试 + 合并覆盖率 (所有 feature，所有板卡: cuatro + tres + red + body)
./run_all_coverage.sh

# 重建 C 库
cd src/test/c && ./build.sh cuatro
cd src/test/c && ./build.sh body
```
