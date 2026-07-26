# 端到端测试未覆盖功能清单

> 最后更新: 2026-07-26
> 基准 e2e 场景数: 172（包含 P0 `can_comms.feature` +8 场景、P1 `tick_paths.feature` +6 场景）
> 综合行覆盖率: **79.6%** (720/905 lines), 函数覆盖率: **76.1%** (35/46 functions)
> 数据来源: `e2e-tests/run_all_coverage.sh` (cuatro + tres + red 合并)

---

## 零、e2e 编译模型：哪些文件进入了覆盖率报告

e2e 通过 `libpanda.c` 编译完整 `board/main.c`，利用 `-I` 优先级覆盖机制：
- `-I e2e-tests/src/test/c` (最高优先级 → e2e 桩)
- `-I /path/to/panda` (项目根)
- `-I /path/to/panda/board` (board 目录)

文件被编译为真实生产代码 vs 被桩替换 vs 被切断，取决于 include 路径中的文件是否被 e2e 桩覆盖。

### 进入覆盖率的 19 个真实 `board/` 文件

这些文件被完整编译为生产代码，覆盖率数据有效：

```
board/main.c                          — 主固件逻辑
board/main_comms.h                    — USB 命令处理 (comms_control_handler)
board/can_comms.h                     — CAN 报文编解码 (comms_can_read/write)
board/config.h                        — 构建配置
board/comms_definitions.h             — ControlPacket_t 类型
board/health.h                        — health_t 结构体
board/can.h                           — CAN 常量定义
board/sys/sys.h                       — 临界区宏、故障常量
board/sys/faults.h                    — 故障处理函数
board/drivers/drivers.h               — 中央驱动声明 (所有驱动类型/函数原型)
board/drivers/registers.h             — 寄存器影子校验
board/drivers/can_common.h            — CAN 队列、can_send、can_init_all
board/drivers/fan.h                   — 风扇控制 (fan_set_power, fan_tick)
board/drivers/gpio.h                  — GPIO 控制
board/drivers/clock_source.h          — 时钟源定时器
board/drivers/simple_watchdog.h       — 看门狗 (桩委托到真实代码)
board/libc.h                          — memcpy, memset, delay
board/stm32h7/lladc_declarations.h    — ADC 信号类型声明
board/boards/board_declarations.h     — board 结构体、HW_TYPE_* 常量
```

### 未进入覆盖率的文件：四大原因

```
┌─ board/ 全部 C/H 文件 (~90 个)
│
├── ✅ 已编译为真实代码 (19 个) → 上面列出
│
├── ⚠️ 被 e2e 桩替换 (19 个) → 第一节
│   └── 生产代码未经编译，覆盖率 0%
│
├── ❌ 被 stm32h7_config.h 桩切断 (16 个) → 第二节
│   └── 通过真实 stm32h7_config.h 的 include 链被切断
│
├── 🚫 其他固件目标 (25 个) → 第三节
│   └── jungle / body / bootstub / crypto (仅 bootstub 使用)
│
└── 📦 CMSIS/HAL 头 + 工具脚本 → 第四节
    └── 第三方 STM32 头文件、Python 工具、测试辅助
```

---

## 覆盖率总览 (仅编译为真实代码的文件)

| 源文件 | 行覆盖 | 函数覆盖 | 未覆盖原因 |
|--------|--------|---------|-----------|
| `board/main_comms.h` | 100% | 3/3 | 全部覆盖（`endpoint2_write.feature` 覆盖了 `comms_endpoint2_write`） |
| `board/main.c` | 46.9% | 4/7 | 主循环 tick 路径 (P1 ✅ 已完成: has_fan=false, heartbeat_counter 溢出, safety_mode_cnt 溢出, harness reinit) |
| `board/drivers/can_common.h` | 86.8% | 10/12 | can_clear_rx 未遍历路径, can_set_speed 未遍历比特率 |
| `board/drivers/gpio.h` | 72.1% | 5/7 | set_gpio_analog, restore_gpio 仅 deep_sleep 覆盖 |
| `board/sys/faults.h` | 78.9% | 2/2 | `fault_occurred` Temporary fault 路径已由 watchdog 覆盖 |
| `board/libc.h` | 60.7% | 3/5 | memset/memcpy 大量路径 |
| `board/drivers/fan.h` | 37.0% | 2/3 | fan cooldown 逻辑 (P8 ✅) + has_fan=false 路径 (P1 ✅) |
| `board/can_comms.h` | 18.4% | 2/4 | CAN 接收/发送内层路径 |
| `board/drivers/clock_source.h` | 18.4% | 1/2 | TIM8 外部时钟模式未覆盖 |
| `board/drivers/registers.h` | — | — | 头文件 (声明) |
| `board/boards/board_declarations.h` | — | — | 头文件 (宏/声明) |
| `board/sys/sys.h` | — | — | 头文件 (声明) |

---

## 一、被 e2e 桩替换的文件 (19 个)

这些 `board/` 下的生产代码文件在 e2e 构建中被同路径的桩文件替换，**真实代码从未编译**，因此覆盖率报告中不存在。

### 桩替换机制

`build.sh` 的 include 路径优先级：`-I e2e-tests/src/test/c` > `-I board/`。当 `e2e-tests/src/test/c/board/xxx.h` 存在时，编译器使用桩文件而非真实 `board/xxx.h`。

