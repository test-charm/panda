# 端到端测试未覆盖功能清单

> 最后更新: 2026-07-26
> 基准 e2e 场景数: 179 (cuatro 默认, 含 tres/red 板型特定场景)
> 综合行覆盖率: **81.6%** (1459/1789 lines), 29 files
> 数据来源: `e2e-tests/run_all_coverage.sh` (cuatro + tres + red 合并)
>
> **本次更新**: B1 power_saving.h 去桩化完成 — 真实生产代码进入覆盖率 (95.8%), 消除 2 个手写副本文件

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
| `board/main_comms.h` | 97.0% | 3/3 | 仅 default handler print + ALLOW_DEBUG 条件未覆盖 |
| `board/can_comms.h` | 100% | 4/4 | ✅ P0 已完成，全部覆盖 |
| `board/main.c` | 64.2% | 4/7 | 主循环 main()/LED fade 不可达；tick_handler 路径 (P1+P3-P9) ✅ |
| `board/drivers/can_common.h` | 95.3% | 10/12 | 队列指针回绕边界条件 (5 lines) |
| `board/drivers/fan.h` | 100% | 3/3 | ✅ P8 已完成，全部覆盖 |
| `board/drivers/gpio.h` | 70.4% | 5/7 | `set_gpio_analog`、`restore_gpio` 仅 deep_sleep 覆盖 |
| `board/sys/faults.h` | 78.9% | 2/2 | Permanent fault 路径未覆盖 (4 lines) |
| `board/drivers/clock_source.h` | 17.5% | 1/2 | `clock_source_init()` 从未被调用 — **最高 ROI 未覆盖** |
| `board/libc.h` | 61.3% | 3/5 | `delay()`、`assert_fatal()`、`memcmp()` 未覆盖 |
| `board/drivers/registers.h` | 97.8% | — | 仅 1 行未覆盖 (hash collision fallback) |
| `board/drivers/simple_watchdog.h` | 100% | — | ✅ P3 已完成 |
| `board/sys/power_saving.h` | 95.8% | — | ✅ B1 完成，真实生产代码直接编译 |
| `board/sys/sys.h` | 83.3% | — | 头文件 (声明) |
| `board/utils.h` | 100% | — | 全部覆盖 |
| `board/boards/cuatro.h` | 34.8% | — | `cuatro_init()` GPIO 配置路径未调用 (P2 首次编译) |
| `board/boards/tres.h` | 58.7% | — | `tres_init()` GPIO 配置路径未调用 (P2 首次编译) |
| `board/boards/red.h` | 65.7% | — | `red_init()` GPIO 配置路径未调用 (P2 首次编译) |
| `board/boards/unused_funcs.h` | 26.1% | — | 大量未使用空函数 |
| `board/boards/board_declarations.h` | 50.0% | — | 板型特定声明 |

---

## 一、被 e2e 桩替换的文件 (19 个)

这些 `board/` 下的生产代码文件在 e2e 构建中被同路径的桩文件替换，**真实代码从未编译**，因此覆盖率报告中不存在。

### 桩替换机制

`build.sh` 的 include 路径优先级：`-I e2e-tests/src/test/c` > `-I board/`。当 `e2e-tests/src/test/c/board/xxx.h` 存在时，编译器使用桩文件而非真实 `board/xxx.h`。

### 替换清单

| 真实文件 | e2e 桩 | 替换原因 | 核心功能 |
|----------|--------|---------|---------|
| `board/provision.h` | 空桩 (返回假数据) | 无真实 OTP 存储 | 设备序列号/Provision 读取 |
| `board/sys/power_saving.h` | ✅ **B1 已完成 — 真实生产代码直接编译** | — | `enter_stop_mode()`, `set_power_save_state()`, `enable_can_transceivers()` |
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
| 🟡 中 | `sys/power_saving.h` | ✅ B1 已完成 — 真实生产代码直接编译，覆盖率 95.8% |
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

#### P1 — `bootkick_tick()` SOM 启动/复位 FSM ✅ 已完成

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

**状态：** ✅ `bootkick.feature` (14 场景，含 @cuatro × 11 + @tres × 3)，全部通过，通过 `jna_call_tick_handler` 调用真实生产代码 `tick_handler()`。

