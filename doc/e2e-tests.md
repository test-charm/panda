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
| `enter_stop_mode_e2e.gen.c` | `board/sys/power_saving.h` | `enter_stop_mode()` 逐字提取 |
| `board_stubs_e2e.gen.c` | `board/boards/cuatro/tres/red.h` | `set_bootkick`, `set_amp_enabled`, `enable_can_transceiver` |
| `power_save_e2e.gen.c` | `board/sys/power_saving.h` | `set_power_save_state()` |
| `fdcan_e2e.gen.c` | `board/drivers/fdcan.h` | FDCAN 初始化代码 |

覆盖率报告排除全部 `.gen.c` 文件。

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
| `jna_process_stop_mode()` | 主循环检查 `stop_mode_requested` → `enter_stop_mode()` |
| `jna_tick_siren()` | tick handler 读 `siren_enabled` → `current_board->set_siren()` |

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
│   │   ├── generate_*.py            # 自动生成脚本（5 个）
│   │   ├── *_e2e.gen.c              # 自动生成文件（6 个，不纳入版本管理）
│   │   └── board/drivers/           # 仅保留 harness.h 测试桩
│   ├── java/com/panda/e2e/
│   │   ├── PandaClient.java         # JNA 接口 + StopModeRegs DTO
│   │   ├── SafetyModeSteps.java     # BDD 步骤定义 + ControlSetup
│   │   ├── Factories.java           # ControlSetup → client 自动装配
│   │   └── spec/UsbControlRequests.java
│   └── resources/
│       ├── features/                # 26 个 feature 文件
│       └── test-design/             # 测试设计文档
```

## 被测功能覆盖

| 功能 | Feature | 场景 | 验证方式 |
|------|---------|------|---------|
| 安全模式 | `safety_mode.feature` | 8 | FDCAN CCCR, gpioAOdr |
| CAN 回环 | `can_loopback.feature` | 4 | FDCAN TEST/MON |
| 心跳 | `heartbeat.feature` | 6 | heartbeat_* 变量 |
| 健康数据包 | `health.feature` | 5 | healthPacket + 可设 voltage/current |
| CAN 模式 | `can_mode.feature` | 6 | stopModeRegs (gpioBModer/gpioBOdr/gpioBPupdr) |
| 继电器 | `relay.feature` | 6 | stopModeRegs.gpioAOdr (PA3/PA9) |
| 省电模式 | `power_save.feature` | 12 | powerSaveTracking + stopModeRegs (gpioBOdr/gpioDOdr/gpioGOdr) |
| 替代体验 | `alternative_experience.feature` | 5 | alternativeExperience |
| 警笛 | `siren.feature` | 3 | stopModeRegs.gpioBOdr (PB14) via jna_tick_siren |
| CAN 通信重置 | `can_comms_reset.feature` | 3 | canCommsBuffers + stopModeRegs.gpioAOdr |
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
| 定时器/风扇 | `timer_fan.feature` | 2 | respBuffer (little-endian) |
| 风扇功率 | `fan_power.feature` | 5 | fanPower |
| 系统复位 | `reset_st.feature` | 1 | nvicResetCount |
| 深度休眠 | `deep_sleep.feature` | 13 | stopModeRegs (25+ 假寄存器: GPIO/ADC/RCC/SYSCFG/EXTI/PWR/SCB/NVIC) |
| SOM GPIO | `som_gpio.feature` | 1 | respBuffer |
| CAN 健康 | `can_health.feature` | 6 | canHealth0 (PSR/ECR 提取) |

## 设计原则

测试优先验证**寄存器级别**的行为（firmware 写入外设的实际位模式），而非中间函数的调用次数或传入参数。
寄存器验证已覆盖函数行为时，不再重复验证调用计数。例如：

* `deep_sleep.feature`：`stopModeRegs.gpio*Moder` 寄存器直接证明 `enter_stop_mode()` 正确配置了 GPIO，无需 `enterStopModeCallCount`
* `can_mode.feature`：`stopModeRegs.gpioBModer/gpioBOdr` 寄存器直接证明 `set_can_mode()` 切换了 CAN 引脚
* `safety_mode.feature`：`fdcanRegs[N].cccr` 寄存器直接证明 `can_init_all()` 初始化了 CAN 硬件
* `relay.feature`：`stopModeRegs.gpioAOdr` 寄存器直接证明 `set_intercept_relay()` 设置了 GPIO

所有功能均已通过寄存器级别验证覆盖，无需函数调用计数或参数追踪。

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

`-I src/test/c` 中的 stub 头文件仅有 `harness.h`（结构体定义）。其他头文件（`gpio.h`, `led.h`, `pwm.h` 等）已删除，统一使用 `board/` 下的生产代码。

## 运行命令

```bash
cd e2e-tests

# 默认 (cuatro)
./gradlew cucumber

# 指定板卡
./gradlew cucumber -Pboard=tres

# 覆盖率
COVERAGE=1 ./gradlew cucumberCoverage

# 重建 C 库
cd src/test/c && ./build.sh cuatro
```