### 替换清单

| 真实文件 | e2e 桩 | 替换原因 | 核心功能 |
|----------|--------|---------|---------|
| `board/provision.h` | 空桩 (返回假数据) | 无真实 OTP 存储 | 设备序列号/Provision 读取 |
| `board/sys/power_saving.h` | `power_save_e2e.gen.c` (手写副本) | STM32 STOP 模式不可用 | `enter_stop_mode()`, `set_power_save_state()` |
| `board/early_init.h` | 空桩 | STM32 早期初始化无意义 | `early_initialization()` |
| `board/crc.h` | 空桩 | CRC 硬件不可用 | CRC 校验 (`crc_calc`, `crc_check`) |
| `board/drivers/bootkick.h` | `bootkick_e2e.gen.c` (生成代码) | 无真实 GPIO | SOM 启动/复位状态机 |
| `board/drivers/fdcan.h` | `fdcan_e2e.gen.c` (从真实源码生成) | 无 FDCAN 外设 | `can_init()`, `can_send()`, `can_rx()` 等 FDCAN 核心函数 |
| `board/drivers/usb.h` | 空桩 | 无真实 USB OTG | `usb_init()`, `usb_irqhandler()` |
| `board/drivers/spi.h` | 空桩 | 无真实 SPI | `spi_init()`, SPI DMA 传输 |
| `board/drivers/fake_siren.h` | 空桩 | 无真实蜂鸣器 GPIO | 蜂鸣器控制 |
| `board/drivers/harness.h` | `harness_detect_e2e.gen.c` (部分提取) | 无真实 SBU ADC | `harness_detect_orientation()` 提取，其他为空 |
| `board/drivers/led.h` | 空桩 | 无真实 LED PWM | `led_init()`, `led_set()` |
| `board/drivers/uart.h` | 桩 (基础实现) | 无真实 UART | `put_char()`, `get_char()` 等 |
| `board/drivers/pwm.h` | 空桩 | 无真实 PWM 定时器 | `pwm_init()`, `pwm_set()` |
| `board/drivers/interrupts.h` | 空桩 | 无真实 NVIC | `init_interrupts()`, `handle_interrupt()` |
| `board/drivers/timers.h` | 空桩 | 无真实 TIM 外设 | `tick_timer_init()`, `microsecond_timer_init()` |
| `board/stm32h7/lladc.h` | 桩 (拦截 `adc_get_mV()`) | 无真实 ADC | ADC 读取 (`adc_get_mV`, `adc_get_raw`) |
| `board/stm32h7/stm32h7_config.h` | 最小化桩 | STM32H7 HAL 头不兼容宿主编译 | **关键枢纽** — 切断其下所有 include 链 |
| `board/stm32h7/sound.h` | 空桩 | 无真实音频 DAC | `sound_init()`, `sound_tick()` |
| `board/obj/gitversion.h` | 桩 (返回假版本) | 非 git 构建环境 | 固件版本号 |

> **关于 `board/drivers/fdcan.h`**：虽然被桩替换，但 `fdcan_e2e.gen.c` 由 `generate_fdcan_stubs.py` 从真实 `board/stm32h7/llfdcan.h` 源码逐字提取生成。**FDCAN 核心函数 (`can_init`, `can_send`, `can_rx` 等) 是以生成代码形式出现在覆盖率中的**，只是声明被桩替换。

### 影响评估

| 优先级 | 文件 | 理由 |
|--------|------|------|
| 🔴 高 | `drivers/fdcan.h` | FDCAN 核心驱动 (500+ 行)，已通过 gen 脚本部分覆盖 |
| 🔴 高 | `drivers/bootkick.h` | SOM 启动状态机 (5 态 FSM)，已通过 gen 脚本部分覆盖 |
| 🟡 中 | `sys/power_saving.h` | STOP 模式进入逻辑，已通过手写副本覆盖 |
| 🟡 中 | `drivers/harness.h` | SBU 检测逻辑，已通过 gen 脚本提取 |
| 🟢 低 | `drivers/gpio.h`, `drivers/pwm.h`, `drivers/led.h` | 纯 GPIO 操作，无业务逻辑 |
| 🟢 低 | `drivers/usb.h`, `drivers/spi.h` | 纯外设初始化，无业务逻辑 |
| 🟢 低 | 其他 | 辅助/声明文件 |

---

## 二、被 `stm32h7_config.h` 桩切断的文件 (16 个)

