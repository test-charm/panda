# 端到端测试未覆盖功能清单

> 最后更新: 2026-07-27
> 基准 e2e 场景数: 197 (cuatro 默认, 含 tres/red 板型特定场景)
> 综合行覆盖率: **90.0%** (1605/1783 lines), 29 files
> 数据来源: `e2e-tests/run_all_coverage.sh` (cuatro + tres + red 合并)
>
> **本次更新**: B5 harness.h 去桩化 ✅ (82.2% → 90.0%)，`deep_sleep.feature` tres gpioAOdr 期望值修正

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
| `board/drivers/can_common.h` | 100% | 10/12 | ✅ N4 已完成，can_queue_wrap.feature (5 场景) |
| `board/drivers/fan.h` | 100% | 3/3 | ✅ P8 已完成，全部覆盖 |
| `board/drivers/gpio.h` | 70.4% | 5/7 | `set_gpio_analog`、`restore_gpio` 仅 deep_sleep 覆盖 |
| `board/sys/faults.h` | 100% | 2/2 | ✅ N3 已完成，permanent_fault.feature (2 场景) |
| `board/drivers/clock_source.h` | 95.0% | 2/2 | ✅ N1 已完成，clock_source_init.feature (6 场景) |
| `board/libc.h` | 83.9% | 3/5 | memcmp 全覆盖 ✅；delay + assert_fatal(false) 不可覆盖 |
| `board/drivers/registers.h` | 97.8% | — | 仅 1 行未覆盖 (hash collision fallback) |
| `board/drivers/simple_watchdog.h` | 100% | — | ✅ P3 已完成 |
| `board/sys/power_saving.h` | 95.8% | — | ✅ B1 完成，真实生产代码直接编译 |
| `board/drivers/bootkick.h` | ~98% | — | ✅ B2 完成，FSM 逻辑直接编译 |
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
| `board/crc.h` | ✅ **C1 已完成 — 真实生产代码直接编译** | — | CRC-8 校验 (`crc_checksum`)；纯 C 算法，通过 `spi_version_packet()` 覆盖 |
| `board/drivers/bootkick.h` | ✅ **B2 已完成 — 真实生产代码直接编译** | — | SOM 启动/复位状态机 |
| `board/drivers/fdcan.h` | `fdcan_e2e.gen.c` (从真实源码生成) + ✅ `can_health_pkt.h` (B4 共享文件) | 无 FDCAN 外设 | `can_init()`, `can_rx()` 等；`update_can_health_pkt()` 已提取为共享 |
| `board/drivers/usb.h` | 空桩 | 无真实 USB OTG | `usb_init()`, `usb_irqhandler()` |
| `board/drivers/spi.h` | 空桩 | 无真实 SPI | `spi_init()`, SPI DMA 传输 |
| `board/drivers/fake_siren.h` | 空桩 | 无真实蜂鸣器 GPIO | 蜂鸣器控制 |
| `board/drivers/harness.h` | ✅ **B5 已完成 (2026-07-27)** | — | `set_intercept_relay()`, `harness_check_ignition()`, `harness_tick()`, `harness_init()`, `harness_detect_orientation()` — 107 行生产代码直接编译 |
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
| 🔴 高 | `drivers/bootkick.h` | ✅ B2 已完成 — 真实代码直接编译，覆盖率进入主报告 |
| 🔴 高 | `drivers/harness.h` | ✅ B5 已完成 — 真实代码直接编译，覆盖率进入主报告 |
| 🟡 中 | `sys/power_saving.h` | ✅ B1 已完成 — 真实生产代码直接编译，覆盖率 95.8% |
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

#### N2 — Board `xxx_init()` 函数覆盖率 ✅ 已完成 (2026-07-26)

```
文件: board/boards/cuatro.h (95.8%), tres.h (89.5%), red.h (100%)
通过 board_init.feature 7 个场景覆盖 + common_init_gpio/gpio_uart7_init 去桩化
```