#### P2 — 心跳丢失自动行为 ✅ 已完成

```
文件: board/main.c:185-244
```

| 行为 | 代码位置 | 覆盖 |
|------|----------|------|
| `controls_allowed` → false（3 次 heartbeat_engaged 不匹配） | main.c:201-208 | ✅ `heartbeat_loss.feature` Scenario 1 |
| 心跳超时 2-5 秒 → SILENT + 省电 | main.c:210-245 | ✅ `heartbeat_loss.feature` Scenario 2,3 |
| `siren_countdown` 3 秒触发 | main.c:217-220 | ✅ `heartbeat_loss.feature` Scenario 4 |
| `controls_allowed_countdown` 5 秒宽限期 | main.c:192-196 | ✅ `heartbeat_loss.feature` Scenario 5 |
| 心跳丢失时 IR 关闭 + 风扇按 SOM GPIO 调整 | main.c:238-243 | ✅ `heartbeat_loss.feature` Scenario 6,7,8 |
| `heartbeat_disabled` 旁路 | main.c:210 | ✅ `heartbeat_loss.feature` Scenario 9 |

**状态：** ✅ `heartbeat_loss.feature` (9 场景)，全部通过。

#### P3 — `simple_watchdog_kick()` 看门狗 ✅ 已完成

**状态：** ✅ `watchdog.feature` (3 场景)，直接 include 真实 `board/drivers/simple_watchdog.h`。

#### P4 — `relay_malfunction` 故障边沿检测 ✅ 已完成

**状态：** ✅ `relay_malfunction.feature`（3 场景），通过 `jna_call_tick_handler` 调用真实 `tick_handler()`。

#### P5 — `check_registers()` 寄存器发散检测 ✅ 已完成

**状态：** ✅ `register_divergence.feature` (3 场景)，全部通过，行 + 分支覆盖 100%。

### 🟡 中优先级（状态变量 / 辅助路径）

#### P6 — WFI 空闲路径 ✅ 已完成
#### P7 — `ignition_can_cnt` / `ignition_can` 自动复位 ✅ 已完成
#### P8 — `fan_state.cooldown_counter` 冷却保持 ✅ 已完成
#### P9 — `harness_detect_orientation()` 线束翻转检测 ✅ 已完成

---

### 🆕 新增未覆盖项（本次分析发现）

#### N1 — `clock_source_init()` 覆盖率仅 17.5% 🔴 最高 ROI

```
文件: board/drivers/clock_source.h (真实代码，已编译)
```

`clock_source_init(bool enable_channel1)` 是整个 `clock_source.h` 的核心函数，配置 TIM1 为主定时器、TIM8 为从定时器（外部时钟模式）。e2e 中该函数从未被调用 — 仅 `clock_source_set_timer_params()` 被 `clock_source.feature` 调用。

| 路径 | 行号 | 说明 |
|------|------|------|
| `enable_channel1=true` 分支 | 33-35 | TIM1 CH1 输出使能 (GPIOA8 alternate) |
| `enable_channel1=false` 分支 | — | 仅 CH2N 输出 (GPIOB14) |
| TIM1 PSC/ARR/CCMR/CCER/CCR 配置 | 18-25 | 0.1ms tick 基础配置 |
| TIM1 BDTR/SMCR/CR2 主模式 | 43-47 | 主定时器触发输出配置 |
| TIM8 SMCR 从模式 | 48 | 外部时钟模式 1，ITR0 触发源 |
| TIM8 PSC/ARR/CCMR2/CCR3/CCER 复制 | 51-55 | 从定时器参数复制 |
| TIM8 BDTR + GPIOB15 alternate | 58-61 | 从定时器输出使能 |
| TIM1+TIM8 CR1 CEN 启动 | 64-65 | 两个定时器同时启动 |

**测试方式**: 直接调用 `clock_source_init(true)` 和 `clock_source_init(false)`，验证 fake TIM1/TIM8 寄存器值 + GPIO alternate 配置。

**工作量**: ~3 场景，0.5 天

#### N2 — Board `xxx_init()` 函数覆盖率偏低 🔴

```
文件: board/boards/cuatro.h (34.8%), tres.h (58.7%), red.h (65.7%)
P2 已将这些文件从桩切断恢复为真实代码编译
```