真实 `board/stm32h7/stm32h7_config.h` 是固件的**中央配置枢纽**，它 include 了约 20 个其他 board 文件：
```
stm32h7_config.h (真实)
├── stm32h7xx.h (CMSIS)
├── board/can.h
├── board/comms_definitions.h
├── board/main_definitions.h ──→ main_declarations.h ──→ drivers/drivers.h
├── board/libc.h
├── board/sys/critical.h          ← 切断
├── board/sys/faults.h
├── board/utils.h                 ← 切断
├── board/drivers/registers.h
├── board/drivers/interrupts.h    (随 stm32h7_config 一起被桩替换)
├── board/drivers/gpio.h
├── board/stm32h7/peripherals.h   ← 切断
├── board/stm32h7/interrupt_handlers.h ← 切断
├── board/drivers/timers.h        (随 stm32h7_config 一起被桩替换)
├── board/drivers/uart.h          (随 stm32h7_config 一起被桩替换)
├── board/stm32h7/lluart.h        ← 切断
├── board/stm32h7/board.h ──────── 切断 ←
│   ├── boards/board_declarations.h
│   ├── boards/unused_funcs.h     ← 切断
│   ├── stm32h7/lladc.h           (已被桩替换)
│   ├── drivers/harness.h         (已被桩替换)
│   ├── drivers/fan.h
│   ├── stm32h7/llfan.h           ← 切断
│   ├── stm32h7/sound.h           (已被桩替换)
│   ├── drivers/fake_siren.h      (已被桩替换)
│   ├── drivers/clock_source.h
│   ├── boards/red.h              ← 切断
│   ├── boards/tres.h             ← 切断
│   └── boards/cuatro.h           ← 切断
├── board/stm32h7/clock.h         ← 切断
├── board/stm32h7/llfdcan.h       ← 切断
│   └── stm32h7/llfdcan_declarations.h ← 切断
├── board/stm32h7/llusb.h         ← 切断
│   └── stm32h7/llusb_declarations.h ← 切断
├── board/drivers/spi.h           (已被桩替换)
└── board/stm32h7/llspi.h         ← 切断
```

e2e 用最小化桩替换 `stm32h7_config.h`，仅重新引入被切断的**必要文件**（`comms_definitions.h`、`sys/sys.h`、`drivers/registers.h`）。

### 被切断且未被重新引入的文件

| 文件 | 行数(估) | 核心功能 | 影响 |
|------|---------|---------|------|
| `board/utils.h` | ~45 | `MIN/MAX/CLAMP/ABS` 宏, `get_ts_elapsed()` | 工具宏，易补偿 |
| `board/sys/critical.h` | ~15 | `enable_interrupts()`, `disable_interrupts()` | 仅用于真实 NVIC |
| `board/stm32h7/board.h` | ~50 | `detect_board_type()` 硬件检测 | 硬件 ID 引脚检测，e2e 硬编码板型 |
| `board/stm32h7/peripherals.h` | ~135 | `peripherals_init()` — 所有外设时钟使能 | 纯寄存器操作 |
| `board/stm32h7/clock.h` | ~30 | 系统时钟配置 (HSE/PLL) | 纯寄存器操作 |
| `board/stm32h7/interrupt_handlers.h` | ~50 | 中断向量表实现 | 纯外设中断 |
| `board/stm32h7/lluart.h` | ~60 | UART 低层驱动 | 被 `drivers/uart.h` 桩屏蔽 |
| `board/stm32h7/llspi.h` | ~40 | SPI 低层驱动 | 被 `drivers/spi.h` 桩屏蔽 |
| `board/stm32h7/llfdcan.h` | ~500 | **FDCAN 寄存器级驱动** | 🔴 核心代码，已通过 `fdcan_e2e.gen.c` 部分提取 |
| `board/stm32h7/llusb.h` | ~100 | USB OTG 低层驱动 | 被 `drivers/usb.h` 桩屏蔽 |
| `board/stm32h7/llfan.h` | ~20 | 风扇 tach 输入捕获 | 被 `drivers/fan.h` 分离 |
| `board/stm32h7/llfdcan_declarations.h` | ~30 | FDCAN 寄存器声明 | 头文件 |
| `board/stm32h7/llusb_declarations.h` | ~30 | USB 寄存器声明 | 头文件 |
| `board/boards/cuatro.h` | ~80 | Cuatro 板级实现 (GPIO 映射) | 🔴 板级关键代码 |
| `board/boards/red.h` | ~60 | Red panda 板级实现 | 🔴 板级关键代码 |
| `board/boards/tres.h` | ~70 | Tres 板级实现 | 🔴 板级关键代码 |
| `board/boards/unused_funcs.h` | ~30 | 板级空函数 (未使用功能的默认实现) | 🟢 空桩 |

### 影响评估

| 优先级 | 文件 | 理由 |
|--------|------|------|
| 🔴 高 | `stm32h7/llfdcan.h` | FDCAN 核心驱动 (~500 行)，CAN 通信的底层实现。已通过 gen 脚本部分提取 |
| 🔴 高 | `boards/cuatro.h`, `red.h`, `tres.h` | 硬件板级实现，包含 GPIO 映射、电压/电流读取等关键逻辑 |
| 🟡 中 | `stm32h7/board.h` | 硬件类型检测 (`detect_board_type`) |
| 🟡 中 | `stm32h7/peripherals.h` | 外设时钟初始化 (RCC)，硬件初始化关键步骤 |
| 🟢 低 | 其他 | 纯 HAL 寄存器操作或声明文件 |

---

## 三、其他固件目标 (25 个文件)

panda 代码库从同一 `board/` 目录构建**三个独立固件**，e2e 当前仅覆盖 panda 主固件 (`board/main.c`)：

```
board/main.c          → panda 固件    ✅ e2e 覆盖
board/jungle/main.c   → jungle 固件   ❌ 无 e2e
board/body/main.c     → body 固件     ❌ 无 e2e
board/bootstub.c      → bootstub      ❌ 无 e2e
```

### Bootstub (3 个文件)

