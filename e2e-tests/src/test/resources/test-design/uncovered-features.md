# 端到端测试未覆盖功能清单

> 最后更新: 2026-07-29
> 基准 e2e 场景数: 224 (cuatro 默认, 含 tres/red 板型特定场景)
> 综合行覆盖率: **91.1%** (1989/2183 lines), 35 files
> 数据来源: `e2e-tests/run_all_coverage.sh` (cuatro + tres + red 合并)
>
> **本次更新**: Phase F.5 spi.h 全状态机覆盖完成（+21 场景, 覆盖率从 83.9% → 91.1%, spi.h 从 13.5% → 94.2%）；E.4 fdcan.h can_rx() 全路径覆盖完成；Phase D.1/D.2/D.3 全部完成

---

## 零、e2e 编译模型：哪些文件进入了覆盖率报告

e2e 通过 `libpanda.c` 编译完整 `board/main.c`，利用 `-I` 优先级覆盖机制：
- `-I e2e-tests/src/test/c` (最高优先级 → e2e 桩)
- `-I /path/to/panda` (项目根)
- `-I /path/to/panda/board` (board 目录)

文件被编译为真实生产代码 vs 被桩替换 vs 被切断，取决于 include 路径中的文件是否被 e2e 桩覆盖。

### 进入覆盖率的 25 个真实 `board/` 文件

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
board/sys/power_saving.h              — 省电管理 (B1)
board/drivers/drivers.h               — 中央驱动声明
board/drivers/registers.h             — 寄存器影子校验
board/drivers/can_common.h            — CAN 队列、can_send、can_init_all
board/drivers/fan.h                   — 风扇控制 (fan_set_power, fan_tick)
board/drivers/gpio.h                  — GPIO 控制
board/drivers/clock_source.h          — 时钟源定时器
board/drivers/simple_watchdog.h       — 看门狗
board/drivers/bootkick.h              — SOM 启动/复位状态机 (B2)
board/drivers/harness.h               — Harness 检测/继电器 (B5)
board/drivers/fdcan.h                 — FDCAN 高层驱动 (C3)
board/drivers/spi.h                   — SPI 协议层 (C3)
board/drivers/can_health_pkt.h        — CAN 健康统计更新 (B4)
board/crc.h                           — CRC-8 校验 (C1)
board/libc.h                          — memcpy, memset, delay
board/stm32h7/lladc_declarations.h    — ADC 信号类型声明
board/stm32h7/llfdcan.h               — FDCAN 寄存器级驱动 (C3)
board/stm32h7/llfdcan_declarations.h  — FDCAN 寄存器声明 (C2)
board/provision.h                     — 设备 Provision 读取
board/boards/board_declarations.h     — board 结构体、HW_TYPE_* 常量
board/boards/cuatro.h                 — Cuatro 板级实现 (P2)
board/boards/tres.h                   — Tres 板级实现 (P2)
board/boards/red.h                    — Red panda 板级实现 (P2)
board/boards/unused_funcs.h           — 未使用功能的空桩实现
```

### 未进入覆盖率的文件：四大原因

```
┌─ board/ 全部 C/H 文件 (~90 个)
│
├── ✅ 已编译为真实代码 (25 个) → 上面列出
│
├── ⚠️ 被 e2e 桩替换 (14 个) → 第一节
│   └── 生产代码未经编译，覆盖率 0%
│
├── ❌ 被 stm32h7_config.h 桩切断 (13 个) → 第二节
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

> C3 完成后，fdcan.h / llfdcan.h / spi.h / crc.h / can_health_pkt.h / provision.h 共 6 个文件新进入覆盖率。文件数从 29 增至 34，总行数从 1783 增至 2160。

| 源文件 | 行覆盖 | 未覆盖原因 |
|--------|--------|-----------|
| `board/main_comms.h` | 95.5% (257/269) | 仅 default handler print + ALLOW_DEBUG 条件未覆盖 |
| `board/main.c` | 64.2% (145/226) | 主循环 main()/LED fade 不可达；debug_ring_callback / enable_fpu 硬件依赖 |
| `board/can_comms.h` | 100% (76/76) | ✅ Phase D.3 已完成 |
| `board/config.h` | 100% (4/4) | ✅ Phase D.1 已完成 |
| `board/crc.h` | 100% (17/17) | ✅ C1 已完成 |
| `board/can.h` | 100% (1/1) | 全部覆盖 |
| `board/provision.h` | 100% (8/8) | 全部覆盖 |
| `board/utils.h` | 100% (10/10) | 全部覆盖 |
| `board/sys/sys.h` | 100% (6/6) | 全部覆盖 |
| `board/drivers/can_common.h` | 100% (107/107) | ✅ N4 已完成 |
| `board/drivers/fan.h` | 100% (27/27) | ✅ P8 已完成 |
| `board/drivers/simple_watchdog.h` | 100% (14/14) | ✅ P3 已完成 |
| `board/drivers/clock_source.h` | 100% (40/40) | ✅ N1 已完成 |
| `board/drivers/registers.h` | 97.8% (44/45) | 仅 1 行未覆盖 (hash collision fallback) |
| `board/drivers/bootkick.h` | 97.9% (47/48) | ✅ B2 完成 |
| `board/drivers/can_health_pkt.h` | 94.6% (35/37) | ✅ B4 共享文件，2 行未覆盖 |
| `board/drivers/gpio.h` | 84.5% (60/71) | `set_gpio_analog`、`restore_gpio` 部分路径 |
| `board/drivers/drivers.h` | 80.0% (4/5) | 1 行未覆盖 |
| `board/drivers/fdcan.h` | ~97% (~175/181) | ✅ E.4 已完成 |
| `board/drivers/spi.h` | **94.2%** (147/156) | ✅ Phase F.5 已完成 — spi_rx_done + spi_tx_done 全状态机覆盖 (仅 spi_init 8行 + 防御 print 4行未覆盖) |
| `board/libc.h` | 83.9% (52/62) | delay + assert_fatal(false) 不可覆盖 |
| `board/sys/faults.h` | 100% (20/20) | ✅ N3 已完成 |
| `board/sys/power_saving.h` | 96.7% (89/92) | ✅ B1 完成 |
| `board/boards/board_declarations.h` | 83.3% (5/6) | 1 行未覆盖 |
| `board/boards/cuatro.h` | 83.3% (55/66) | GPIO 配置路径部分未调用 |
| `board/boards/tres.h` | 88.0% (81/92) | GPIO 配置路径部分未调用 |
| `board/boards/red.h` | 90.0% (63/70) | GPIO 配置路径部分未调用 |
| `board/boards/unused_funcs.h` | 100% (23/23) | ✅ Phase D.2 已完成 |
| `board/stm32h7/llfdcan.h` | 83.2% (134/161) | ✅ C3 完成，部分 LL 路径未触发 |
| `board/stm32h7/llfdcan_declarations.h` | 91.3% (21/23) | ✅ C2 完成，2 行未覆盖 |
| `e2e-tests/.../fdcan_regs.h` | 94.1% (160/170) | e2e 测试桩 |
| `e2e-tests/.../board/stm32h7/board.h` | 100% (41/41) | e2e 测试桩 |
| `e2e-tests/.../board/stm32h7/lladc.h` | 88.9% (8/9) | e2e 测试桩 |
| `e2e-tests/.../board/drivers/spi.h` | 0.0% (0/3) | 🟢 SPI stub — 随 spi.h 测试一起覆盖 |

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
| `board/drivers/fdcan.h` | ✅ **C3 + E.4 已完成 — 真实生产代码直接编译 + can_rx() 全路径覆盖** | — | `can_init()`, `can_rx()`, `process_can()` 等；~97% 覆盖 |
| `board/drivers/usb.h` | 空桩 | 无真实 USB OTG | `usb_init()`, `usb_irqhandler()` |
| `board/drivers/spi.h` | ✅ **C3 已完成 — 真实生产代码直接编译** | — | `spi_version_packet()`, `spi_rx_done()` 等；13.5% 覆盖 |
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