各板型的 `xxx_init()` 函数设置 GPIO 模式、输出类型、上下拉。这些函数被 `main()` 调用，但 e2e 中从未执行。未覆盖行：

| 板型 | 未覆盖行 | 核心未覆盖内容 |
|------|---------|---------------|
| `cuatro_init()` | 23-24, 28-30, 32-34, 36-38, 50-51, 54-55, 58-59, 62-64 | GPIO MODER/OTYPER/PUPDR 配置 |
| `tres_init()` | 11-19, 26-30, 49-50, 95-107 | GPIO + ADC 配置 |
| `red_init()` | 23-24, 65-99 | GPIO 配置 |

**测试方式**: 调用 `xxx_init()` 后验证 GPIO MODER/OTYPER/PUPDR/OSPEEDR 寄存器值。

**工作量**: ~6 场景（3 板型 × 2），1 天

#### N3 — `faults.h` Permanent fault 路径 🟡

```
文件: board/sys/faults.h
未覆盖: lines 9-10 (permanent fault 打印), 23-24 ("Cannot recover")
```

当前仅 temporary fault 路径被 watchdog 覆盖。Permanent fault 状态转换未测试。

**工作量**: 1 场景，极低

#### N4 — `can_common.h` 队列指针回绕 🟡

```
文件: board/drivers/can_common.h (95.3%)
未覆盖: lines 47, 64, 90, 101-102 — 队列满时 w_ptr/r_ptr 回绕到 0
```

**工作量**: ~2 场景，0.5 天

#### N5 — `libc.h` `delay()` / `assert_fatal()` / `memcmp()` 🟢

```
文件: board/libc.h (61.3%)
```

`delay()` 是忙等待循环，`assert_fatal()` 是死循环，`memcmp()` 是标准比较。低业务价值。

**工作量**: ~2 场景，低 ROI

### 🟢 低优先级（仅初始化 / 调试）

#### P10 — LED 行为 ❌ 不需要
#### P11 — `sound_tick()` / `sound_init()` 音频子系统 ❌ 不需要
#### P12 — `safety_mode_cnt` 递增计数器 ✅ 已完成

---

## 七、权限状态总结