| 文件 | 功能 |
|------|------|
| `board/bootstub.c` | 最小引导程序，负责固件刷写 |
| `board/bootstub_declarations.h` | Bootstub 全局声明 |
| `board/flasher.h` | 刷写协议命令处理 (3 个未覆盖命令: 0xb0 echo, 0xb1 unlock, 0xb2 erase) |

### Jungle 固件 (6 个文件)

| 文件 | 功能 |
|------|------|
| `board/jungle/main.c` | Jungle 测试夹具主固件 |
| `board/jungle/main_comms.h` | 8 个 Jungle USB 命令 (panda 电源控制、点火信号等) |
| `board/jungle/jungle_health.h` | Jungle 健康数据包结构 |
| `board/jungle/boards/board_declarations.h` | Jungle 板级声明 |
| `board/jungle/boards/board_v2.h` | Jungle V2 板级实现 |
| `board/jungle/stm32h7/board.h` | Jungle 硬件检测 |

### Body 固件 (12 个文件)

| 文件 | 功能 |
|------|------|
| `board/body/main.c` | Body 控制器主固件 |
| `board/body/main_comms.h` | 2 个 Body USB 命令 (电机启停/转速) |
| `board/body/can.h` | Body CAN 定义 |
| `board/body/dotstar.h` | DotStar LED 控制 |
| `board/body/boards/board_declarations.h` | Body 板级声明 |
| `board/body/boards/board_body.h` | Body 板级实现 |
| `board/body/stm32h7/board.h` | Body 硬件检测 |
| `board/body/bldc/bldc.h` | BLDC 电机控制接口 |
| `board/body/bldc/bldc_defs.h` | BLDC 类型定义 |
| `board/body/bldc/BLDC_controller.h` | BLDC 控制器 (Simulink 生成) |
| `board/body/bldc/BLDC_controller.c` | BLDC 控制器实现 |
| `board/body/bldc/BLDC_controller_data.c` | BLDC 控制器数据 |
| `board/body/bldc/rtwtypes.h` | Simulink RTW 类型 |

### Crypto (4 个文件，仅 bootstub 使用)

| 文件 | 功能 | 使用方 |
|------|------|--------|
| `board/crypto/sha.h` / `sha.c` | SHA-256 实现 | bootstub (固件签名验证) |
| `board/crypto/rsa.h` / `rsa.c` | RSA-1024 实现 | bootstub (固件签名验证) |
| `board/crypto/hash-internal.h` | 哈希内部声明 | sha.c |

---

## 四、CMSIS/HAL 头文件与工具脚本 (不计入覆盖率)

以下文件属于第三方代码或非 C 代码，不应计入覆盖率统计：

### CMSIS/HAL 头文件 (12 个)
`board/stm32h7/inc/` 下的 STM32 官方 CMSIS 头文件，非 panda 自有代码：
`core_cm7.h`, `cmsis_gcc.h`, `cmsis_compiler.h`, `cmsis_version.h`, `mpu_armv7.h`, `system_stm32h7xx.h`, `stm32h725xx.h`, `stm32h735xx.h`, `stm32h7xx.h`, `stm32h7xx_hal_def.h`, `stm32h7xx_hal_gpio_ex.h`

### 其他非 C 文件
| 文件 | 类型 | 说明 |
|------|------|------|
| `board/fake_stm.h` | 测试辅助 | 宿主测试用 STM32 桩，非生产固件代码 |
| `board/flash.py` | Python | panda 刷写工具 |
| `board/recover.py` | Python | DFU 恢复工具 |
| `board/__init__.py` | Python | Python 包 |
| `board/README.md` | 文档 | — |

### 未被任何 include 链引用的文件
| 文件 | 说明 |
|------|------|
| `board/stm32h7/llflash.h` | Flash 驱动，仅 `BOOTSTUB` 条件下编译 |
| `board/stm32h7/lli2c.h` | I2C 驱动，仅 audio codec 使用，主路径未引用 |

---

## 五、USB 命令覆盖状态

### `board/main_comms.h` — panda 固件 (33/34 已覆盖)