**实施内容：**

1. **JNA 接口**: `jna_board_init()` 调用 `current_board->init()`，之前重置 GPIO/PWR/TIM/NVIC 为清洁状态，预置 PWR_CR3_USB33RDY 避免 tres_init USB LDO 自旋等待。
2. **寄存器 getter**: 新增 GPIO OTYPER/OSPEEDR/PUPDR (A-G)、AFR (C/D/E)、PWR_CR3、GPIO ODR (C/D/E) 的 JNA 访问器。
3. **去桩化**: `common_init_gpio()` 和 `gpio_uart7_init()` 从空桩替换为真实实现（复制自 `board/stm32h7/peripherals.h`）。`uart_init()`、`sound_init()`、`pwm_init()` 保持桩切断（无 GPIO 寄存器副作用）。
4. **Java 侧**: `BoardInitState` (45 字段 DTO)、`boardInit()` / `getBoardInit()`、`When board init` 步骤。

**场景覆盖**:

| 场景 | 板型 | 验证的寄存器 |
|------|------|------------|
| GPIO MODER 全部端口 | Cuatro | gpioA/B/C/D/E/F/G_Moder |
| OTYPER 开漏引脚 | Cuatro | gpioC/D_Otyper (FAN_EN, DC_IN_EN_N) |
| PUPDR 上下拉 | Cuatro | gpioB/C_Pupdr (SOM GPIO, CAN 收发器) |
| USB OSPEEDR | Cuatro | gpioA_Ospeedr (USB FS pins) |
| USB LDO + 板级 GPIO | Tres | pwrCr3, gpioC_Moder/Pupdr/Otyper/Odr |
| CAN 收发器 + 电压检测 | Red | gpioB/D/G_Moder, gpioB_Otyper/Pupdr/Odr, gpioF_Moder |
| USB 引脚 | Red | gpioA_Moder/Ospeedr |

**每行覆盖状态**:

| 板型 | 总行数 | 已覆盖 | 桩切断 | 有效覆盖率 |
|------|--------|--------|--------|-----------|
| `cuatro_init()` | 24 | 23 | 1 (uart_init) | 95.8% |
| `tres_init()` | 19 | 17 | 2 (uart_init, pwm_init) | 89.5% |
| `red_init()` | 17 | 17 | 0 | 100% |
| **合计** | **60** | **57** | **3** | **95.0%** |

**工作量**: 7 场景（实际），1 天（预估一致）

#### N3 — `faults.h` Permanent fault 路径 ✅ 已完成 (2026-07-27)

```
文件: board/sys/faults.h
覆盖率: 78.9% → 100% (33/33 lines)
```

实施: `#ifdef E2E_TEST` 块覆盖 `PERMANENT_FAULTS` 为 `FAULT_UNUSED_INTERRUPT_HANDLED`，
新增 `permanent_fault.feature` (2 场景) 覆盖永久故障不可恢复 + 幂等路径。

**工作量**: 2 场景，极低 ✅ 已完成

#### N4 — `can_common.h` 队列指针回绕 ✅ 已完成

```
文件: board/drivers/can_common.h (95.3% → 100%)
已完成: lines 47, 64, 90, 101-102 — `can_queue_wrap.feature` (5 场景)
```

#### N5 — `libc.h` `delay()` / `assert_fatal()` / `memcmp()` ✅ 已完成