| 优先级 | 项目 | 代码文件 | 覆盖状态 | 工作量估算 |
|--------|------|---------|----------|-----------|
| **P1** | `bootkick_tick()` FSM | `board/drivers/bootkick.h` | ✅ `bootkick.feature` (14 场景) | — |
| **P2** | 心跳丢失自动行为 | `board/main.c:185-244` | ✅ `heartbeat_loss.feature` (9 场景) | — |
| **P3** | `simple_watchdog` 看门狗 | `board/drivers/simple_watchdog.h` | ✅ `watchdog.feature` (3 场景) | — |
| **P4** | `relay_malfunction` 故障检测 | `board/main.c:134-141` | ✅ `relay_malfunction.feature` (3 场景) | — |
| **P5** | `check_registers()` | `board/drivers/registers.h` | ✅ `register_divergence.feature` (3 场景) | — |
| **P6** | WFI 空闲路径 | `board/main.c:377-385` | ✅ `wfi_idle.feature` (3 场景) | — |
| **P7** | `ignition_can_cnt` 复位 | `board/main.c:251-253` | ✅ `ignition_can.feature` (2 场景) | — |
| **P8** | `fan_state.cooldown` | `board/drivers/fan.h` | ✅ `fan_cooldown.feature` (3 场景) | — |
| **P9** | `harness_detect_orientation` | `board/drivers/harness.h:52-88` | ✅ `harness_detect.feature` (8 场景) | — |
| **P10** | LED 行为 | `board/main.c:166-375` | ❌ 不需要 | — |
| **P11** | `sound_tick()` 音频 | `board/stm32h7/sound.h` | ❌ 不需要 | — |
| **P12** | `safety_mode_cnt` | `board/main.c` | ✅ `tick_paths.feature` | — |
| **N1** | `clock_source_init()` | `board/drivers/clock_source.h` | ❌ **17.5% → 目标 95%+** | 0.5 天 |
| **N2** | Board `xxx_init()` | `board/boards/{cuatro,tres,red}.h` | ❌ **35-66% → 目标 70%+** | 1 天 |
| **N3** | Permanent fault | `board/sys/faults.h` | ❌ **78.9% → 目标 100%** | 极低 |
| **N4** | CAN queue wrap | `board/drivers/can_common.h` | ❌ **95.3% → 目标 100%** | 0.5 天 |
| **N5** | `libc.h` 未覆盖路径 | `board/libc.h` | ❌ **61.3%** (低 ROI) | 0.5 天 |
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
本周                                    下周                              后续
N1 clock_source_init (17.5% → 95%+)    N2 board xxx_init() (35-66%+)    N4 can_common wrap
N3 faults permanent (78.9% → 100%)      B2 bootkick.h 去桩化               N5 libc.h (低 ROI)
✅ B1 power_saving.h 去桩化 (已完成)                                       Jungle/Body 固件
```

---

### 🔴 Phase A — 不改构建，纯加场景（最高 ROI）

#### N1 — `clock_source_init()` 覆盖率从 17.5% 提升到 95%+

**文件**: `board/drivers/clock_source.h`（真实生产代码，已编译但从未调用）

`clock_source_init(bool enable_channel1)` 配置 TIM1（主模式）和 TIM8（从模式/外部时钟）寄存器。e2e 中仅 `clock_source_set_timer_params()` 被调用（33% 覆盖），`clock_source_init()` 从未执行。

| 场景 | 测试内容 |
|------|---------|
| 初始化 (channel1 使能) | `clock_source_init(true)` → 验证 TIM1 PSC/ARR/CCMR1/CCER, TIM8 SMCR/PSC/ARR/CCR3, GPIOA8 + GPIOB14 alternate |
| 初始化 (channel1 禁用) | `clock_source_init(false)` → 验证 GPIOA8 alternate 未使能，GPIOB14 仍使能 |
| 寄存器完整性 | 验证 BDTR/MOE, CR2/MMS, BDTR/MOE for TIM8, CR1/CEN for both TIMs |

**JNA 接口**：现有 `jna_get_TIM1_CCR1()` 等函数可复用。需额外暴露 TIM1 SMCR/BDTR/CR2/DIER 和 TIM8 PSC/ARR/SMCR/CCR3/BDTR。

**预估收益**: `clock_source.h` 从 17.5% → 90%+（~33 uncovered lines）

**工作量**: ~3 场景，0.5 天

---

#### N2 — Board `xxx_init()` 覆盖率提升

**文件**: `board/boards/{cuatro,tres,red}.h`（P2 已首次编译为真实代码，但从未调用 init 函数）

| 板型 | 当前覆盖 | 未覆盖核心路径 |
|------|---------|---------------|
| `cuatro_init()` | 34.8% | GPIO MODER/OTYPER/PUPDR for CAN transceiver, bootkick, fan, relay pins |
| `tres_init()` | 58.7% | GPIO + ADC 配置, clock source TIM 配置 |
| `red_init()` | 65.7% | GPIO 配置, 电压/电流 ADC 通道 |

**测试方式**: 每种板型 2 场景（调用 init + 验证寄存器，验证不崩溃）

**预估收益**: 3 个文件从 35-66% → 70-85%（~25 uncovered lines）

**工作量**: ~6 场景，1 天

---

#### N3 — `faults.h` Permanent fault 路径

**文件**: `board/sys/faults.h`，当前 78.9%，仅 4 行未覆盖

| 场景 | 测试内容 |
|------|---------|
| Permanent fault 不可恢复 | 触发 permanent fault → 再次 `fault_occurred()` → 验证 "Cannot recover" 消息 |

**工作量**: 1 场景，极低

---

#### N4 — `can_common.h` 队列指针回绕

**文件**: `board/drivers/can_common.h`，当前 95.3%，5 行未覆盖

| 场景 | 测试内容 |
|------|---------|
| w_ptr 回绕 | 填充队列使 `w_ptr` 回绕到 0 → 验证 `next_w_ptr` 计算 |
| r_ptr 回绕 | `can_clear_rx()` 但 `r_ptr` 已经为 0 → 验证边界 |
| can_tx_check_min_slots_free 回绕 | w_ptr < r_ptr → 容量计算正确 |

**工作量**: ~2 场景，0.5 天

---

### 🟡 Phase B — 减少测试桩，引用更多生产代码

#### B1 ✅ — 合并 `power_save_e2e.gen.c` + `enter_stop_mode_e2e.gen.c` → 真实 `board/sys/power_saving.h`（已完成 2026-07-26）

**实施结果**:
- 删除 `e2e-tests/src/test/c/board/sys/power_saving.h`（e2e 桩）
- 删除 `power_save_e2e.gen.c`（37 行手写副本）
- 删除 `enter_stop_mode_e2e.gen.c`（98 行手写副本）
- 真实 `board/sys/power_saving.h` 添加 `#pragma once`（防重入保护）
- `enable_can_transceivers` 使用纯生产代码，移除 `#ifdef E2E_TEST` 跟踪
- CMSIS 寄存器宏前置到 `board/main.c` 之前
- 新增 3 个翻转线束场景（`@cuatro/@tres/@red`），覆盖 `harness.status == HARNESS_STATUS_FLIPPED` → `main_bus = 3U` 分支
- `power_saving.h` 覆盖率: 0% → **95.8%** (92/96 lines)
- 综合覆盖率: 79.6% → **81.6%**
- 同步清理: `ir_power_call_count` / `last_siren_state` / `canTransceiversCallCount` 等冗余跟踪变量（用寄存器断言替代）