| 命令 | 功能 | 覆盖状态 |
|------|------|----------|
| 0xa8 | 微秒定时器 | ✅ `microsecond_timer.feature` |
| 0xb0 | IR 功率 | ✅ `ir_power.feature` |
| 0xb1 | 风扇功率 | ✅ `fan_power.feature` |
| 0xb2 | 风扇转速 | ✅ `timer_fan.feature` |
| 0xb5 | 深度休眠 (`ALLOW_DEBUG`) | ✅ `deep_sleep.feature` |
| 0xc0 | 通信重置 | ✅ `can_comms_reset.feature` |
| 0xc1 | 硬件类型 | ✅ `hw_type.feature` |
| 0xc2 | CAN 健康统计 | ✅ `can_health.feature` |
| 0xc3 | MCU UID | ✅ `mcu_uid.feature` |
| 0xc4 | 中断调用率 | ✅ `interrupt_rate.feature` |
| 0xc5 | 继电器驱动 | ✅ `relay.feature` |
| 0xc6 | SOM GPIO 读取 | ✅ `som_gpio.feature` |
| 0xd0 | 序列号/Provision | ✅ `serial.feature` |
| 0xd1 | Bootloader 模式 | ✅ `bootloader.feature` |
| 0xd2 | 健康数据包 | ✅ `health.feature` |
| 0xd3 | 签名第一块 (64B) | ✅ `signature.feature` |
| 0xd4 | 签名第二块 (64B) | ✅ `signature.feature` |
| 0xd6 | 固件版本 | ✅ `get_version.feature` |
| 0xd8 | 系统复位 | ✅ `reset_st.feature` |
| 0xdb | CAN 复用模式 | ✅ `can_mode.feature` |
| 0xdc | 安全模式 | ✅ `safety_mode.feature` |
| 0xdd | 数据包版本 | ✅ `packet_versions.feature` |
| 0xde | CAN 波特率 | ✅ `can_bitrate.feature` |
| 0xdf | 替代体验 | ✅ `alternative_experience.feature` |
| 0xe0 | UART 读取 | ✅ `uart_read.feature` |
| 0xe5 | CAN 回环 | ✅ `can_loopback.feature` |
| 0xe6 | 时钟源 | ✅ `clock_source.feature` |
| 0xe7 | 省电模式 | ✅ `power_save.feature` |
| 0xe8 | CAN FD 自动 | ✅ `can_fd_auto.feature` |
| 0xf1 | CAN 环形缓冲清除 | ✅ `can_ring_clear.feature` |
| 0xf3 | 心跳 | ✅ `heartbeat.feature` |
| 0xf6 | 警笛 | ✅ `siren.feature` |
| **0xf8** | **禁用心跳检查** | ✅ `heartbeat.feature:63-79,106-126` |
| 0xf9 | CAN FD 数据率 | ✅ `can_fd_data_bitrate.feature` |
| 0xfc | CAN FD Non-ISO | ✅ `can_fd_non_iso.feature` |

### `board/flasher.h` — Bootstub 刷写命令 (3/9 未覆盖)

| 命令 | 功能 | 覆盖状态 | 说明 |
|------|------|----------|------|
| 0xb0 | Flasher echo | ❌ | 刷写协议握手 |
| 0xb1 | 解锁 Flash | ❌ | 设置 prog_ptr，绿灯 |
| 0xb2 | 擦除扇区 | ❌ | param1 指定扇区 |
| 0xc1 | 硬件类型 | ✅ | 与 main_comms 共享 |
| 0xc3 | MCU UID | ✅ | 与 main_comms 共享 |
| 0xd0 | 序列号 | ✅ | 与 main_comms 共享 |
| 0xd1 | Bootloader 模式 | ✅ | 与 main_comms 共享 |
| 0xd6 | 固件版本 | ✅ | 与 main_comms 共享 |
| 0xd8 | 系统复位 | ✅ | 与 main_comms 共享 |

> ⚠️ e2e 当前只编译 `board/main.c`，不覆盖 bootstub 固件 (`bootstub.c`)。

### `board/jungle/main_comms.h` — Jungle 固件 (0/8 已覆盖)

| 命令 | 功能 | 覆盖状态 |
|------|------|----------|
| 0xa0 | 设置 panda 电源 | ❌ |
| 0xa1 | 设置 harness 方向 | ❌ |
| 0xa2 | 设置点火信号 | ❌ |
| 0xa3 | 按通道设置 panda 电源 | ❌ |
| 0xa4 | 启停生成 CAN 流量 | ❌ |
| 0xf4 | CAN 收发器使能 | ❌ |
| 0xf5 | CAN 静默模式 | ❌ |
| 0xf7 | Header 引脚控制 | ❌ |

> ⚠️ Jungle 是独立固件目标，需要单独 e2e 环境。

### `board/body/main_comms.h` — Body 固件 (0/2 已覆盖)

| 命令 | 功能 | 覆盖状态 |
|------|------|----------|
| 0xb3 | 电机转速 | ❌ |
| 0xb4 | 电机启停 | ❌ |

> ⚠️ Body 是独立固件目标，需要单独 e2e 环境。

---

## 六、`board/main.c` 主循环行为

### 🔴 高优先级（行为显著、可测）

#### P1 — `bootkick_tick()` SOM 启动/复位 FSM

```
文件: board/drivers/bootkick.h
调用: main.c:176 (1Hz tick)
```

**5 态状态机：**
```
BOOT_BOOTKICK → BOOT_STANDBY → (STANDBY→BOOTKICK edge) → 20 tick 等待 → BOOT_RESET → BOOT_BOOTKICK
```

- `bootkick_reset_triggered` 标志位（出现在 health packet 中但未被测试）
- 复位倒计时、串口活动检测、SOM GPIO 检测
- 3 种中止路径：串口活动、SOM GPIO 高、非 BOOTKICK 状态

**状态：** ✅ `bootkick.feature` (14 场景，含 @cuatro × 11 + @tres × 3) + `bootkick.md` 设计文档，全部通过，通过 `jna_call_tick_handler`（完整生产代码 `tick_handler()`）调用真实 `bootkick_tick()` 代码。

#### P2 — 心跳丢失自动行为

```
文件: board/main.c:185-244
```