> **关于 `board/drivers/fdcan.h`**：✅ C3 已于 2026-07-27 完成去桩化，真实 `fdcan.h` + `llfdcan.h` 直接编译进入覆盖率（共 316 行），`fdcan_e2e.gen.c` 及生成脚本已删除。

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

#### C3 — `llfdcan.h` + `fdcan.h` 真实代码纳入 ✅ 已完成

**文件**: `board/stm32h7/llfdcan.h`（242 行）+ `board/drivers/fdcan.h`（249 行），共 491 行

**实施**: 
1. `llfdcan.h`：2 处 `#ifdef E2E_TEST` — CCE 自动清除 + 指针安全 RAM 刷新
2. `fdcan.h`：4 处 `#ifdef E2E_TEST` — `cans[]` 数组、10Hz 速率限制、FDCAN FIFO 指针算术
3. `llfdcan_declarations.h`：`#ifndef E2E_TEST` 守卫 `FDCAN_START_ADDRESS`
4. e2e `interrupts.h`：真实 `REGISTER_INTERRUPT`（非 no-op 桩）
5. e2e `fdcan_regs.h`：新增 TXFQS、TXBAR、RXF0S、IR_RF0N、IR_TFE 寄存器位 + `canfd_fifo` 类型
6. `libpanda.c`：移除 `fdcan_e2e.gen.c`，改为直接 `#include` 真实 `llfdcan.h`；`NUM_INTERRUPTS` 16→161；`interrupts[]` 完整类型
7. `jna_can_send` 校验后设 checksum（`process_can` 需要）
8. `can_common.h`：移除 `#ifndef E2E_TEST` 守卫（`process_can` 无条件执行，守卫已不再需要）

**收益**: 491 行真实代码进入覆盖率，消除 `fdcan_e2e.gen.c` 及其生成脚本，消除 e2e 桩 `fdcan.h`

**新增测试**: `fdcan_interrupt.feature`（2 场景）— `process_can` TXBAR/TXFQS 寄存器验证 + 0xff 守卫
**更新测试**: `can_fd_non_iso.feature`（+1 步骤）— FDCAN 中断注册验证
**删除测试**: `can_comms.feature` 2 场景（cross-chunk read + checksum — 非端到端）
**删除测试**: `can_comms_reset.feature` 1 场景（buffer state — 非端到端）

---

### 预估总收益

```
✅ B1 完成:       power_saving.h 进入覆盖率 (96.7%), 综合 81.6%
✅ B2 完成:       bootkick.h 进入覆盖率 (97.9%), 综合 82.2%
✅ B4 完成:       can_health_pkt.h 共享文件 (94.6%), 消除 1 个 gen 文件
✅ B5 完成:       harness.h 去桩化 → 107 行进入覆盖率, 消除 3 文件, 综合 90.0%
✅ C1 完成:       crc.h 去桩化 → 17 行 + spi_version_packet, 消除 1 个空桩
✅ C2 完成:       llfdcan_declarations.h → 23 行真实宏, 消除 fdcan_regs.h 内联重复
✅ C3 完成:       llfdcan.h + fdcan.h → 316 行真实代码进入覆盖率, 消除 fdcan_e2e.gen.c + e2e 桩 fdcan.h
   → Phase D 后基线: 80.5% (1738/2160), 34 files (+33 行, can_comms.h → 100%)
```

---

## 十、`libpanda.c` 桩库存与去桩化机会

### 当前状态：哪些已是真实代码，哪些还是桩

```
libpanda.c (精简后) 编译模型:
  #include "board/main.c"                    ← ✅ 完整固件 (main.c 内 include 真实 fdcan.h, power_saving.h, spi.h)
  #include "board/drivers/fan.h"             ← ✅ 真实代码 (100% 覆盖)
  #include "board/drivers/clock_source.h"    ← ✅ 真实代码 (100% 覆盖)
  #include "board/drivers/simple_watchdog.h" ← ✅ 真实代码 (100% 覆盖)
  #include "board/libc.h"                    ← ✅ 真实代码 (83.9% 覆盖)
  #include "board/drivers/registers.h"       ← ✅ 真实代码 (97.8% 覆盖)
  #include "board/sys/faults.h"              ← ✅ 真实代码 (100% 覆盖)
  #include "board/drivers/harness.h"         ← ✅ 真实代码 (B5 完成)
  #include "board/drivers/fdcan.h"           ← ✅ 真实代码 (C3 + E.4 完成, ~97% 覆盖)
  #include "board/drivers/spi.h"             ← ✅ 真实代码 (C1 通过 spi_version_packet 触发, 13.5% 覆盖)
  #include "board/drivers/can_health_pkt.h"  ← ✅ 真实代码 (B4 共享文件, 94.6% 覆盖)
  #include "board/crc.h"                     ← ✅ 真实代码 (C1 完成, 100% 覆盖)
  #include "board/stm32h7/llfdcan.h"         ← ✅ 真实代码 (C3 完成, 83.2% 覆盖)
  #include "board/stm32h7/llfdcan_declarations.h" ← ✅ 真实代码 (C2 完成, 91.3% 覆盖)
  #include "board/drivers/uart.h"            ← ✅ 真实代码
  #include "boards/board_declarations.h"     ← ✅ 真实代码
  #include "board/boards/{cuatro,tres,red}.h" ← ✅ 真实代码 (83-90% 覆盖)
  #include "board/drivers/gpio.h"            ← ✅ 真实代码 (84.5% 覆盖)
  #include "board/drivers/interrupts.h"      ← ✅ 真实 REGISTER_INTERRUPT (C3)
  #include "board/stm32h7/stm32h7_config.h"  ← ⚠️ e2e 桩 (最小化)
  #include "board/stm32h7/lladc.h"           ← ⚠️ e2e 桩 (拦截 adc_get_mV)
  #include "board/drivers/pwm.h"             ← ⚠️ e2e 桩 (空实现)
  #include "board/drivers/led.h"             ← ⚠️ e2e 桩 (空实现)
  #include "board/drivers/timers.h"          ← ⚠️ e2e 桩 (空实现)
  #include "board/drivers/usb.h"             ← ⚠️ e2e 桩 (空实现)
  #include "board/drivers/fake_siren.h"      ← ⚠️ e2e 桩 (空实现)
```

### 去桩化机会排序

| 优先级 | 桩/Gen 文件 | 替换目标 | 收益 | 障碍 |
|--------|-----------|---------|------|------|
| ✅ B1 | `power_save_e2e.gen.c` + `enter_stop_mode_e2e.gen.c` | `board/sys/power_saving.h` | ✅ 已完成 — 真实代码覆盖率 95.8% | `enter_stop_mode` 为 static (通过文本 include 解决) |
| ✅ B2 | `bootkick_e2e.gen.c` | `board/drivers/bootkick.h` | ✅ 已完成 — 真实代码进入覆盖率 | `static` locals 通过 `#ifdef E2E_TEST` 暴露 |
| ✅ B3 | `fdcan_e2e.gen.c` + e2e 桩 `fdcan.h` | `board/stm32h7/llfdcan.h` + `board/drivers/fdcan.h` | ✅ C3 已完成 — 316 行真实代码，消除 gen 脚本 + 桩文件 | `while()` 轮询 + `cans[]` + `REGISTER_INTERRUPT` |
| ✅ B4 | `can_health_e2e.gen.c` | `board/drivers/can_health_pkt.h` | ✅ 已完成 — 提取为共享文件 | `fdcan.h` 含硬件轮询，仅提取纯业务函数 |
| 🔴 B5 | `harness_detect_e2e.gen.c` + e2e 桩 `harness.h` | `board/drivers/harness.h` | ✅ 已完成 — 107 行真实代码进入覆盖率 + 消除 2 文件 + 1 脚本 | `harness_detect_orientation()` 为 static，`#ifdef E2E_TEST` 暴露 |
| ✅ C1 | e2e 桩 `crc.h` (空文件) | `board/crc.h` | ✅ 已完成 — 20 行纯 CRC-8 算法，消除空桩 + spi_version_packet 测试 | 零障碍 |
| ✅ C2 | — (gen 文件内联宏) | `board/stm32h7/llfdcan_declarations.h` | ✅ 已完成 — 51 行真实宏定义，fdcan_regs.h 消除重复 | 零障碍 |
| ✅ C3 | `fdcan_e2e.gen.c` + e2e 桩 `fdcan.h` | `board/stm32h7/llfdcan.h` + `board/drivers/fdcan.h` | ✅ 已完成 — 215 行真实代码 (81 fdcan + 134 llfdcan)，消除 gen 脚本 + 桩文件 | `while()` 轮询 + `cans[]` + `REGISTER_INTERRUPT` |