```
文件: board/libc.h (61.3% → 83.9%)
已完成: memcmp() 全路径覆盖 (通过真实 provision.h + serial.feature TC3)
剩余: delay() 6 lines + assert_fatal(false) 5 lines — 自然不可覆盖
```

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
| **N1** | `clock_source_init()` | `board/drivers/clock_source.h` | ✅ **17.5% → 95%+** (已完成) | — |
| **N2** | Board `xxx_init()` | `board/boards/{cuatro,tres,red}.h` | ✅ **35-66% → 95%+** (已完成) | — |
| **N3** | Permanent fault | `board/sys/faults.h` | ✅ **100%** (已完成 2026-07-27) | 极低 |
| **N4** | CAN queue wrap | `board/drivers/can_common.h` | ✅ **100%** (已完成 2026-07-27) | 0.5 天 |
| **N5** | `libc.h` 未覆盖路径 | `board/libc.h` | ✅ **83.9%** (已完成 2026-07-27，通过真实 provision.h) | 0.5 天 |
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
✅ N1 clock_source_init (17.5% → 95%+)   N4 can_common wrap (100%)        N5 libc.h (83.9%, 真实 provision.h)
✅ N3 faults permanent (78.9% → 100%)    ✅ B2 bootkick.h 去桩化 (已完成)     Jungle/Body 固件
✅ B1 power_saving.h 去桩化 (已完成)     ✅ B2 bootkick.h 去桩化 (已完成)
🟡 B3 fdcan (硬件轮询, 不去桩)            ✅ B4 can_health 共享文件 (已完成)
✅ N2 board xxx_init() (35-66% → 95%+)   ✅ common_init_gpio 去桩化
🟡 B5 harness.h 去桩化 (对标 B2 模式)
✅ C1 crc.h 去桩化 (空桩, 通过 spi_version_packet 测试覆盖)
✅ C2 llfdcan_declarations.h 去桩化
```

---

### 🔴 Phase A — 不改构建，纯加场景（最高 ROI）

#### N1 — `clock_source_init()` 覆盖率从 17.5% 提升到 95%+ ✅ 已完成

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

#### N2 — Board `xxx_init()` 覆盖率提升 ✅ 已完成 (2026-07-26)

**文件**: `board/boards/{cuatro,tres,red}.h`，通过 `board_init.feature` 7 个场景 + 去桩化 `common_init_gpio` / `gpio_uart7_init`

| 板型 | 当前覆盖 | 未覆盖核心路径 |
|------|---------|---------------|
| `cuatro_init()` | **95.8%** (23/24) | `uart_init()` 桩切断 (无 GPIO 效果) |
| `tres_init()` | **89.5%** (17/19) | `uart_init()` + `pwm_init()` 桩切断 |
| `red_init()` | **100%** (17/17) | 全部覆盖 |

**实施要点**:
1. `jna_board_init()` → `current_board->init()` 在清洁 GPIO 状态下调用
2. `common_init_gpio()` / `gpio_uart7_init()` 去桩化 (真实代码从 `peripherals.h` 复制)
3. `jna_board_init()` 预置 PWR_CR3_USB33RDY 避免 tres_init USB LDO 自旋
4. `BoardInitState` (45 寄存器字段) 提供 GPIO MODER/OTYPER/OSPEEDR/PUPDR/AFR/ODR 全量访问

**测试场景**: 7 个 (4 cuatro + 1 tres + 2 red)，全部通过。189 场景全量回归无影响。

**预估收益**: 3 个文件从 35-66% → **95.0%** (57/60 行覆盖，仅 3 行桩切断)

**工作量**: 7 场景（实际），1 天（预估一致）

---

#### N3 — `faults.h` Permanent fault 路径 ✅ 已完成 (2026-07-27)

**文件**: `board/sys/faults.h`，覆盖率 78.9% → **100%** (33/33 lines)

**实施**:
1. `board/sys/faults.h` 添加 `#ifdef E2E_TEST` 块，将 `PERMANENT_FAULTS` 覆盖为 `FAULT_UNUSED_INTERRUPT_HANDLED` (bit 1 = 2)
2. `libpanda.c` 新增 `jna_get_fault_status()`, `jna_trigger_fault()`, `jna_recover_fault()` 三个 JNA 辅助函数
3. `PandaClient.java` / `PandaSteps.java` 新增 JNA 接口 + `When trigger fault {int}` / `When recover fault {int}` 步骤定义
4. `permanent_fault.feature` (2 场景) 覆盖永久故障不可恢复 + 幂等路径

