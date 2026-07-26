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
```

构建输出 `libpanda_${board}.dylib`，编译宏 `-DE2E_BOARD_CUATRO/TRES/RED` 控制板级 GPIO 引脚选择。`@cuatro/@tres/@red` 标签过滤板特定场景。

## 自动生成代码

以下文件由 Python 脚本从生产代码提取，`build.sh` 在编译前自动生成：

| 生成文件 | 来源 | 内容 |
|---------|------|------|
| `fdcan_e2e.gen.c` | `board/stm32h7/llfdcan.h` | FDCAN 初始化代码 (B3: 硬件轮询，暂不去桩) |
| `harness_detect_e2e.gen.c` | `board/drivers/harness.h:52-88` | `harness_detect_orientation()` |

覆盖率报告排除全部 `.gen.c` 文件。

> B1 ✅: `power_saving.h` 去桩化。B2 ✅: `bootkick.h` 去桩化。B4 ✅: `can_health_pkt.h` 提取共享。

> 板级函数（`enable_can_transceiver`, `set_bootkick`, `set_amp_enabled`, `set_can_mode`）已不再从桩提取，改为通过 `board/stm32h7/board.h` 桩直接编译 `board/boards/{cuatro,tres,red}.h` 生产代码。详见 P2 任务。

## 假硬件寄存器

`libpanda.c` 中为 `enter_stop_mode()` 涉及的外设创建假寄存器实例：

| 外设 | 假实例 | 访问的生产代码 |
|------|--------|--------------|
| GPIO A-G | `e2e_GPIOA`..`e2e_GPIOG` | `board/drivers/gpio.h` (set_gpio_output, set_gpio_mode) |
| ADC1/2 | `e2e_ADC1`, `e2e_ADC2` | 寄存器直接操作 |
| RCC | `e2e_RCC` | 时钟控制 |
| SYSCFG | `e2e_SYSCFG` | EXTI 配置 |
| EXTI | `e2e_EXTI` | 中断/唤醒 |
| PWR | `e2e_PWR` | 电源模式 |
| NVIC | `e2e_NVIC` | 中断控制 |
| SCB | `e2e_SCB` | 系统控制 |
| TIM1 | `fake_TIM1` | IR PWM, 时钟源 |

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
| `jna_board_init()` | 重置 GPIO/PWR/TIM，预置 USB33RDY → `current_board->init()` (N2) |
| `jna_reset_*` 系列 (15+) | 每次 `@Before` 中重置所有假状态 |

## 目录结构

```
e2e-tests/
├── build.gradle
├── scripts/coverage-report.sh       # 覆盖率报告（支持多板）
├── src/test/
│   ├── c/
│   │   ├── build.sh                 # 编译（支持 BOARD 参数）
│   │   ├── fake_stm.h               # GPIO_TypeDef 完整结构体
│   │   ├── libpanda.c               # 假寄存器实例 + JNA 访问器
│   │   ├── generate_*.py            # 自动生成脚本（2 个）
│   │   ├── *_e2e.gen.c              # 自动生成文件（2 个，不纳入版本管理）
│   │   └── board/drivers/           # 仅保留 harness.h 测试桩
│   ├── java/com/panda/e2e/
│   │   ├── PandaClient.java         # JNA 接口 + StopModeRegs DTO
│   │   ├── SafetyModeSteps.java     # BDD 步骤定义 + ControlSetup
│   │   ├── Factories.java           # ControlSetup → client 自动装配 + hexToBytes
│   │   └── spec/
│   │       ├── UsbControlRequests.java  # 33 个 USB 控制请求 spec
│   │       └── ControlSetups.java       # 前置数据 spec
│   └── resources/
│       ├── features/                # 40 个 feature 文件
│       └── test-design/             # 测试设计文档
```

## 被测功能覆盖

| 功能 | Feature | 场景 | 验证方式 |
|------|---------|------|---------|
| 安全模式 | `safety_mode.feature` | 8 | FDCAN CCCR, gpioAOdr |
| CAN 回环 | `can_loopback.feature` | 4 | FDCAN TEST/MON |
| 心跳 | `heartbeat.feature` | 6 | heartbeat_* 变量 |
| 心跳丢失 | `heartbeat_loss.feature` | 9 | safetyState + powerSaveTracking 通过 jna_call_tick_handler |
| 健康数据包 | `health.feature` | 5 | healthPacket + 可设 voltage/current |
| CAN 模式 | `can_mode.feature` | 6 | stopModeRegs (gpioBModer/gpioBOdr/gpioBPupdr) |
| 继电器 | `relay.feature` | 6 | stopModeRegs.gpioAOdr (PA3/PA9) |
| 省电模式 | `power_save.feature` | 15 | powerSaveTracking + stopModeRegs (gpioBOdr/gpioDOdr/gpioGOdr) |
| 替代体验 | `alternative_experience.feature` | 5 | alternativeExperience |
| 警笛 | `siren.feature` | 3 | stopModeRegs.gpioBOdr (PB14) via jna_tick_siren |
| CAN 通信重置 | `can_comms_reset.feature` | 3 | canCommsBuffers + stopModeRegs.gpioAOdr |
| CAN 通信序列化 | `can_comms.feature` | 8 | comms_can_write → txQueue, comms_can_read → commsReadBytes, checksumCheckPassed |
| CAN 环形缓冲 | `can_ring_clear.feature` | 4 | rxQueue/txQueue |
| 固件版本 | `get_version.feature` | 1 | respBuffer |
| 数据包版本 | `packet_versions.feature` | 1 | packetVersions |
| IR 功率 | `ir_power.feature` | 3 | irPwm (TIM1 CCR1) |
| 硬件类型 | `hw_type.feature` | 1 | respBuffer |
| CAN 波特率 | `can_bitrate.feature` | 3 | FDCAN NBTP/CCCR/IE/TXBC/RXF0C |
| CAN FD 自动 | `can_fd_auto.feature` | 3 | canFdConfig |
| CAN FD Non-ISO | `can_fd_non_iso.feature` | 3 | FDCAN CCCR |
| CAN FD 数据率 | `can_fd_data_bitrate.feature` | 3 | FDCAN DBTP/CCCR/IE/TXBC/RXF0C |
| 时钟源 | `clock_source.feature` | 3 | clockSource (TIM1/TIM8 CCR) |
| 时钟源初始化 | `clock_source_init.feature` | 6 | clockSourceInit (TIM1×12, TIM8×8, GPIO×4, NVIC×2) |
| 板级初始化 | `board_init.feature` | 7 | boardInit (GPIO MODER/OTYPER/OSPEEDR/PUPDR/AFR/ODR ×45, PWR_CR3) — N2 完成 |
| 定时器/风扇 | `timer_fan.feature` | 2 | respBuffer (little-endian) |
| 风扇功率 | `fan_power.feature` | 5 | fanPower |
| 风扇冷却 | `fan_cooldown.feature` | 3 | fanCooldownCounter + fanPower 通过 jna_call_tick_handler |
| 系统复位 | `reset_st.feature` | 1 | nvicResetCount |
| 深度休眠 | `deep_sleep.feature` | 13 | stopModeRegs (25+ 假寄存器: GPIO/ADC/RCC/SYSCFG/EXTI/PWR/SCB/NVIC) |
| SOM GPIO | `som_gpio.feature` | 1 | respBuffer |
| CAN 健康 | `can_health.feature` | 6 | canHealth0 (PSR/ECR 提取) |
| 微秒定时器 | `microsecond_timer.feature` | 2 | respBuffer (4-byte LE) |
| MCU UID | `mcu_uid.feature` | 2 | respBuffer (12 bytes) |
| 中断调用率 | `interrupt_rate.feature` | 3 | respBuffer (4-byte LE / 空) |
| 序列号/Provision | `serial.feature` | 2 | respBuffer (16/32 bytes) |
| 固件签名 | `signature.feature` | 2 | respBuffer (64 bytes 分块) |
| Bootloader 模式 | `bootloader.feature` | 3 | nvicResetCount, enterBootloaderMode |
| UART 读取 | `uart_read.feature` | 3 | respBuffer (字符读取 / 空) |
| Bootkick SOM 复位 | `bootkick.feature` | 14 | tick_handler FSM (state/waitingCountdown/resetCountdown/resetTriggered) + stopModeRegs (gpioAOdr/gpioCOdr) 通过 jna_call_tick_handler |
| 继电器故障 | `relay_malfunction.feature` | 3 | readFaults (FAULT_RELAY_MALFUNCTION 边沿检测) |
| 看门狗 | `watchdog.feature` | 3 | readFaults (FAULT_HEARTBEAT_LOOP_WATCHDOG, 直接 include 生产代码 `simple_watchdog.h`) |
| 寄存器发散 | `register_divergence.feature` | 3 | readFaults (FAULT_REGISTER_DIVERGENT, 真实 `registers.h` + `jna_set_register_divergent` 注入) |
| WFI 空闲路径 | `wfi_idle.feature` | 3 | stopModeRegs (wfiEntered + scbScr, 通过 `jna_process_wfi_idle`) |
| ignition_can 自动复位 | `ignition_can.feature` | 2 | ignitionCan (通过 `jna_set_ignition_can` + `jna_call_tick_handler`) |
| 线束翻转检测 | `harness_detect.feature` | 8 | harnessStatus (生产 `harness_detect_orientation()` + ADC 拦截桩) |
| Tick 路径 | `tick_paths.feature` | 6 | has_fan=false, heartbeat_counter 溢出, safety_mode_cnt 溢出, harness reinit (P1) |

## C 代码覆盖率

> 数据来源: `e2e-tests/run_all_coverage.sh` 合并报告 (cuatro + tres + red)
> 生成时间: 2026-07-26 (B1/B2/B4 去桩化 + N1/N2 完成)

| 源文件 | 行覆盖 | 函数覆盖 | 说明 |
|--------|--------|---------|------|
| `board/main_comms.h` | **97.0%** (261/269) | 3/3 | USB 命令处理 |
| `board/main.c` | **64.2%** (145/226) | 4/7 | 主循环 + 初始化 |
| `board/drivers/can_common.h` | **95.3%** (102/107) | 10/12 | CAN 通用操作 |
| `board/drivers/gpio.h` | **70.4%** (50/71) | 5/7 | GPIO 控制 |
| `board/sys/faults.h` | **78.9%** (15/19) | 2/2 | 故障设置 |
| `board/libc.h` | **61.3%** (38/62) | 3/5 | 最小化 libc 替代 |
| `board/drivers/fan.h` | **100%** (27/27) | 3/3 | 风扇 PWM + 冷却 |
| `board/can_comms.h` | **100%** (76/76) | 4/4 | CAN 通信序列化 |
| `board/drivers/clock_source.h` | **95.0%** (38/40) | 2/2 | ✅ N1 完成 (`clock_source_init` 全覆盖) |
| `board/utils.h` | **100%** (10/10) | 1/1 | 工具函数 |
| `board/sys/power_saving.h` | **95.8%** (92/96) | — | ✅ B1 |
| `board/drivers/bootkick.h` | **~98%** (预估) | — | ✅ B2 |
| `board/drivers/can_health_pkt.h` | **~95%** (预估) | — | ✅ B4 (共享文件) |
| `board/boards/*.h` | **95.0%** (57/60) | — | ✅ N2 完成 + 去桩化 (board_init.feature 7 场景) |
| **合计** | **~87.5%** (~1570/1789 lines, 29 files) | — | B1/B2/B4 去桩化 + N1/N2 完成 |

> ⚠️ `main.c` 中未覆盖的函数：`sound_tick`。P1-P8 已全部覆盖。详见 `e2e-tests/src/test/resources/test-design/uncovered-features.md`。

## 设计原则

测试优先验证**寄存器级别**的行为（firmware 写入外设的实际位模式），而非中间函数的调用次数或传入参数。
寄存器验证已覆盖函数行为时，不再重复验证调用计数。例如：

* `deep_sleep.feature`：`stopModeRegs.gpio*Moder` 寄存器直接证明 `enter_stop_mode()` 正确配置了 GPIO，无需 `enterStopModeCallCount`
* `can_mode.feature`：`stopModeRegs.gpioBModer/gpioBOdr` 寄存器直接证明 `set_can_mode()` 切换了 CAN 引脚
* `safety_mode.feature`：`fdcanRegs[N].cccr` 寄存器直接证明 `can_init_all()` 初始化了 CAN 硬件
* `relay.feature`：`stopModeRegs.gpioAOdr` 寄存器直接证明 `set_intercept_relay()` 设置了 GPIO

**所有功能均已通过寄存器级别验证覆盖**，无需函数调用计数或参数追踪。

> B1/B2/N2 完成后，`enable_can_transceivers` / `bootkick_tick` / `xxx_init()` 使用纯生产代码。
> 冗余跟踪变量（`canTransceivers*`, `irPowerCallCount`, `last_siren_state`）已移除，
> 改为 `stopModeRegs` / `boardInit` 和 TIM1.CCR1 寄存器直接验证。
> B4: `update_can_health_pkt()` 提取为共享文件 `can_health_pkt.h`。

## C 代码编译

```bash
BOARD=cuatro cc -std=gnu11 -fPIC -shared -O0 -g \
  -I src/test/c \
  -I . -I board/ -I .venv/.../opendbc \
  -D main=panda_main \
  -D ALLOW_DEBUG \
  -D E2E_BOARD_CUATRO \
  -o libpanda_cuatro.dylib src/test/c/libpanda.c
```

`-I src/test/c` 中的 stub 头文件提供板级适配（`board/stm32h7/board.h` — 引入真实 `board/boards/*.h` 生产代码，并包含 `common_init_gpio()` / `gpio_uart7_init()` 的真实实现复制自 `peripherals.h`）以及 `harness.h`（结构体定义）、`lladc.h`（ADC 拦截桩）。其他头文件（`gpio.h`, `led.h`, `pwm.h` 等）统一使用 `board/` 下的生产代码。

## 运行命令

```bash
cd e2e-tests

# 默认 (cuatro)
./gradlew cucumber

# 指定板卡
./gradlew cucumber -Pboard=tres

# 覆盖率 (单板)
COVERAGE=1 ./gradlew cucumberCoverage

# 全量测试 + 合并覆盖率 (所有 feature，所有板卡)
./run_all_coverage.sh

# 重建 C 库
cd src/test/c && ./build.sh cuatro
```