| 行为 | 代码位置 | 覆盖 |
|------|----------|------|
| `controls_allowed` → false（3 次 heartbeat_engaged 不匹配） | main.c:201-208 | ✅ `heartbeat_loss.feature` Scenario 1 |
| 心跳超时 2-5 秒 → SILENT + 省电 | main.c:210-245 | ✅ `heartbeat_loss.feature` Scenario 2,3 |
| `siren_countdown` 3 秒触发 | main.c:217-220 | ✅ `heartbeat_loss.feature` Scenario 4 |
| `controls_allowed_countdown` 5 秒宽限期 | main.c:192-196 | ✅ `heartbeat_loss.feature` Scenario 5（countdown 过期后不触发 siren） |
| 心跳丢失时 IR 关闭 + 风扇按 SOM GPIO 调整 | main.c:238-243 | ✅ `heartbeat_loss.feature` Scenario 6,7,8 |
| `heartbeat_disabled` 旁路 | main.c:210 | ✅ `heartbeat_loss.feature` Scenario 9 |

**状态：** ✅ `heartbeat_loss.feature` (9 场景)，全部通过，通过 `jna_call_tick_handler` 调用真实生产代码。

#### P3 — `simple_watchdog_kick()` 看门狗

```
文件: board/drivers/simple_watchdog.h
调用: main.c:131 (8Hz tick_handler)
```

- 375ms 超时阈值 (`3*1000000/8` μs) → `FAULT_HEARTBEAT_LOOP_WATCHDOG` (bit 26)
- 测试通过 `timerValue` 控制微秒定时器，在 tick 之间推进时间
- **状态：** ✅ `watchdog.feature` (3 场景)，直接 include 真实 `board/drivers/simple_watchdog.h` 生产代码

#### P4 — `relay_malfunction` 故障边沿检测

```
文件: board/main.c:134-141
调用: 8Hz tick_handler
```

- **状态：** ✅ `relay_malfunction.feature`（3 个场景，通过 `jna_call_tick_handler` 调用真实生产代码 `tick_handler()`）

#### P5 — `check_registers()` 寄存器发散检测

```
文件: board/drivers/registers.h
调用: main.c:248 (1Hz)
```

- 影子寄存器校验 → `FAULT_REGISTER_DIVERGENT`
- **状态：** ✅ `register_divergence.feature` (3 场景)，全部通过
- **实现方式：** e2e `stm32h7_config.h` 引入真实 `registers.h`（替换原有空存根），`jna_set_register_divergent()` 直接注入 `register_map` 制造发散状态，`init_registers()` 在 `jna_panda_init()` 末尾调用清除初始化噪音
- **行覆盖：** `check_registers()` 内部 100% 行 + 分支覆盖

### 🟡 中优先级（状态变量 / 辅助路径）

#### P6 — WFI 空闲路径

```
文件: board/main.c:377-385
```

- CUATRO `enter_stop_mode()` ✅ 已覆盖
- 非 CUATRO 的 `__WFI()` 空闲路径 ✅ 已覆盖 (`wfi_idle.feature`, 3 场景，通过 `jna_process_wfi_idle` 调用生产代码)

#### P7 — `ignition_can_cnt` / `ignition_can` 自动复位

```
文件: board/main.c:251-253
```

- CAN 流量停止后 `ignition_can_cnt` 递增，超过 2 后 `ignition_can = false`
- 测试通过 `jna_set_ignition_can` 设置初始状态 + `jna_call_tick_handler` 驱动 tick 累积验证
- **状态：** ✅ `ignition_can.feature` (2 场景)，全部通过

#### P8 — `fan_state.cooldown_counter` 冷却保持

- 风扇断电后继续运行 `cooldown_time * 8` 个 tick
- **状态：** ✅ `fan_cooldown.feature` (3 场景) + 设计文档 (`fan-cooldown.md`)，全部通过，通过 `jna_call_tick_handler` 调用真实 `fan_tick()` 代码

#### P9 — `harness_detect_orientation()` 线束翻转检测

```
文件: board/drivers/harness.h:52-88
```

- SBU ADC 电压检测逻辑
- **状态：** ✅ `harness_detect.feature` (8 场景) + 设计文档 (`harness-detect.md`)，通过 `generate_harness_stubs.py` 逐字提取生产代码，`lladc.h` 桩拦截 `adc_get_mV()`

### 🟢 低优先级（仅初始化 / 调试）

#### P10 — LED 行为

| LED | 行为 | 代码位置 |
|-----|------|----------|
| 绿灯 | `controls_allowed` | main.c:166 |
| 蓝灯 | 省电模式闪烁 | main.c:170 |
| 红灯 | 呼吸渐变（非省电）/ 慢闪（故障） | main.c:354-375 |

> 仅调试指示，无功能影响。**状态：** ❌ 无测试需求

#### P11 — `sound_tick()` / `sound_init()` 音频子系统

```
文件: board/stm32h7/sound.h
```

- 麦克风空闲超时、功放空闲超时
- `sound_output_level` 出现在 health packet，但未驱动
- **状态：** ❌ 无测试

#### P12 — `safety_mode_cnt` 递增计数器

- 每秒自增，仅在 safety hooks 内部使用
- **状态：** ❌ 无测试需求

---

## 七、权限状态总结