---

## 十一、生产代码 `#ifdef E2E_TEST` 使用清单

C3 完成后，生产代码中 `E2E_TEST` 条件编译共涉及 6 个文件，15 处使用：

### `board/drivers/harness.h`（4 处）

| 行 | 守卫 | 用途 |
|----|------|------|
| 5 | `#ifndef` | `harness` 全局变量 — e2e 中由 libpanda.c 定义 |
| 56 | `#ifdef` | `harness_detect_orientation()` static→公开 — 供 e2e JNA 调用 |
| 99 | `#ifndef` | `harness_tick()` 中跳过 `harness_detect_orientation()` 调用 |
| 111 | `#ifndef` | `harness_init()` 中跳过初始方向检测 |

### `board/drivers/fdcan.h`（4 处）

| 行 | 守卫 | 用途 |
|----|------|------|
| 3 | `#ifndef` | `cans[3]` 数组 — e2e 中由 libpanda.c 定义为 `fake_fdcan[]` |
| 24 | `#ifdef` | `can_clear_send()` 跳过 10Hz 速率限制（`microsecond_timer_get` 始终为 0） |
| 63 | `#ifdef` | `process_can()` 中 `TxFIFOSA` 用指针算术替代 `uint32_t` 强转 |
| 140 | `#ifdef` | `can_rx()` 中 `RxFIFO0SA` 用指针算术替代 `uint32_t` 强转 |

### `board/drivers/bootkick.h`（3 处）

| 行 | 守卫 | 用途 |
|----|------|------|
| 7 | `#ifdef` | 提升 `static` 局部变量为文件作用域供 JNA 访问 |
| 18 | `#ifdef` | `#define` 映射 `e2e_*` 变量到原 `static` 局部变量名 |
| 90 | `#ifdef` | `#undef` 清理 |

### `board/stm32h7/llfdcan.h`（2 处）

| 行 | 守卫 | 用途 |
|----|------|------|
| 32 | `#ifdef` | `fdcan_exit_init()` 中同时清除 CCE（模拟硬件自动行为） |
| 194 | `#ifdef` | `llcan_init()` 中 RAM 刷新用指针算术替代 `uint32_t` 强转 |

### `board/stm32h7/llfdcan_declarations.h`（1 处）

| 行 | 守卫 | 用途 |
|----|------|------|
| 16 | `#ifndef` | `FDCAN_START_ADDRESS` — e2e 中由 libpanda.c 重定义为 `fake_fdcan_sram` |

### `board/sys/faults.h`（1 处）

| 行 | 守卫 | 用途 |
|----|------|------|
| 3 | `#ifdef` | 重定义 `PERMANENT_FAULTS` 以测试永久故障路径 |

### 不可去桩化的文件

| 文件 | 理由 |
|------|------|
| `interrupts.h`, `timers.h`, `usb.h`, `led.h`, `pwm.h`, `fake_siren.h` | 纯 STM32 外设初始化，无独立业务逻辑 |
| `stm32h7_config.h` | 中央配置枢纽，必须桩化以切断 CMSIS/HAL 依赖链 |
| `lladc.h` | 必须拦截 `adc_get_mV()` 以注入测试数据 |
| `early_init.h` | 启动流程：`SCB->VTOR`、`jump_to_bootloader()`、`DBGMCU->IDCODE`，无可测业务逻辑 |
| `provision.h` | 已通过 `PROVISION_CHUNK_ADDRESS` override 使用真实代码 |
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

#### ✅ 已完成去桩化（原"有条件 include"）

| 文件 | 行数 | 障碍 | 方案 |
|------|------|------|------|
| `board/stm32h7/llfdcan.h` | 242 | `while()` 硬件轮询 → 死循环 | ✅ C3 已完成 — `#ifdef E2E_TEST` 方案 B（自变异 FDCAN 寄存器） |
| `board/drivers/fdcan.h` | 249 | 依赖 llfdcan.h + `cans[3]` 数组冲突 + `REGISTER_INTERRUPT` | ✅ C3 已完成 — `#ifdef E2E_TEST` 条件编译 |

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
usb.h               — USB OTG 外设初始化
pwm.h, led.h        — PWM/LED 外设初始化
fake_siren.h        — 蜂鸣器 GPIO
interrupts.h        — NVIC 初始化
```

#### 决策矩阵

```
                  直接 include?
         ┌─ 有业务逻辑? ─┬─ 纯 C 算法? ─── ✅ 直接 include (crc.h, llfdcan_declarations.h)
         │               ├─ 有 static? ─── ✅ E2E_TEST 暴露 (harness.h, bootkick.h)
         │               └─ 有 while()? ── ✅ C3 已完成 — #ifdef E2E_TEST (llfdcan.h, fdcan.h)
         └─ 纯外设操作? ─────────────────── ❌ 不可 include