#### 跟踪桩 → 寄存器断言 对照表

B1 揭示的模式：`libpanda.c` 中的调用计数 / 状态保存跟踪变量，可通过假寄存器直接读取来替代。

| 跟踪变量 | 来源 | 寄存器断言 | 状态 |
|---------|------|-----------|------|
| `ir_power_call_count` | `board_set_ir_power_stub` | `irPowerValue` (TIM1.CCR1) | ✅ 已清理 |
| `last_siren_state` | `board_set_siren_stub` | `gpioBOdr` bit14 (GPIOB 14) | ✅ 已清理 |
| `canTransceiversCallCount` | `enable_can_transceivers` | `gpio*Odr` (板级 GPIO) | ✅ 已清理 |
| `canTransceiversEnabled` | `enable_can_transceivers` | `gpio*Odr` (板级 GPIO) | ✅ 已清理 |
| `siren_was_active` | `board_set_siren_stub` (latch) | — 无寄存器等价 | ✗ 不可替代 |
| `irqEnableCount` | `llcan_irq_enable` | — NVIC ICER/ISER 未暴露 | ✗ 需先加 NVIC 状态 |
| `irqDisableCount` | `llcan_irq_disable` | — 同上 | ✗ |
| `lastIrqEnabledBus` | `llcan_irq_enable` | — 同上 | ✗ |
| `irqDisabledBus*` | `llcan_irq_disable` | — 同上 | ✗ |
| `nvicResetCount` | `NVIC_SystemReset` | — SCB AIRCR 未暴露 | ✗ 低 ROI |

---

#### B2 — 替换 `bootkick_e2e.gen.c` → 真实 `board/drivers/bootkick.h`

**当前状态**: `bootkick_e2e.gen.c`（58 lines, 98.3% 覆盖）由 `generate_bootkick_stubs.py` 从真实 `bootkick.h` 提取生成

**目标**: 直接 `#include "board/drivers/bootkick.h"` 真实生产代码

**障碍**: 真实 `bootkick.h` 使用 `USART_TypeDef`。解决方案：在 `fake_stm.h` 中添加最小化 `USART_TypeDef` 定义（仅需包含 bootkick 用到的寄存器字段）。

**收益**: 消除 1 个生成文件 + 1 个生成脚本

**工作量**: ~0.5 天

---

### 预估总收益

```
Phase A 完成后:  79.6% → ~85%   (770/905 lines)
✅ B1 完成:       power_saving.h 进入覆盖率 (95.8%), 综合 81.6%
Phase B 剩余:     ~81.6% → ~83%  (完成 B2 bootkick 去桩化)
```

---

## 十、`libpanda.c` 桩库存与去桩化机会

### 当前状态：哪些已是真实代码，哪些还是桩