| 场景 | 测试内容 |
|------|---------|
| 永久故障不可恢复 | `trigger fault 2` → 验证 faultStatus=2 → `recover fault 2` → 验证 readFaults=2 (不清除) |
| 重复触发幂等 | `trigger fault 2` ×2 → 验证 readFaults=2 (不倍增) |

**工作量**: 2 场景，极低 ✅ 已完成

---

#### N4 — `can_common.h` 队列指针回绕 ✅ 已完成

**文件**: `board/drivers/can_common.h`，**95.3% → 100%** (107/107 lines)，新增 5 场景

| 场景 | 测试内容 |
|------|---------|
| r_ptr 回绕 | 设置 w_ptr=1, r_ptr=415 → push + pop → r_ptr 从 415 回绕到 0 |
| w_ptr 回绕 | 设置 w_ptr=415, r_ptr=1 → push → w_ptr 从 415 回绕到 0 |
| push 失败 | 设置 w_ptr=415, r_ptr=0 (满) → push → 返回 false，w_ptr 不变 |
| slots_empty 回绕 | 设置 w_ptr=100, r_ptr=200 → can_slots_empty → 返回 r_ptr-w_ptr-1=99 |
| slots_empty 正常 | 设置 w_ptr=200, r_ptr=100 → 回归验证 |

**实施**: 新增 JNA 函数 `jna_set_can_queue_state` / `jna_can_push_direct` / `jna_can_pop_direct` / `jna_can_slots_empty`，通过 `CanQueue` 表驱动 Given 前置设置队列状态。

**工作量**: 0.5 天 ✅ 已完成

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

#### B2 ✅ — 替换 `bootkick_e2e.gen.c` → 真实 `board/drivers/bootkick.h`（已完成 2026-07-26）

**实施结果**:
- 删除 `e2e-tests/src/test/c/board/drivers/bootkick.h`（e2e 桩）
- 删除 `bootkick_e2e.gen.c`（94 行生成代码）
- 删除 `generate_bootkick_stubs.py`（生成脚本）
- 真实 `board/drivers/bootkick.h` 添加 `#pragma once` + `#ifdef E2E_TEST` 状态暴露（6 个 static local → 文件作用域全局变量）
- `-DE2E_TEST` 重新加入 `build.sh` CFLAGS
- `board/main.c` 的 include 链自然引入真实 bootkick 代码
- 综合覆盖率: 81.6% → **82.2%** (预估, bootkick.h 94 lines 进入覆盖率)

---

#### B4 ✅ — 提取 `can_health_e2e.gen.c` → 共享文件 `board/drivers/can_health_pkt.h`（已完成 2026-07-26）

**实施结果**:
- 创建 `board/drivers/can_health_pkt.h`（52 行，含 `update_can_health_pkt()`，`#pragma once`）
- `board/drivers/fdcan.h` 中原函数体替换为 `#include "board/drivers/can_health_pkt.h"`
- 删除 `can_health_e2e.gen.c`（57 行）和 `generate_can_health_stubs.py`
- e2e stub `board/drivers/fdcan.h` 添加 `#include "board/drivers/can_health_pkt.h"`
- `libpanda.c` 替换 gen 文件为真实 `can_health_pkt.h`

> 注意：B4 与 B1/B2 模式不同。`fdcan.h` 包含硬件轮询循环无法整文件 include，
> 但 `update_can_health_pkt()` 本身是纯业务逻辑。提取为独立文件后生产和 e2e 共享。

---

#### B5 ✅ — 替换 `harness_detect_e2e.gen.c` → 真实 `board/drivers/harness.h`（已完成 2026-07-27）