```

---

## 十二、低于 80% 文件提升分析（Phase D 后基线：80.5%，1738/2160）

C3 完成后，7 个文件覆盖率低于 80%。以下按**提升难度 × 收益**排序，给出具体路径。

```
┌─ 文件 ──────────────┬─ 覆盖率 ──┬─ 未覆盖行 ──┬─ 提升难度 ──┐
│ drivers/spi.h        │ 13.5%    │ 135        │ 🔴 高       │
│ drivers/fdcan.h      │ ~97%     │ ~96        │ 🟢 完成     │
│ main.c               │ 64.2%    │ 81         │ 🟡 中       │
│ can_comms.h          │ 56.6%    │ 33         │ 🟢 低       │
│ unused_funcs.h       │ 26.1%    │ 17         │ 🟢 极低     │
│ e2e/.../spi.h (stub) │ 0.0%     │ 3          │ 🟢 极低     │
│ drivers/drivers.h    │ 80.0%    │ 1          │ 🟢 极低     │
└──────────────────────┴───────────┴────────────┴────────────┘
```

### 十二.1 `board/drivers/spi.h` — **94.2%** (147/156) ✅ Phase F.5 已完成 (2026-07-29)

**已覆盖**: `spi_version_packet()` (VERSION), `validate_checksum()` (全场景), `spi_rx_done()` 全状态机 (HEADER + DATA_RX 全 endpoint), `spi_tx_done()` 全状态转换, `can_tx_comms_resume_spi()`。

**spi_rx_done() 状态机 — 全部 ✅**:
```
├── VERSION 匹配 → spi_version_packet()        ← ✅ B9
├── SPI_STATE_HEADER:
│   ├── 有效 sync + checksum → ACK            ← ✅ A1
│   └── 无效 sync/checksum → NACK             ← ✅ A2,A3
├── SPI_STATE_DATA_RX:
│   ├── checksum 无效 → NACK                  ← ✅ B1
│   ├── endpoint 0 (控制传输)                  ← ✅ B10 (有效), B11 (数据不足)
│   ├── endpoint 1/0x81 (CAN read)            ← ✅ B5,B6
│   ├── endpoint 2 (endpoint2 write)          ← ✅ B4
│   ├── endpoint 3 (CAN write)                ← ✅ B7 (ready), B8 (!ready)
│   ├── endpoint 0xAB (test echo)             ← ✅ B2
│   ├── endpoint 0xAC (test NACK)             ← ✅ B3
│   ├── unexpected endpoint                   ← ✅ B12
│   └── RX unexpected state + no response     ← ✅ B13
└── 尾部: NACK/DACK response, error_count     ← ✅ ALL
```

**spi_tx_done() 状态 — 全部 ✅**:
```
├── HEADER_NACK / reset → HEADER              ← ✅ C1,C5
├── HEADER_ACK → DATA_RX                      ← ✅ C2
├── DATA_TX → HEADER                          ← ✅ C3
└── 意外状态 → HEADER + print                 ← ✅ C4
```

**未覆盖 (9 行, 5.8%)**: `spi_init()` (8行, 硬件 DMA 初始化) + CAN read/write 防御性 print (2行)。

**实施要点**:
1. `libpanda.c`: 新增 10 个 JNA 函数（`jna_spi_get/set_state`, `jna_spi_write_rx_buf`, `jna_spi_read_tx_buf`, `jna_spi_rx_done`, `jna_spi_tx_done`, `jna_spi_get/reset_error_count`, `jna_spi_get/set_can_tx_ready`）
2. `PandaClient.java`: 新增 `SpiStateResult` (state + errorCount + rx(SpiRxDetail)) DTO
3. `PandaSteps.java`: 新增 10 个 When 步骤
4. `spi_state_machine.feature`: 21 个场景，覆盖 spi_rx_done 13 个 + spi_tx_done 5 个 + 边界 3 个

---

### 十二.2 `board/drivers/fdcan.h` — ✅ ~97% (~175/181) — Phase E.4 已完成 (2026-07-29)

**已覆盖**: `can_set_speed()`、`can_init()`、`process_can()`（TX 中断路径）、`can_clear_send()`、`can_rx()` 全路径。

**新增 8 个场景**（`fdcan_interrupt.feature` 第 3-10 场景）覆盖 `can_rx()` 所有核心路径：

| 场景 | 验证点 |
|------|--------|
| 标准 CAN 帧 | 11-bit 地址 → `rxQueue[0].returned=false, rejected=false, bus=0` + `totalRxCnt=1` |
| 扩展 CAN 帧 | 29-bit 地址 → `rxQueue[0].extended=true` |
| CAN-FD 自动检测 | `canfd_frame=1` → `bus_config[].canfd_enabled` 自动设 true |
| BRS 自动检测 | `brs_frame=1` → `bus_config[].brs_enabled` 自动设 true |
| FIFO 满覆盖模式 | F0F=1 → `rx_fifo_idx` 偏移 +1, `totalRxLostCnt++`, `RXF0A=1` |
| CAN 转发 | `forwarding_bus=1` → `total_fwd_cnt++` |
| IRQ 错误处理 | PED + PEA → `update_can_health_pkt()` |
| safety_rx_hook 拒绝 | TOYOTA 模式 + panda XOR ≠ Toyota sum → `safety_rx_invalid=1` |

**未覆盖**: `body_can_rx()` (3 行, 仅 PANDA_BODY 固件) 和 `can_rx()` 中 `safety_rx_hook` 返回 false 路径 (1 行, 需 vehicle-specific safety mode + wrong checksum)。

**实施要点**:
1. `libpanda.c`: 新增 14 个 JNA 函数（`jna_fdcan_write_rx_fifo`、`jna_set_fdcan_rxf0s/ir`、`jna_get_can_health_total_rx_cnt/fwd_cnt`、`jna_set_bus_forwarding_bus`、`jna_reset_bus_config` 等）
2. `fdcan.h`: 新增 1 处 `#ifdef E2E_TEST`（line 214, 手动清除 RXF0S 防止死循环）
3. `PandaClient.java`: CanMessage 新增 `extended`/`fd` 字段；新增 DAL 属性 `isCanfdEnabled0/isBrsEnabled0/getFdcanRxf0aBus0`
4. `PandaSteps.java`: 新增 `CanRxInjectRequest` + 6 个 When 步骤
5. 场景总数从 2 → 10（+8）

---

### 十二.3 `board/can_comms.h` — 56.6% (43/76) → ✅ 100% (Phase D.3 已完成)

**已覆盖**: 正常 CAN 包的 `comms_can_read` 和 `comms_can_write` 路径（单次传输能装下完整包）。

**未覆盖**: overflow buffer 分片路径。当 CAN 包跨多个 USB/SPI 传输分片时触发。

```
comms_can_read() 分片路径 (16 行未覆盖):
├── 前次分片有剩余 (can_read_buffer.ptr > 0)     ← ❌
│   └── 复制 overflow 到输出 → 缩短 buffer
└── 当前包超出 max_len                        ← ❌
    └── 复制部分到输出 → 剩余存入 can_read_buffer

comms_can_write() 分片路径 (26 行未覆盖):
├── 前次分片有剩余 (can_write_buffer.ptr != 0)   ← ❌
│   ├── 本次数据足够完成包 → 组装 + can_send
│   └── 本次数据不够 → 追加到 buffer
└── 当前包超出本次 len                        ← ❌
    └── 复制部分到 can_write_buffer → 记录 tail_size
```

**提升方案**: 构造跨分片的 CAN 包场景。
- `comms_can_read`: 先调用一次 `comms_can_read` 读取部分数据（触发 buffer 暂存），再调用一次读出剩余
- `comms_can_write`: 先写入部分数据触发 buffer 暂存，再写入剩余部分触发组装和 `can_send`

**预估收益**: +33 行（覆盖率 +1.5%），低投入高回报。

**实施** (2026-07-28): 
- `libpanda.c`: 新增 `jna_comms_can_reset()` 确保场景间缓冲区状态干净
- `PandaClient.java` + `PandaSteps.java`: 暴露 JNA 绑定 + 步骤定义
- `can_comms.feature`: 新增 5 个 overflow buffer 场景
  - `comms_can_read` overflow: 单帧分片读取 (2 场景)
  - `comms_can_write` overflow: 帧分片写入完成/未完成/多帧尾部 (3 场景)
- 所有场景都有 When 操作触发溢出 → Then 验证 buffer 状态 (ptr/tail) + 帧完整性
- 场景数: 203 (+6 vs 基线 197)

---

### 十二.4 `board/main.c` — 64.2% (145/226) 🟡 中等难度

**已覆盖**: `set_safety_mode()`、`is_car_safety_mode()`、`tick_handler()`（8Hz 定时器中断处理）。

**未覆盖分析**:

```
debug_ring_callback() (6 行)      ← UART 调试回环，非关键
__initialize_hardware_early() (3) ← 硬件早期初始化，依赖 SCB->VTOR
enable_fpu() (4 行)               ← FPU 使能，纯寄存器操作
main() 函数 (120 行):
  ├── 初始化序列 (272-340)       ← 几乎不可测：clock_init、peripherals_init、
  │                                  detect_board_type、usb_init、spi_init 等
  ├── LED 呼吸循环 (354-366)     ← 可测：需 mock delay()
  └── 电源管理 (376-385)         ← 不可测：依赖 enter_stop_mode() + __WFI()
```

**实际可提升**: 有限。`main()` 初始化序列是纯硬件依赖，不适合 e2e。LED 呼吸循环理论上可测但需要 mock `delay()`（当前 `delay()` 在 e2e 中是 busy loop）。`debug_ring_callback` 需要 UART 数据注入。