| 优先级 | 项目 | 代码文件 | 覆盖状态 | 工作量估算 |
|--------|------|---------|----------|-----------|
| **P1** | `bootkick_tick()` FSM | `board/drivers/bootkick.h` | ✅ feature 已有 (`bootkick.feature`，14 场景) + 设计文档 (`bootkick.md`)，全部通过，通过 `jna_tick_handler` 调用真实代码 | — |
| **P2** | 心跳丢失自动行为 | `board/main.c:185-244` | ✅ `heartbeat_loss.feature` (9 场景) + 设计文档 (`heartbeat-loss.md`)，全部通过，通过 `jna_call_tick_handler` 调用真实生产代码 | — |
| **P3** | `simple_watchdog` 看门狗 | `board/drivers/simple_watchdog.h` | ✅ `watchdog.feature` (3 场景) + 设计文档 (`watchdog.md`)，直接 include 生产代码 | — |
| **P4** | `relay_malfunction` 故障检测 | `board/main.c:134-141` | ✅ feature 已有 (`relay_malfunction.feature`，3 场景) + 设计文档 (`relay-malfunction.md`) | — |
| **P5** | `check_registers()` | `board/drivers/registers.h` | ✅ `register_divergence.feature` (3 场景) + 设计文档 (`register-divergence.md`)，通过 `jna_set_register_divergent` 注入 + `init_registers` 在 init 末尾清噪音 | 小 |
| **P6** | WFI 空闲路径 | `board/main.c:377-385` | ✅ 已覆盖 (`wfi_idle.feature`, 3 场景) + 设计文档 (`wfi-idle.md`) | 小 |
| **P7** | `ignition_can_cnt` 复位 | `board/main.c:251-253` | ✅ `ignition_can.feature` (2 场景) + 设计文档 (`ignition-can.md`) | 小 |
| **P8** | `fan_state.cooldown` | `board/drivers/fan.h` | ✅ `fan_cooldown.feature` (3 场景) + 设计文档 (`fan-cooldown.md`)，通过 `jna_call_tick_handler` 调用真实 `fan_tick()` 代码 | 小 |
| **P9** | `harness_detect_orientation` | `board/drivers/harness.h:52-88` | ✅ `harness_detect.feature` (8 场景) + 设计文档 (`harness-detect.md`)，通过 `generate_harness_stubs.py` 逐字提取生产代码，`lladc.h` 桩拦截 `adc_get_mV()` | 小 |
| **P10** | LED 行为 | `board/main.c:166-375` | ❌ 不需要 | — |
| **P11** | `sound_tick()` 音频 | `board/stm32h7/sound.h` | ❌ 不需要 | — |
| **P12** | `safety_mode_cnt` | `board/main.c` | ✅ `tick_paths.feature` (通过 `jna_set_safety_mode_cnt` + `jna_call_tick_handler`) | 小 |
| — | Flasher 命令 (3 个) | `board/flasher.h` | ❌ 新 e2e 目标 | 大 |
| — | Jungle 命令 (8 个) | `board/jungle/main_comms.h` | ❌ 新 e2e 目标 | 大 |
| — | Body 命令 (2 个) | `board/body/main_comms.h` | ❌ 新 e2e 目标 | 小 |

---

## 八、`jna_call_tick_handler()` — 生产代码 tick 触发

`When tick handler` 步骤触发完整的生产代码 `tick_handler()`（`board/main.c`），包含所有 8Hz 和 1Hz 逻辑。通过 `heartbeatDisabled` 控制心跳超时，可精确测试 tick 累积行为。

| 特性 | 状态 | 场景数 |
|------|------|--------|
| `bootkick.feature` | ✅ 14 场景全部通过 | 14 |
| `relay_malfunction.feature` | ✅ 3 场景 | 3 |
| `watchdog.feature` | ✅ 3 场景全部通过 | 3 |
| `heartbeat_loss.feature` | ✅ 9 场景全部通过 | 9 |
| `register_divergence.feature` | ✅ 3 场景全部通过 | 3 |
| `ignition_can.feature` | ✅ 2 场景全部通过 | 2 |
| `tick_paths.feature` | ✅ 6 场景全部通过 (P1: has_fan, heartbeat_counter, safety_mode_cnt, harness reinit) | 6 |

8 次 `jna_call_tick_handler()` 调用 = 1 次 1Hz tick（`loop_counter` 每 8 次归零）。
使用 `When call tick handler {int} times` 批量触发多个 tick。

```
Given exists data → 设置全局状态
When call tick handler N times → 触发生产代码 tick_handler() N 次
Then control data should be → 验证结果
```

适用于：心跳超时、controls_allowed 退出、watchdog、siren_countdown、ignition_can_cnt、fan cooldown 等所有需多 tick 累积的测试。

---

## 九、下一步推荐

### 优先级路线图

```
本周                        下周                        后续
P0 can_comms.h ✅ 完成    → P2 boards/*.h ✅ 完成    → P3 spi_cmd ✅ 完成
P1 main.c tick 路径 ✅ 完成 (去桩化)                   (SPI 通道)
(不改构建，纯加场景)        (板级生产代码直接编译)       (ROI 偏低)
```

### 🔴 P0 — 提升 `can_comms.h` 覆盖率 (当前 18.4%，最高 ROI) ✅ 已完成

**2026-07-25 完成**，新增 `can_comms.feature` 8 个场景，覆盖率从 18.4% → 97.4%。所有 4 个函数 100% 覆盖，可执行行 76/76 (100%)。