```
libpanda.c (精简后) 编译模型:
  #include "board/main.c"                    ← ✅ 完整固件 (main.c 内 include 真实 power_saving.h)
  #include "board/drivers/fan.h"             ← ✅ 真实代码 (100% 覆盖)
  #include "board/drivers/clock_source.h"    ← ✅ 真实代码 (17.5% 覆盖 — 仅 set_timer_params 被调用)
  #include "board/drivers/simple_watchdog.h" ← ✅ 真实代码 (100% 覆盖)
  #include "board/libc.h"                    ← ✅ 真实代码 (61.3% 覆盖)
  #include "board/drivers/registers.h"       ← ✅ 真实代码 (97.8% 覆盖)
  #include "board/sys/faults.h"              ← ✅ 真实代码 (78.9% 覆盖)
  #include "board/drivers/harness.h"         ← ✅ 真实代码 (struct + 声明)
  #include "board/drivers/uart.h"            ← ✅ 真实代码
  #include "boards/board_declarations.h"     ← ✅ 真实代码
  #include "board/boards/{cuatro,tres,red}.h" ← ✅ 真实代码 (P2, 35-66% 覆盖)
  #include "board/drivers/gpio.h"            ← ✅ 真实代码 (70.4% 覆盖)
  #include "board/drivers/interrupts.h"      ← ⚠️ e2e 桩 (空实现)
  #include "board/stm32h7/stm32h7_config.h"  ← ⚠️ e2e 桩 (最小化)
  #include "board/stm32h7/lladc.h"           ← ⚠️ e2e 桩 (拦截 adc_get_mV)
  #include "board/drivers/pwm.h"             ← ⚠️ e2e 桩 (空实现)
  #include "board/drivers/led.h"             ← ⚠️ e2e 桩 (空实现)
  #include "board/drivers/timers.h"          ← ⚠️ e2e 桩 (空实现)
  #include "board/drivers/spi.h"             ← ⚠️ e2e 桩 (空实现)
  #include "board/drivers/usb.h"             ← ⚠️ e2e 桩 (空实现)
  #include "board/drivers/fake_siren.h"      ← ⚠️ e2e 桩 (空实现)
  #include "fdcan_e2e.gen.c"                 ← 🔧 从 llfdcan.h 提取 (93.6% 覆盖)
  #include "can_health_e2e.gen.c"            ← 🔧 从 fdcan.h 提取 (94.6% 覆盖)
  #include "bootkick_e2e.gen.c"              ← 🔧 从 bootkick.h 提取 (98.3% 覆盖)
  #include "harness_detect_e2e.gen.c"        ← 🔧 从 harness.h 提取 (100% 覆盖)
```

### 去桩化机会排序

| 优先级 | 桩/Gen 文件 | 替换目标 | 收益 | 障碍 |
|--------|-----------|---------|------|------|
| ✅ B1 | `power_save_e2e.gen.c` + `enter_stop_mode_e2e.gen.c` | `board/sys/power_saving.h` | ✅ 已完成 — 真实代码覆盖率 95.8% | `enter_stop_mode` 为 static (通过文本 include 解决) |
| 🔴 B2 | `bootkick_e2e.gen.c` | `board/drivers/bootkick.h` | 消除 1 个生成文件 + 生成脚本 | 需 USART_TypeDef stub |
| 🟡 B3 | `fdcan_e2e.gen.c` | `board/stm32h7/llfdcan.h` | 消除最大的生成文件 (140 lines) | 依赖大量 STM32 HAL 头 |
| 🟡 B4 | `can_health_e2e.gen.c` | `board/drivers/fdcan.h` | 消除 1 个生成文件 (37 lines) | fdcan.h 已有 e2e 桩 |
| 🟢 B5 | `harness_detect_e2e.gen.c` | `board/drivers/harness.h` | 消除 1 个生成文件 (29 lines) | 函数为 static，低优先级 |

### 不可去桩化的文件

| 文件 | 理由 |
|------|------|
| `interrupts.h`, `timers.h`, `usb.h`, `spi.h`, `led.h`, `pwm.h` | 纯 STM32 外设初始化，无独立业务逻辑 |
| `stm32h7_config.h` | 中央配置枢纽，必须桩化以切断 CMSIS/HAL 依赖链 |
| `lladc.h` | 必须拦截 `adc_get_mV()` 以注入测试数据 |
| `early_init.h`, `provision.h`, `crc.h` | 硬件特定功能 |