**推荐**: 将这部分标记为「硬件依赖，不可在 e2e 中覆盖」，不要投入时间。

---

### 十二.5 `board/boards/unused_funcs.h` — 26.1% (6/23) → ✅ 100% (Phase D.2 已完成)

**已覆盖**: `unused_set_bootkick()`（通过 red board 调用）、`unused_set_amp_enabled()`（通过 red board 调用）。

**新增覆盖** (2026-07-28): RED e2e_board 的 `set_ir_power`/`set_fan_enabled`/`set_siren`/`read_current_mA`/`read_som_gpio` 从 stub 改为真正的 `unused_*` 函数（匹配生产 `red.h`）。TRES 的 `read_current_mA` 改为 `unused_read_current`。cuatro/tres 的 `set_fan_enabled` 改为生产函数，`board_set_fan_enabled_stub` 已删除。

| 函数 | 板 | 触发路径 |
|------|----|---------|
| `unused_set_ir_power()` | red | 0xb0 → `current_board->set_ir_power` |
| `unused_set_fan_enabled()` | red | ⚠️ `fan_tick` 跳过 (`has_fan=false`)；JNA 通过 `current_board->set_fan_enabled()` 调用 |
| `unused_set_siren()` | red | `tick_handler` → `current_board->set_siren` |
| `unused_read_current()` | red, tres | 0xd2 → `get_health_pkt` → `read_current_mA` |
| `unused_read_som_gpio()` | red | 0xc6 → `current_board->read_som_gpio` |

**实施**:
- `libpanda.c`: RED e2e_board 5 个函数指针从 stub 改为 `unused_*`；cuatro/tres `set_fan_enabled` 改为生产函数；删除 `board_set_fan_enabled_stub`
- 场景分散到对应 feature: `fan_power.feature` (+4), `health.feature` (+2), `som_gpio.feature` (+1), `ir_power.feature` (+1), `siren.feature` (+1)
- 所有场景都有 Given 注入非零值 → Then 验证 unused 覆盖了它（避免 false-positive）

---

### 十二.6 `board/config.h` — 75.0% → ✅ 100% (Phase D.1 已完成)

唯一的未覆盖行: `#define CAN_INIT_TIMEOUT_MS 500U`（第 13 行）。通过新增 `jna_get_can_init_timeout_ms()` JNA getter + `packet_versions.feature` 验证步骤覆盖。

**实施**: 
- `libpanda.c`: 新增 `int jna_get_can_init_timeout_ms(void) { return CAN_INIT_TIMEOUT_MS; }`
- `PandaClient.java`: JNA 接口声明 + `getCanInitTimeoutMs()` getter
- `packet_versions.feature`: 新增 `canInitTimeoutMs: 500` 验证

---

### 十二.7 `e2e-tests/.../spi.h` + `board/drivers/drivers.h` 🟢 极低难度

- `e2e/.../spi.h`: 3 行 stub，随 §十二.1 的 SPI 测试一起覆盖
- `board/drivers/drivers.h`: 1 行未覆盖（80.0%），低优先级

---

### 推荐实施顺序

```
Phase D — 快速提升 (实际 +33 行 / +1.6%) — ✅ 全部完成
  1. config.h: 引用 CAN_INIT_TIMEOUT_MS ✅ 已完成 (2026-07-28)
  2. unused_funcs.h: 在 @tres/@red 场景中调用空桩函数 ✅ 已完成 (2026-07-28)
  3. can_comms.h: overflow buffer 分片场景 ✅ 已完成 (2026-07-28)

Phase E — 核心提升 (预计 +74 行 / +3.4%)
  4. fdcan.h: can_rx() 完整路径（RX FIFO 模拟 + 多场景）✅ 已完成 (2026-07-29, +8 场景, ~96 行)

Phase F — 远期 (实际 +251 行 / +7.2%)
  5. spi.h: SPI 状态机测试 (需模拟 DMA 回调) ✅ 已完成 (2026-07-29, +21 场景, ~126 行)
     → spi_rx_done 全路径 (13 场景): HEADER ACK/NACK, VERSION, DATA_RX 全 endpoint (0/1/2/3/0x81/0xAB/0xAC)
     → spi_tx_done 全状态 (5 场景): HEADER_NACK→HEADER, HEADER_ACK→DATA_RX, DATA_TX→HEADER, reset, unexpected
     → 额外覆盖 (3 场景): RX unexpected state, no response fallback, unexpected endpoint

不可提升:
  6. main.c: debug_ring_callback + main() 初始化 — 硬件依赖
```

```
Phase D 后基线:   80.5% (1738/2160)
Phase E 完成后:  ~83.9% (~1814/2160) ✅
Phase F 完成后:  91.1% (1989/2183) ✅
```

---

## 十三、e2e 测试设计审视：非端到端功能测试与合并机会

> 分析时间: 2026-07-29
> 涵盖: 全部 52 个 feature 文件
> 目标: 识别被测对象不是完整端到端工作流的测试，评估通过修改其它已有测试来覆盖的可行性

### 评判标准

一个测试被认为是"非端到端"的，当满足以下条件之一：
1. **单一数据读取 handler**：仅测试一个控制请求返回预设值，无业务流程
2. **内部实现细节**：测试数据结构内部操作或初始化函数，无用户可见行为流
3. **单一控制写入 handler**：仅测试一个简单参数写入 + 寄存器变化的控制请求
4. **纯重复覆盖**：被测功能已被另一个 feature 的完全相同的 scenario 覆盖

### 总览

> ✅ **更新 (2026-07-29):** 第 1+2 梯队已完成合并，C1 已完成合并。以下 11 个文件已删除/合并，剩余 9 个待处理（第 3+4 梯队）。

```
非端到端 / 可通过其他测试覆盖的：20 个 feature 文件 → 11 个已合并 ✅
──────────────────────────────────────────
纯重复：           1 个 → ✅ 已删除 (microsecond_timer)
单一数据读取：     8 个 → ✅ B1-B5 已合并 (5), B6-B8 待处理 (3)
内部实现细节：     6 个 → ✅ C1 已合并 (1), C2-C6 待处理 (5)
单一控制写入：     5 个 → ✅ D1-D2, D4-D5 已合并 (4), D3 待处理 (1)

仍为真正端到端功能：32 个（不变）
当前 feature 总数: 42 个 (52 → 42, 净减 10)
```

### 详细清单

#### 类别 A：纯重复 ✅ 可安全删除

| # | Feature 文件 | 被测对象 | 覆盖分析 | 合并目标 | 方案 |
|---|-------------|---------|---------|---------|------|
| A1 | `microsecond_timer.feature` | `get_microsecond_timer()` | 与 `timer_fan.feature` 中两个 scenario 完全一致（非零 timer + 零 timer） | `timer_fan.feature` | ✅ 已删除 |

#### 类别 B：单一数据读取 handler — 可合并到相关 feature

这些 feature 仅通过 control write 调用一个 USB endpoint，验证 `respBuffer` 返回值。无业务流程、无状态转换、无副作用。