已覆盖路径：
- ✅ CAN FD 64 字节帧打包/解包 → DLC=15 正确解析
- ✅ 跨 chunk 分片传输 — write 端 (二次分片、tail > remaining、tail ≤ remaining)
- ✅ 跨 chunk 分片传输 — read 端 (max_len 截断、overflow 排空)
- ✅ `returned` / `rejected` 标志位 — wire format 编解码验证
- ✅ 校验和 mismatch → `can_check_checksum` 返回 false
- ✅ 连续多帧批量读写 — 帧边界正确识别

剩余未覆盖：`refresh_can_tx_slots_available()` 中 `can_tx_check_min_slots_free` 返回 false 的 4 个分支（队列满边界），需硬件层模拟，ROI 偏低。

---

### 🟡 P1 — 提升 `main.c` tick 路径覆盖率 (当前 46.9%) ✅ 已完成

**不改构建，`jna_call_tick_handler` + 新增 `jna_set_heartbeat_counter`/`jna_set_safety_mode_cnt` JNA 桥接。**

| 未覆盖路径 | 代码位置 | 测试思路 | 覆盖场景 |
|-----------|---------|---------|---------|
| `current_board->has_fan` 为 false 跳过 `fan_tick` | fan.h:22 | red panda (无风扇) 下验证 fan_state 不变 | `@red` 风扇状态不变 |
| ~~`power_save_enabled` 与 `controls_allowed` 组合分支~~ → 修正为 harness reinit 路径 | main.c:144-152 | harness 状态变更触发 `set_safety_mode` + `set_power_save_state` | harness reinit 重置心跳计数器 + harness reinit 省电状态保持 |
| `heartbeat_counter` 溢出封顶 | main.c:179-181 | 设 heartbeat_counter = UINT32_MAX(-1)，触发 tick 验证不递增 | heartbeat 计数器封顶 + heartbeat 计数器递增 |
| `safety_mode_cnt` 溢出回绕 | main.c:257 | 设 safety_mode_cnt = UINT32_MAX(-1)，验证回绕到 0 | 安全模式计数器溢出回绕 |

**实现**: `tick_paths.feature` (6 场景)，新增 JNA 函数 `jna_set_heartbeat_counter`、`jna_set_safety_mode_cnt`、`jna_get_safety_mode_cnt`，设计文档 `tick-paths.md`

**工作量**: ~0.5 天 ✅

---

### 🟡 P2 — 将 `boards/{cuatro,red,tres}.h` 从桩切断恢复 ✅ 已完成

**2026-07-26 完成**。这三个文件定义了**板级 GPIO 映射**（CAN 收发器引脚、电压/电流检测引脚、bootkick 引脚）。此前 e2e 中用 `board_stubs_e2e.gen.c` 提取函数副本 + `board_stub` 硬编码替代，真实函数从未编译。

**做法**: 创建 e2e 桩 `board/stm32h7/board.h`，引入真实 `board/boards/{cuatro,red,tres}.h` 生产代码。`detect_board_type()` 保留在 `libpanda.c` 中桩化，但板级函数（`enable_can_transceiver`、`set_bootkick`、`set_amp_enabled`、`set_can_mode`）直接编译真实代码。`libpanda.c` 中的 `e2e_board` 结构体按板型引用真实静态函数，同时保留电压/电流/风扇/IR/警报/SOM GPIO 的 e2e 拦截桩。

**变更文件**:
- 新增 `board/stm32h7/board.h` — e2e 桩，替代真实 `board/stm32h7/board.h`
- 修改 `libpanda.c` — `e2e_board` 替代 `board_stub`，移除 `board_stubs_e2e.gen.c` 引入
- 修改 `build.sh` — 移除 `board_stubs_e2e.gen.c` 生成步骤
- 修改 `fake_stm.h`、`harness.h`、`lladc.h`、`pwm.h` — 类型/宏适配

| 可覆盖的真实函数 | 所属文件 | 状态 |
|-----------------|---------|------|
| `cuatro/tres/red_enable_can_transceiver()` | GPIO 引脚映射 | ✅ 直接编译，现有场景覆盖 |
| `cuatro/tres/red_read_voltage_mV()` | ADC 通道映射 | ✅ 直接编译，e2e 拦截桩保持 |
| `cuatro/tres/red_read_current_mA()` | ADC 通道映射 | ✅ 直接编译，e2e 拦截桩保持 |
| `cuatro/tres_set_bootkick()` | GPIO 引脚映射 | ✅ 直接编译，现有场景覆盖 |
| `cuatro_set_amp_enabled()` | GPIO 引脚映射 | ✅ 直接编译，现有场景覆盖 |

**工作量**: ~1 天 ✅

---

### 🟢 P3 — `main_comms.h` 缺失的 `spi_cmd` (唯一未覆盖的 USB 命令) ✅

33/34 USB 命令已覆盖，`spi_cmd` 即 `comms_endpoint2_write`（USB/SPI endpoint 2 批量写入函数）。
已在 `endpoint2_write.feature` (6 场景) 中通过直接调用真实生产代码完成覆盖。

**工作量**: ✅ 已完成

---

### P0+P1+P2 实际收益

```
P0 完成前综合行覆盖率: 65.1% (575/884)
P0 完成后预估:         79.6% (720/905, + can_comms.h 18.4→100%)
P1 完成后预估:         82-85% (+ main.c tick 路径 4 个新分支, fan.h has_fan=false 路径)
P2 完成后预估:         86-90% (+ boards/*.h 首次直接编译, llfdcan.h 等首次进入)
```