**实施结果**:
- 删除 `e2e-tests/src/test/c/board/drivers/harness.h`（e2e 桩）
- 删除 `harness_detect_e2e.gen.c`（29 行生成代码）
- 删除 `generate_harness_stubs.py`（生成脚本）
- 真实 `board/drivers/harness.h` 添加 `#pragma once` + `#ifdef E2E_TEST` 暴露 `harness_detect_orientation()`
- `harness_check_ignition()` E2E 下走 `e2e_ignition_line`
- `set_intercept_relay()` E2E 下 NC 按 NORMAL 处理 + 跳过 NC 短路
- `harness_tick()`/`harness_init()` 中 `harness_detect_orientation()` E2E 下跳过
- `board/drivers/drivers.h` 中 harness 类型/声明移出 `#ifdef STM32H7` 守卫
- e2e `board.h` 中 gpio.h 移到 harness.h 之前；`libpanda.c` 新增 `adc_signal_t` + `harness_configuration` typedef
- `deep_sleep.feature` tres board 场景 `gpioAOdr` 期望值从 521 更新为 265（真实 tres 使用 PA8 而非 PA9）
- 综合覆盖率: 82.2% → **90.0%** (1605/1783 lines, 29 files)

---

### 🟢 Phase C — 低优先级去桩化（远期）

#### C1 — `board/crc.h` 直接 include ✅ 已完成

**文件**: `board/crc.h`（20 行），纯 CRC-8 位运算算法，零硬件依赖。已完成去桩化。

**实施**: 删除 `e2e-tests/src/test/c/board/crc.h`，真实代码自动生效。额外新增 `spi_version_packet.feature` (2 场景) 确保 `crc_checksum()` 通过 `spi_version_packet()` 调用进入覆盖率。

**收益**: 20 行 CRC-8 算法 + 43 行 spi_version_packet，消除 1 个空桩文件。

#### C2 — `board/stm32h7/llfdcan_declarations.h` 直接 include

**文件**: `board/stm32h7/llfdcan_declarations.h`（51 行），纯宏定义和函数声明（`CAN_QUANTA`、`CAN_SEG1` 等）。当前 `fdcan_e2e.gen.c` 内联了所需宏。

**实施**: `libpanda.c` 或 `fdcan_regs.h` 中添加 `#include "board/stm32h7/llfdcan_declarations.h"`，gen 文件复用真实宏定义。

**收益**: 51 行真实宏，gen 文件更干净。

#### C3（远期）— `llfdcan.h` + `fdcan.h` 自变异寄存器方案

**文件**: `board/stm32h7/llfdcan.h`（228 行）+ `board/drivers/fdcan.h`（227 行），共 455 行

**障碍**: 
1. `while()` 硬件轮询循环 → 需实现自变异 FDCAN 寄存器（写 CCCR.INIT 自动置位，对标 TIM 自变异模式）
2. `cans[3]` 数组重复定义（真实 fdcan.h 和 libpanda.c 各一份）→ 需 `#ifdef E2E_TEST` 条件编译
3. `REGISTER_INTERRUPT` 需要 `interrupts[]` 数组 → 需 stub

**工作量**: 2-3 天，不推荐当前阶段实施。gen 脚本方案是正确的折中。

---

### 预估总收益

```
✅ B1 完成:       power_saving.h 进入覆盖率 (95.8%), 综合 81.6%
✅ B2 完成:       bootkick.h 进入覆盖率, 综合 82.2%
✅ B4 完成:       can_health_pkt.h 共享文件, 消除 1 个 gen 文件
✅ B5 完成:       harness.h 去桩化 → 107 行进入覆盖率, 消除 3 文件, 综合 90.0%
✅ C1 完成:       crc.h 去桩化 → 20 行 + spi_version_packet (43 行), 消除 1 个空桩, 新增 spi_version_packet.feature (2 场景)
✅ C2 完成:       llfdcan_declarations.h → 51 行真实宏, 消除 fdcan_regs.h 内联重复
⚪ C3 远期:       llfdcan.h + fdcan.h 自变异寄存器 → 455 行 (不推荐当前阶段)
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
  #include "board/libc.h"                    ← ✅ 真实代码 (83.9% 覆盖)
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
  #include "harness_detect_e2e.gen.c"        ← 🔧 从 harness.h 提取 (100% 覆盖)
```