| # | Feature 文件 | 被测 handler | 合并目标 | 合并方式 |
|---|-------------|-------------|---------|---------|
| B1 | `hw_type.feature` | `get_hw_type()` (0xc1) | `spi_version_packet.feature` | ✅ 已合并。SPI 版本包中 `bytes[21]` 已是 `hw_type = CUATRO`，现有 scenario 已覆盖 |
| B2 | `get_version.feature` | `get_version()` (0xd6) | `health.feature` | ✅ 已合并。在 `health.feature` 中添加 get_version scenario |
| B3 | `mcu_uid.feature` | `get_mcu_uid()` (0xc3) | `spi_version_packet.feature` | ✅ 已合并。SPI 版本包中 `bytes[9-20]` 已是 12 字节 UID，现有 scenario 已覆盖 |
| B4 | `packet_versions.feature` | `get_packet_versions()` (0xdd) | `health.feature` | ✅ 已合并。在 `health.feature` 中添加 packet_versions scenario |
| B5 | `serial.feature` | serial/provision (0xd0) | `spi_version_packet.feature` | ✅ 已合并。SPI 版本包已包含设备标识信息，现有 scenario 已覆盖 |
| B6 | `interrupt_rate.feature` | `get_interrupt_rate()` (0xc4) | `fdcan_interrupt.feature` | 该 feature 已涉及 FDCAN 中断注册 + 速率校验，可在现有 scenario 中追加 `get_interrupt_rate` 调用 |
| B7 | `signature.feature` | 签名分块 (0xd3/0xd4) | `health.feature` 或新建启动校验 scenario | 2 个单一 control write → respBuffer 校验，可在一个 scenario 中连续调用两个 endpoint |
| B8 | `uart_read.feature` | UART 读取 (0xe0) | `endpoint2_write.feature` | endpoint2 ring 4 写入 → UART buffer，写后立即读回，在同一个 scenario 中验证 |

#### 类别 C：内部实现细节 — 可合并到相关 feature

这些 feature 测试的是内部数据结构操作或初始化函数，通过 JNA 直接操控底层状态而非通过固件 USB/SPI 命令。

| # | Feature 文件 | 被测对象 | 问题本质 | 合并目标 | 合并方式 |
|---|-------------|---------|---------|---------|---------|
| C1 | `can_queue_wrap.feature` | `can_push`/`can_pop`/`can_slots_empty` 指针回绕 | 通过 JNA 直接设 `w_ptr`/`r_ptr` 测试 `can_common.h` 内部循环缓冲区。是数据结构单元测试 | `can_comms.feature` | ✅ 已合并。5 个 wrap-around scenario 已追加到 `can_comms.feature:293-379`，`can_queue_wrap.feature` 已删除。`can_common.h` 保持 100%（107/107）覆盖 |
| C2 | `clock_source_init.feature` | `clock_source_init()` | 测试 TIM1/TIM8 寄存器初始化 + GPIO alternate function。固件启动时的纯初始化函数，从未被用户命令触发 | `clock_source.feature` | 在 `clock_source.feature` 现有 scenario 中添加对 `clockSourceInit` 初始寄存器值的校验 |
| C3 | `board_init.feature` | `board_xxx_init()` GPIO 配置 | 测试启动时的 GPIO MODER/OTYPER/PUPDR 寄存器写入。按板型分别测试，无用户交互 | 其他按 board 标注的 feature | 在 `power_save.feature`、`can_mode.feature`、`deep_sleep.feature` 等已有 `@cuatro`/`@tres`/`@red` scenario 中添加 `boardInit` 字段校验 |
| C4 | `register_divergence.feature` | `check_registers()` 内部故障检测 | 通过 JNA 注射 `registerDivergent` 直接触发 fault。是内部自检函数，可通过常规 tick 流程覆盖 | `tick_paths.feature` | 在 `tick_paths.feature` 中添加 register divergent 触发的 scenario（已有 heartbeat counter、safety_mode_cnt 等同类场景） |
| C5 | `watchdog.feature` | `simple_watchdog_kick()` 心跳看门狗 | 通过 `ControlSetup.timerValue` 直接注入时间差距触发 fault。纯内部故障检测 | `tick_paths.feature` | 在 `tick_paths.feature` 中添加 watchdog 触发的 scenario |
| C6 | `endpoint2_write.feature` | `comms_endpoint2_write()` | 测试 SPI endpoint 2 数据写入 debug/buffer。SPI 协议内部实现 | `spi_state_machine.feature` | 该 feature 已覆盖 endpoint 2 的 DATA_RX 路径（`DATA_RX endpoint 2 — endpoint2 write → DACK`），在同一 scenario 中增加写入数据的校验 |

#### 类别 D：单一控制写入 handler — 可合并到相关 feature

这些 feature 测试的 handler 逻辑极简（写入一个值 / 翻转一个标志 / 触发一次操作），可与相关的更复杂的 feature 合并。

| # | Feature 文件 | 被测 handler | 合并目标 | 合并方式 |
|---|-------------|-------------|---------|---------|
| D1 | `can_fd_non_iso.feature` | `set_can_fd_non_iso()` (0xfc) | `can_fd_data_bitrate.feature` | ✅ 已合并。所有 3 个 scenario 已追加到 can_fd_data_bitrate.feature |
| D2 | `can_fd_auto.feature` | `set_can_fd_auto()` (0xe8) | `can_fd_data_bitrate.feature` | ✅ 已合并。所有 3 个 scenario 已追加到 can_fd_data_bitrate.feature |
| D3 | `can_comms_reset.feature` | `reset_can_comms()` (0xc0) | `safety_mode.feature` | `safety_mode.feature` 已有"切换安全模式清空队列"的 scenario（第 7 个），在其中增加 `reset_can_comms` 后状态校验 |
| D4 | `reset_st.feature` | NVIC 系统复位 (0xd8) | `bootloader.feature` | ✅ 已合并为 `system_reset_bootloader.feature` (4 个 scenario) |
| D5 | `bootloader.feature` | `enter_bootloader_mode()` (0xd1) | 扩展后的 `reset_st.feature` | ✅ 已合并为 `system_reset_bootloader.feature` (4 个 scenario) |

### 仍为真正端到端功能的 32 个测试

以下 feature 测试的是完整的多步骤端到端工作流，**不应合并**：

| 分类 | Feature | 端到端流程 |
|------|---------|-----------|
| **CAN 通信协议** | `can_comms` | USB ep3 out → deserialize → process_can → rxQueue → serialize → USB ep1 in（完整编解码管道） |
| | `can_loopback` | loopback enable → CAN send → echo rxQueue → FDCAN 寄存器验证 |
| | `can_ring_clear` | 预填充队列 → clear 命令 → 验证队列空 |
| | `can_health` | preset PSR/ECR → control write → 验证 canHealth 提取逻辑 |
| **CAN 配置** | `can_bitrate` | set bitrate → can_init → FDCAN 寄存器全量验证 |
| | `can_fd_data_bitrate` | set FD bitrate → canfd_enabled/brs_enabled + FDCAN dbtp 寄存器 |
| | `can_mode` | set OBD_CAN2/NORMAL → GPIO MODER/ODR 按板验证 |
| **安全模式** | `safety_mode` | 多模式切换 → CAN send → rejected/allowed → relay + FDCAN 寄存器 |
| **心跳超时** | `heartbeat_loss` | 多 tick 累积 → controls_allowed 撤销 → SILENT → siren/IR/fan |
| | `heartbeat` | 心跳 engaged/disabled 状态转换 + car_safety 禁止 disable |
| **电源管理** | `power_save` | enable/disable → CAN IRQ/transceiver/IR → 按板 GPIO + 翻转线束 |
| | `deep_sleep` | deep sleep request → enter_stop_mode → GPIO MODER/EXIT/PWR/SCB 全套寄存器 |
| | `wfi_idle` | power_save enabled → WFI 空闲路径 → 按板 + SOM GPIO 条件 |
| **SPI 协议** | `spi_state_machine` | HEADER→DATA_RX→DATA_TX→HEADER 全状态机 |
| | `spi_version_packet` | VERSION 匹配 → spi_version_packet → CRC-8 + UID + hw_type + PID |
| **故障处理** | `permanent_fault` | trigger → fault_status PERMANENT → recover 不可清除 → 幂等 |
| | `relay_malfunction` | tick_handler → relay_malfunction edge → fault 触发/恢复 |
| **CAN 中断** | `fdcan_interrupt` | can_send → process_can → TXBAR; can_rx → RX FIFO → rxQueue; IRQ 错误 |
| **设备控制** | `relay` | multi-param → GPIOA ODR → relay A/B/AB/off + 高位忽略 |
| | `siren` | set_siren → tick → GPIOB ODR bit14 + red no-op |
| | `ir_power` | set_ir_power → irPwm → red no-op |
| | `fan_power` | set_fan_power → 钳位 → GPIO D ODR 按板型 + 0 功率 cooldown |
| | `fan_cooldown` | set_fan_power 0 → 多 tick → cooldown_counter 递减至 0 |
| **tick 流程** | `tick_paths` | has_fan false 跳过 / heartbeat_counter UINT32_MAX 封顶 / safety_mode_cnt 溢出回绕 / harness reinit |
| | `ignition_can` | preset ignition_can → 多 tick → 超时后自动清零 |
| **硬件检测** | `harness_detect` | preset SBU voltage → detect_orientation → NORMAL/FLIPPED/NC + relay_driven 跳过 |
| | `som_gpio` | preset somGpio → read endpoint → 按板返回 1/0 |
| **启动流程** | `bootkick` | ignition edge → BOOT_BOOTKICK → 20 tick 等待 → BOOT_RESET → GPIO 按板 |
| **其他** | `alternative_experience` | set value → car_safety 阻止 → 边界值（0 / 32767） |
| | `clock_source` | set params → TIM register 分解（ccr1/ccr2/ccr3/arr/ccr4）+ 边界（0 / max） |
| | `timer_fan` | get_microsecond_timer + get_fan_rpm（两个相关 endpoint 在同一 feature） |

### 合并后的预期效果

```
当前:  52 个 feature 文件
合并后: ~37 个 feature 文件（减少 ~15 个）

减少类型:
  A 纯重复:         1 个
  B 数据读取合并:   8 个 → 减少 8 个独立文件（内容分散到 5 个目标文件）
  C 内部实现合并:   6 个 → 减少 6 个独立文件（内容分散到 5 个目标文件）
  D 控制写入合并:   5 个 → 减少 5 个独立文件（内容分散到 3 个目标文件）
                     ↑ 有重叠合并目标，实际减少可能略少

场景总数保持: 所有被合并的 scenario 内容变为目标文件的新 scenario，
              测试覆盖不丢失，仅组织方式变化。
```

### 优先级建议

> ✅ **第 1+2 梯队已完成** (2026-07-29): 删除 microsecond_timer.feature; 合并 reset_st+bootloader → system_reset_bootloader.feature; 合并 can_fd_non_iso+can_fd_auto → can_fd_data_bitrate.feature; 合并 hw_type+mcu_uid+serial → spi_version_packet.feature (已隐式覆盖); 合并 get_version+packet_versions → health.feature

```
🟢 第 1 梯队 (立即执行，无风险): ✅ 已完成
   A1: microsecond_timer.feature → 已删除

🟡 第 2 梯队 (低风险，高收益): ✅ 已完成
   D4+D5: reset_st + bootloader → 已合并为 system_reset_bootloader.feature
   D1+D2: can_fd_non_iso + can_fd_auto → 已合并到 can_fd_data_bitrate.feature
   B1+B3+B5: hw_type + mcu_uid + serial → 已合并到 spi_version_packet.feature
   B2+B4: get_version + packet_versions → 已合并到 health.feature

🟠 第 3 梯队 (中等风险，需设计 scenario):
   ✅ C1: can_queue_wrap → 已合并到 can_comms (5 scenarios, can_common.h 100% 覆盖)
   ✅ C4+C5: register_divergence + watchdog → 已合并到 tick_paths (6 scenarios)
   ✅ C2: clock_source_init → 已合并到 clock_source (6 scenarios)
   ✅ C6: endpoint2_write → 已合并到 spi_state_machine (6 scenarios)
   ✅ D3: can_comms_reset → 已合并到 safety_mode (2 scenarios)
   ✅ B7: signature → 已合并到 health (2 scenarios)
   ✅ B6: interrupt_rate → 已合并到 fdcan_interrupt (3 scenarios)
   ✅ 第 3 梯队全部完成 (2026-07-29), feature 文件从 42 → 35
   
   📊 合并后覆盖率: 1985/2183 lines (90.9%), 与合并前完全一致

🔴 第 4 梯队 (高风险/争议大，暂缓):
   C3: board_init → 分散到其他按板 feature
   B8: uart_read → 合并到 endpoint2_write（但 endpoint2_write 自身也可能被合并）
```

---

## 第十四节：非端到端 When 步骤分析

> 分析时间: 2026-07-29
> 范围: `e2e-tests/src/test/resources/features/` 下 35 个 feature 文件

### 分析标准

**端到端 (E2E)**: When 步骤通过固件的公开 API 执行 — USB 控制/批量传输、CAN 发送/接收、tick_handler 调用、SPI 协议交互

**非端到端 (非 E2E)**: When 步骤直接调用内部 C 函数 (JNA)、操作内部数据结构、操作模拟硬件寄存器

### 🔴 完全非端到端 feature (4 个)

| Feature | When 步骤 | 内部机制 | 场景数 | 可被哪些 E2E 覆盖 |
|---------|----------|---------|--------|------------------|
| `board_init.feature` | `When board init` | JNA 直接调用 `current_board->init()` | 7 | `panda_init()` 在 dylib 加载时自动调用，所有 feature 的 Background 即触发。GPIO 副作用被 `power_save`、`can_mode` 等验证，但寄存器初始值无独立 E2E 场景 |
| `harness_detect.feature` | `When detect harness orientation` | JNA 直接调用 `harness_detect_orientation()` | 8 | `tick_handler()` 8Hz 中调用 `harness_detect_orientation()`，`tick_paths.feature` 的 harness reinit 场景 + `heartbeat_loss.feature` 的 `When call tick handler N times` 覆盖同一代码路径 |
| `permanent_fault.feature` | `When trigger fault N`<br>`When recover fault N` | JNA 直接调用 `fault_occurred()` / `fault_recovered()` | 2 | `trigger fault`: `relay_malfunction.feature` (tick→relay edge)、`tick_paths.feature` C4 (check_registers)、C5 (watchdog) 均通过 tick_handler 触发 `fault_occurred()`<br>`recover fault`: **无法被 E2E 覆盖** — `fault_recovered()` 无公开 API |
| `wfi_idle.feature` | `When process wfi idle` | JNA 直接调用 WFI 空闲路径 | 3 | 主循环中 `power_save_enabled && !cuatro_deep_sleep` → `__WFI()`。`power_save.feature` + tick_handler 可触发条件，但 e2e 无主循环运行，**无法被 E2E 等价覆盖** |

### 🟡 部分非端到端 When 步骤