### 去桩化机会排序

| 优先级 | 桩/Gen 文件 | 替换目标 | 收益 | 障碍 |
|--------|-----------|---------|------|------|
| ✅ B1 | `power_save_e2e.gen.c` + `enter_stop_mode_e2e.gen.c` | `board/sys/power_saving.h` | ✅ 已完成 — 真实代码覆盖率 95.8% | `enter_stop_mode` 为 static (通过文本 include 解决) |
| ✅ B2 | `bootkick_e2e.gen.c` | `board/drivers/bootkick.h` | ✅ 已完成 — 真实代码进入覆盖率 | `static` locals 通过 `#ifdef E2E_TEST` 暴露 |
| 🟡 B3 | `fdcan_e2e.gen.c` | `board/stm32h7/llfdcan.h` | 硬件轮询循环 — 不去桩 (gen 脚本是正确方案) | 需自变异寄存器；远期 C3 |
| ✅ B4 | `can_health_e2e.gen.c` | `board/drivers/can_health_pkt.h` | ✅ 已完成 — 提取为共享文件 | `fdcan.h` 含硬件轮询，仅提取纯业务函数 |
| 🔴 B5 | `harness_detect_e2e.gen.c` + e2e 桩 `harness.h` | `board/drivers/harness.h` | ✅ 已完成 — 107 行真实代码进入覆盖率 + 消除 2 文件 + 1 脚本 | `harness_detect_orientation()` 为 static，`#ifdef E2E_TEST` 暴露 |
| ✅ C1 | e2e 桩 `crc.h` (空文件) | `board/crc.h` | ✅ 已完成 — 20 行纯 CRC-8 算法，消除空桩 + spi_version_packet 测试 | 零障碍 |
| ✅ C2 | — (gen 文件内联宏) | `board/stm32h7/llfdcan_declarations.h` | ✅ 已完成 — 51 行真实宏定义，fdcan_regs.h 消除重复 | 零障碍 |
| ⚪ C3 | `fdcan_e2e.gen.c` + e2e 桩 `fdcan.h` | `board/stm32h7/llfdcan.h` + `board/drivers/fdcan.h` | 455 行真实代码 (远期) | `while()` 轮询 + `cans[]` 冲突 + `REGISTER_INTERRUPT` |

### 不可去桩化的文件

| 文件 | 理由 |
|------|------|
| `interrupts.h`, `timers.h`, `usb.h`, `spi.h`, `led.h`, `pwm.h`, `fake_siren.h` | 纯 STM32 外设初始化，无独立业务逻辑 |
| `stm32h7_config.h` | 中央配置枢纽，必须桩化以切断 CMSIS/HAL 依赖链 |
| `lladc.h` | 必须拦截 `adc_get_mV()` 以注入测试数据 |
| `early_init.h` | 启动流程：`SCB->VTOR`、`jump_to_bootloader()`、`DBGMCU->IDCODE`，无可测业务逻辑 |
| `provision.h` | 已通过 `PROVISION_CHUNK_ADDRESS` override 使用真实代码（`memcpy`/`memcmp` 走真实 `libc.h`） |
| `sound.h` | 音频 DAC 纯硬件操作，无独立业务逻辑 |
| `peripherals.h` | 纯 RCC 时钟使能寄存器操作；`common_init_gpio`/`gpio_uart7_init` 已复制到 e2e `board.h` |
| `clock.h` | PWR/FLASH/RCC 寄存器配置，无可测业务逻辑 |
| `interrupt_handlers.h` | 144 行 `void XXX_IRQHandler(void) { handle_interrupt(XXX_IRQn); }` 样板代码 |
| `critical.h` | `__enable_irq()` / `__disable_irq()` CMSIS 内置函数，e2e 中 `ENTER_CRITICAL`/`EXIT_CRITICAL` 已 stub |
| `llfan.h`, `lluart.h`, `llspi.h`, `llusb.h` | 纯外设寄存器操作（EXTI、SYSCFG、UART/USB/SPI 寄存器） |
| `boards/unused_funcs.h` | 空桩占位函数，生产环境也未使用 |