| # | 非 E2E When 步骤 | 所在 Feature | 内部机制 | 场景数 | 可被哪些 E2E 覆盖 |
|---|-----------------|-------------|---------|--------|------------------|
| 1 | `When can push direct to queue N` | `can_comms.feature` | JNA 直接操作 CAN 队列 w_ptr/r_ptr | 5 (C1 合并) | USB ep3 out → `comms_can_write` → `can_send` → `process_can` → `can_push` (同一代码路径)。`fdcan_interrupt.feature` 的 `can_rx` 也调用 `can_push` |
| 2 | `When can pop direct from queue N` | `can_comms.feature` | JNA 直接操作 CAN 队列 | 同上 | USB ep1 in → `comms_can_read` → `can_pop` (同一代码路径) |
| 3 | `When refresh can slots empty for queue N` | `can_comms.feature` | JNA 直接调用 `can_slots_empty()` | 同上 | `can_push` 内部调用 `can_slots_empty`，满队列场景即覆盖 |
| 4 | `When clock source init` | `clock_source.feature` | JNA 直接调用 `clock_source_init()` | 6 (C2 合并) | `board_init.feature`: `cuatro_init()` / `tres_init()` 内部调用 `clock_source_init()`，GPIO/TIM 副作用可验证 |
| 5 | `When process stop mode` | `deep_sleep.feature` | JNA 直接调用 `enter_stop_mode()` | ~6 | `deep_sleep.feature` 的 USB `RequestDeepSleep` 场景设置 `stop_mode_requested`，主循环下一次迭代调用 `enter_stop_mode()`，但 e2e **无主循环运行** |
| 6 | `And set fan enabled through board 1` | `fan_power.feature` | JNA 指针调用 `set_fan_enabled()` | 1 | cuatro/tres: `SetFanPower` → tick_handler → `fan_tick` → `set_fan_enabled` (已由同一 feature 覆盖)<br>red: `unused_set_fan_enabled` **无法被 E2E 覆盖** (`has_fan=false` 跳过 `fan_tick`) |
| 7 | `When process can 255` | `fdcan_interrupt.feature` | JNA 直接调用 `process_can()` | 1 | `can_send` (USB ep3 / can_comms) → `process_can`，正常 CAN 发送即触发 |
| 8 | `When can rx send:`<br>`When can rx N` | `fdcan_interrupt.feature` | JNA 直接调用 `can_rx()`，注入假 FDCAN SRAM | 5 (E.4) | `can_loopback.feature`: loopback enable → CAN send → 硬件回环 → FDCAN RX 中断 → `can_rx()` |
| 9 | `When set forwarding bus N to bus M` | `fdcan_interrupt.feature` | JNA 直接操作 `bus_config[].forwarding_bus` | 1 | **无法被 E2E 覆盖** — 无 USB 控制接口设置转发总线 |
| 10 | `When set fdcan ir bus N errors ...` | `fdcan_interrupt.feature` | JNA 直接操作 FDCAN IR 寄存器 | 2 | **无法被 E2E 覆盖** — PED/PEA/EP/BO 是硬件错误标志，软件无法主动触发 |
| 11 | `When tick siren` | `siren.feature` | JNA 直接调用 `set_siren()` | 3 | `tick_handler()` 8Hz 中调用 `set_siren()`，`When call tick handler N times` (如 `heartbeat_loss.feature`) 即触发同一代码路径 |
| 12 | `When spi tx done`<br>`When spi tx done with reset` | `spi_state_machine.feature` | DMA 完成模拟 | 5 | `SpiProcessData` → `spi_rx_done` 已设置 `next_state`，状态转换在 `spi_rx_done` 中完成。`spi_tx_done` 只是让 DMA 模拟"发送完毕"，**实际状态转换逻辑相同** |
| 13 | `When spi set state N` | `spi_state_machine.feature` | 直接写入 `spi_state` | 1 | 所有合法状态由 SPI 协议自然驱动，不需要手动设状态 |
| 14 | `When endpoint2 write with hex:` | `spi_state_machine.feature` | JNA 直接调用 `comms_endpoint2_write()` | 5 (C6 合并) | SPI DATA_RX endpoint 2 → `comms_endpoint2_write()` (B4 场景)，同一代码路径 |
| 15 | `When SPI version packet` | `spi_version_packet.feature` | JNA 直接调用 `spi_version_packet()` | 2 | SPI HEADER 收到 "VERSION" → `spi_rx_done()` 调用 `spi_version_packet()`，`spi_state_machine.feature` 已覆盖 |
| 16 | `And detect harness orientation` (非 1Hz 路径) | `tick_paths.feature` | JNA 直接调用 `harness_detect_orientation()` | 2 | 同 `harness_detect.feature`，`tick_handler()` 8Hz 内部调用 |

### 分类总结

```
非 E2E When 步骤总计: 20 个 (分布在 14 个 feature 中)

覆盖情况:
  ✅ 已被 E2E 路径等价覆盖:     12 个  (60%)  — 同一 C 代码路径，触发方式不同
  ⚠️ 部分等效/路径不同:          6 个  (30%)  — board_init/wfi_idle/stop_mode/tx_done/set_state/version_packet
  ❌ 无法被 E2E 覆盖:            4 个  (20%)  — recover_fault/set_forwarding/set_fdcan_ir/red_set_fan_enabled
```

### 12 个"已被 E2E 等价覆盖"步骤的转换分析 (2026-07-29)

| # | 非 E2E When 步骤 | 可转换? | 原因 |
|---|-----------------|---------|------|
| 1 | `When can push direct` | ❌ 保留 | 测试特定 w_ptr/r_ptr 位置的回绕/满队列，USB 路径无法精确控制队列指针 |
| 2 | `When can pop direct` | ❌ 保留 | 同上，需特定 r_ptr 位置 |
| 3 | `When refresh can slots empty` | ❌ 保留 | 同上，边缘条件测试 |
| 4 | `When clock source init` | ❌ 保留 | `board_init` 不验证 TIM 寄存器值，仅 GPIO 副作用 |
| 5 | `When process can 255` | ❌ 保留 | 0xff 守卫在 `can_send()` 调用 `process_can()` 之前被拦截，USB 路径无法触发 |
| 6 | `When can rx send:` | ❌ 保留 | 扩展帧/CAN-FD/BRS/FIFO 满等帧类型需直接注入假 FDCAN SRAM，loopback 只能产生标准帧 |
| 7 | **`When tick siren`** | ✅ **已转换** | `tick_handler()` 8Hz 中调用 `set_siren()`，`When call tick handler 8 times` 等价覆盖 |
| 8 | `When spi tx done` | ❌ 保留 | DMA 完成回调，`SpiProcessData` 只触发 `spi_rx_done`，`tx_done` 是独立路径 |
| 9 | `When spi set state N` | ❌ 保留 | 测试 `spi_tx_done` 的 default/unexpected 分支，正常 SPI 协议不会进入该状态 |
| 10 | `When endpoint2 write with hex:` | ❌ 保留 | SPI 路径仅覆盖 ring 0，rings 1-4 的 `get_ring_by_number()` 过滤逻辑需直接调用 |
| 11 | `When SPI version packet` | ❌ 保留 | SPI 状态机 VERSION 场景仅验证状态转换，不验证 CRC-8/UID/hw_type/PID 数据内容 |
| 12 | `And detect harness orientation` (tick_paths) | ❌ 保留 | 作为 setup 步骤设置 `harness.status` 触发 reinit，`tick_handler` 内部调用同一函数 |

**结论**: 仅 siren.feature 的 3 个 `When tick siren` 可无损耗转换为 `When call tick handler 8 times`（已完成）。其余 11 个因测试的是 E2E 路径无法触发的边界条件或数据验证，保留非 E2E 调用方式。

1. **60% 的非 E2E When 步骤有对应的 E2E 等价路径**——同一段 C 代码被 USB 命令、CAN 传输、tick_handler 或 SPI 协议自然触发。这些非 E2E 步骤主要是为了测试边界条件（队列回绕、满队列等）时更精确地控制内部状态。

2. **30% 是硬件初始化/主循环路径**——`board_init`、`wfi_idle`、`enter_stop_mode` 在真实硬件上由 `main()` 启动流程或主循环触发，e2e 环境无主循环，必须直接 JNA 调用。这些属于环境限制，非设计问题。

3. **20% 完全无法被 E2E 覆盖**:
   - `fault_recovered()` — 无公开 API，只在 relay_malfunction 边沿检测中由 tick_handler 内部调用
   - `bus_config[].forwarding_bus` — 无 USB 控制接口
   - FDCAN IR 错误标志 (PED/PEA/EP/BO) — 纯硬件标志，软件无法主动写入
   - red `unused_set_fan_enabled` — `has_fan=false` 导致 `fan_tick()` 体被完全跳过

这些是固件内部实现细节或硬件寄存器操作，**保留直接 JNA 测试是合理的**。