### 去桩化可行性完整分析 (2026-07-27)

对全部 19 个 e2e 桩文件 + 16 个被 `stm32h7_config.h` 切断的文件逐一分析：

#### ✅ 可直接 include（无生产代码改动）

| 文件 | 行数 | 依赖 | 改动 |
|------|------|------|------|
| `board/crc.h` | 20 | 无（纯 C 位运算） | ✅ C1 已完成 — 删除 e2e 空桩，通过 spi_version_packet 覆盖 |
| `board/stm32h7/llfdcan_declarations.h` | 51 | `FDCAN_GlobalTypeDef`（fdcan_regs.h ✓） | libpanda.c 添加 include |

#### ✅ 可直接 include（需 `#ifdef E2E_TEST` 暴露 static 函数）

| 文件 | 行数 | 依赖 | 改动 |
|------|------|------|------|
| `board/drivers/harness.h` | 107 | `adc_get_mV`（lladc.h 桩 ✓）、`gpio.h`（真实 ✓）、`current_board->harness_config`（✓） | ✅ B5 已完成 — `#pragma once` + `#ifdef E2E_TEST` |

#### ⚠️ 有条件 include（需额外工作）

| 文件 | 行数 | 障碍 | 方案 |
|------|------|------|------|
| `board/stm32h7/llfdcan.h` | 228 | `while()` 硬件轮询 → 死循环 | 方案 A: 保留 gen 脚本剥离轮询；方案 B: 自变异 FDCAN 寄存器 |
| `board/drivers/fdcan.h` | 227 | 依赖 llfdcan.h + `cans[3]` 数组冲突 + `REGISTER_INTERRUPT` | 需先解决 llfdcan.h 问题 + `#ifdef E2E_TEST` 条件编译 |

#### ❌ 不可 include（纯硬件/外设操作，无业务逻辑）

```
early_init.h        — SCB->VTOR, DBGMCU->IDCODE, jump_to_bootloader()
provision.h         — 已通过 PROVISION_CHUNK_ADDRESS override 使用真实代码
peripherals.h       — 纯 RCC 时钟使能；common_init_gpio 已复制到 e2e board.h
clock.h             — PWR/FLASH/RCC 寄存器配置
interrupt_handlers.h — 144 行 IRQ 样板代码
critical.h          — __enable_irq()/__disable_irq() CMSIS 内置函数
llfan.h             — EXTI/SYSCFG 寄存器 + REGISTER_INTERRUPT
lluart.h            — UART 低层寄存器操作
llspi.h             — SPI DMA 寄存器操作
llusb.h             — USB OTG 寄存器操作
sound.h             — 音频 DAC，无独立业务逻辑
timers.h            — TIM 外设初始化
usb.h, spi.h        — 外设初始化
pwm.h, led.h        — PWM/LED 外设初始化
fake_siren.h        — 蜂鸣器 GPIO
interrupts.h        — NVIC 初始化
```

#### 决策矩阵

```
                  直接 include?
         ┌─ 有业务逻辑? ─┬─ 纯 C 算法? ─── ✅ 直接 include (crc.h, llfdcan_declarations.h)
         │               ├─ 有 static? ─── ✅ E2E_TEST 暴露 (harness.h, 对标 B2)
         │               └─ 有 while()? ── ⚠️ 需 gen 脚本或自变异寄存器 (llfdcan.h, fdcan.h)
         └─ 纯外设操作? ─────────────────── ❌ 不可 include
```
