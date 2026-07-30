# 端到端测试覆盖分析

> 最后更新: 2026-07-30
> Feature 文件: 36 个, 场景总数: 235 (cuatro/tres/red 合并)
> 综合行覆盖率: **~91%** (~2100/~2300 lines), ~40 files
> 数据来源: `e2e-tests/run_all_coverage.sh`

---

## 一、e2e 编译模型

e2e 通过 `libpanda.c` 编译完整 `board/main.c`，利用 `-I` 优先级覆盖机制：
- `-I e2e-tests/src/test/c` (最高优先级 → e2e 桩)
- `-I /path/to/panda` (项目根)
- `-I /path/to/panda/board` (board 目录)

### 1.1 进入覆盖率的 31 个真实 `board/` 文件

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
board/drivers/pwm.h                   — PWM 控制 (Phase G)
board/drivers/led.h                   — LED 控制 (Phase G)
board/drivers/gpio.h                  — GPIO 控制
board/drivers/clock_source.h          — 时钟源定时器
board/drivers/simple_watchdog.h       — 看门狗
board/drivers/bootkick.h              — SOM 启动/复位状态机 (B2)
board/drivers/harness.h               — Harness 检测/继电器 (B5)
board/drivers/fdcan.h                 — FDCAN 高层驱动 (C3)
board/drivers/spi.h                   — SPI 协议层 (C3)
board/drivers/can_health_pkt.h        — CAN 健康统计更新 (B4)
board/drivers/timers.h                — 定时器初始化/读取 (Phase H)
board/drivers/interrupts.h            — 中断处理/频率限制 (Phase H)
board/drivers/uart.h                  — UART 调试输出 (Phase H)
board/crc.h                           — CRC-8 校验 (C1)
board/libc.h                          — memcpy, memset, delay
board/stm32h7/lladc_declarations.h    — ADC 信号类型声明
board/stm32h7/llfdcan.h               — FDCAN 寄存器级驱动 (C3)
board/boards/board_declarations.h     — board 结构体、HW_TYPE_* 常量
board/boards/{cuatro,tres,red}.h      — 板级实现
board/boards/unused_funcs.h           — 未使用功能的空桩实现
board/provision.h                     — 设备 Provision 读取
```

### 1.2 未进入覆盖率的文件

```
┌─ board/ 全部 C/H 文件 (~90 个)
│
├── ✅ 已编译为真实代码 (31 个)
├── ⚠️ 被 e2e 桩替换 (7 个) — 见第三节
├── ❌ 被 stm32h7_config.h 切断 — 纯硬件外设 (peripherals.h, clock.h, llfan.h 等)
├── 🚫 其他固件目标 (25 个) — 见第七节
└── 📦 CMSIS/HAL 头 + 工具脚本 — 见第八节
```

---

## 二、覆盖率总览

> 基线: C3 完成后 fdcan.h / llfdcan.h / spi.h / crc.h / can_health_pkt.h / provision.h 共 6 个文件新进入覆盖率。

| 源文件 | 行覆盖 | 说明 |
|--------|--------|------|
| `board/main_comms.h` | 95.5% (257/269) | 仅 default handler print + ALLOW_DEBUG 条件未覆盖 |
| `board/main.c` | 64.2% (145/226) | main()/LED fade/debug_ring_callback 硬件依赖，不可提升 |
| `board/can_comms.h` | 100% (76/76) | ✅ |
| `board/config.h` | 100% (4/4) | ✅ |
| `board/crc.h` | 100% (17/17) | ✅ |
| `board/can.h` | 100% (1/1) | ✅ |
| `board/provision.h` | 100% (8/8) | ✅ |
| `board/utils.h` | 100% (10/10) | ✅ |
| `board/sys/sys.h` | 100% (6/6) | ✅ |
| `board/drivers/can_common.h` | 100% (107/107) | ✅ |
| `board/drivers/fan.h` | 100% (27/27) | ✅ |
| `board/drivers/pwm.h` | 82.2% (37/45) | ✅ 去桩化 (仅 default 分支 + ch3 llfan 路径未覆盖) |
| `board/drivers/led.h` | 96.0% (24/25) | ✅ 去桩化 (仅 LED_RED define 行未覆盖) |
| `board/drivers/simple_watchdog.h` | 100% (14/14) | ✅ |
| `board/drivers/clock_source.h` | 100% (40/40) | ✅ |
| `board/drivers/registers.h` | 97.8% (44/45) | 仅 hash collision fallback 未覆盖 |
| `board/drivers/bootkick.h` | 97.9% (47/48) | ✅ |
| `board/drivers/can_health_pkt.h` | 94.6% (35/37) | ✅ |
| `board/drivers/gpio.h` | 84.5% (60/71) | set_gpio_analog、restore_gpio 部分路径 |
| `board/drivers/drivers.h` | 80.0% (4/5) | 1 行未覆盖 |
| `board/drivers/fdcan.h` | ~97% (~175/181) | ✅ body_can_rx() 仅 PANDA_BODY 固件 |
| `board/drivers/spi.h` | 94.2% (147/156) | ✅ spi_init (8行 DMA) + 防御 print (4行) |
| `board/drivers/timers.h` | **100%** (27/27) | ✅ Phase H (timer_init, microsecond_timer_init, interrupt_timer_init, tick_timer_init) |
| `board/drivers/interrupts.h` | **96.2%** (51/53) | ✅ Phase H (init_interrupts, handle_interrupt, interrupt_timer_handler, unused_interrupt_handler) |
| `board/drivers/uart.h` | **94.8%** (73/77) | ✅ Phase H (UART_BUFFER 直接使用, 无 E2E_TEST 守卫) |
| `board/libc.h` | 83.9% (52/62) | delay() + assert_fatal(false) 不可覆盖 |
| `board/sys/faults.h` | 100% (20/20) | ✅ |
| `board/sys/power_saving.h` | 96.7% (89/92) | ✅ |
| `board/boards/board_declarations.h` | 83.3% (5/6) | 1 行未覆盖 |
| `board/boards/cuatro.h` | 83.3% (55/66) | GPIO 配置路径部分未调用 |
| `board/boards/tres.h` | 88.0% (81/92) | GPIO 配置路径部分未调用 |
| `board/boards/red.h` | 90.0% (63/70) | GPIO 配置路径部分未调用 |
| `board/boards/unused_funcs.h` | 100% (23/23) | ✅ |
| `board/stm32h7/llfdcan.h` | 83.2% (134/161) | ✅ 部分 LL 路径未触发 |
| `board/stm32h7/llfdcan_declarations.h` | 91.3% (21/23) | ✅ 真实代码 (Phase H) |
| `e2e-tests/.../fdcan_regs.h` | 94.1% (160/170) | e2e 桩 |
| `e2e-tests/.../board/stm32h7/board.h` | 100% (41/41) | e2e 桩 |
| `e2e-tests/.../board/stm32h7/lladc.h` | 88.9% (8/9) | e2e 桩 |

---

## 三、e2e 桩库存与去桩化状态

### 3.1 编译模型

```
libpanda.c (2026-07-29 现状):
  #include "board/main.c"                    ← ✅ 完整固件
  #include "board/drivers/fan.h"             ← ✅ 真实代码 (100%)
  #include "board/drivers/clock_source.h"    ← ✅ 真实代码 (100%)
  #include "board/drivers/simple_watchdog.h" ← ✅ 真实代码 (100%)
  #include "board/libc.h"                    ← ✅ 真实代码 (83.9%)
  #include "board/drivers/registers.h"       ← ✅ 真实代码 (97.8%)
  #include "board/sys/faults.h"              ← ✅ 真实代码 (100%)
  #include "board/drivers/harness.h"         ← ✅ 真实代码 (100%)
  #include "board/drivers/fdcan.h"           ← ✅ 真实代码 (~97%)
  #include "board/drivers/spi.h"             ← ✅ 真实代码 (94.2%)
  #include "board/drivers/can_health_pkt.h"  ← ✅ 真实代码 (100%)
  #include "board/crc.h"                     ← ✅ 真实代码 (100%)
  #include "board/stm32h7/llfdcan.h"         ← ✅ 真实代码 (83.2%)
  #include "board/drivers/bootkick.h"        ← ✅ 真实代码 (100%)
  #include "board/sys/power_saving.h"        ← ✅ 真实代码 (96.7%)
  #include "board/boards/{cuatro,tres,red}.h" ← ✅ 真实代码 (83-90%)
  #include "board/drivers/gpio.h"            ← ✅ 真实代码 (84.5%)
  #include "board/stm32h7/stm32h7_config.h"  ← ⚠️ e2e 桩 (CMSIS 切断 + include 转发)
  #include "board/stm32h7/board.h"           ← ⚠️ e2e 桩 (GPIO/ADC/PWR 宏 → 真实 board)
  #include "board/stm32h7/lladc.h"           ← ⚠️ e2e 桩 (拦截 adc_get_mV)
  #include "board/stm32h7/llfdcan_declarations.h" ← ✅ 真实代码 (91.3%, Phase H — 包装器已删除)
  #include "board/drivers/uart.h"            ← ✅ 真实代码 (94.8%, Phase H)
  #include "board/drivers/interrupts.h"      ← ✅ 真实代码 (96.2%, Phase H)
  #include "board/drivers/pwm.h"             ← ✅ 真实代码 (82.2%, 直接用真实文件)
  #include "board/drivers/led.h"             ← ✅ 真实代码 (96.0%, 直接用真实文件)
  #include "board/drivers/timers.h"          ← ✅ 真实代码 (100%, Phase H)
  #include "board/drivers/usb.h"             ← ⚠️ e2e 桩 (USB endpoint 模拟)
  #include "board/drivers/fake_siren.h"      ← ⚠️ e2e 桩 (声明)
  #include "board/drivers/simple_watchdog.h" ← ✅ 真实代码 (100%, 直接用真实文件)
  #include "board/drivers/spi.h"             ← ✅ 真实代码 (94.2%, 直接用真实文件, llspi stubs 在 fake_stm.h)
```

### 3.2 桩文件清单 (15 个, 8 已完成) 与去桩化评估

| 文件 | 类型 | 可去桩? | 方案 / 障碍 |
|------|------|---------|------------|
| `stm32h7_config.h` | 配置枢纽 | ❌ 不可 | 切断 CMSIS/HAL 依赖链的必须枢纽。真实文件引入 `stm32h7xx.h`，无法在 macOS 编译。 |
| `stm32h7/board.h` | 桥接桩 | ❌ 不可 | 让真实 board init 编译的必经之路。GPIO/ADC/PWR 宏映射无可替代。 |
| `stm32h7/lladc.h` | 拦截桩 | ❌ 不可 | 真实 `lladc.h` 直读 ADC 寄存器。e2e 必须注入受控电压测试 harness 检测。 |
| `stm32h7/llfdcan_declarations.h` | 定义桩 | ✅ 已完成 | 真实文件已有 `#ifndef E2E_TEST` 守卫。`llfdcan.h` 用 `#include "llfdcan_declarations.h"`（相对路径），编译器先查同目录，直接命中真实文件。e2e 包装器多余，已删除。覆盖率 91.3%。 |
| `stm32h7/sound.h` | 空桩 | ❌ 不可 | 229 行 SAI4/DMA/DAC/DFSDM 外设初始化，无独立业务逻辑。 |
| `early_init.h` | 空桩 | ❌ 不可 | SCB->VTOR、DBGMCU->IDCODE、jump_to_bootloader()，纯启动流程。 |
| `drivers/pwm.h` | 空桩 | ✅ 已完成 (Phase G) | 真实代码仅用 `register_set`/`register_set_bits`。e2e 包装器已删除，真实文件直接使用。覆盖率 82.2% (37/45)。 |
| `drivers/led.h` | 空桩 | ✅ 已完成 (Phase G) | 依赖 `pwm_init`/`pwm_set`。e2e 包装器已删除，真实文件直接使用。覆盖率 96.0% (24/25)。 |
| `drivers/timers.h` | 空桩 | ✅ 已完成 | 所有类型/宏/桩集中到 `fake_stm.h`（`INTERRUPT_TIMER_IRQ`、`enable_interrupt_timer`、`NVIC_EnableIRQ`）。`init_interrupts(true)` + `microsecond_timer_init()` + `tick_timer_init()` 在 `jna_panda_init()` 中调用。覆盖率 100% (27/27)。 |
| `drivers/usb.h` | 功能桩 | ❌ 不可 | e2e 专属 USB endpoint 模拟器，非简单桩。真实 usb.h 为完整 USB OTG 驱动 (31KB)。 |
| `drivers/fake_siren.h` | 声明桩 | ❌ 不可 | 116 行 I2C codec/DMA/TIM7/DAC，深度耦合硬件。 |
| `drivers/uart.h` | 类型桩 | ✅ 已完成 | `uart_ring` 类型移到 `fake_stm.h`（`void*` 替代 `USART_TypeDef*`），`UART_BUFFER` 宏不再需要 `#ifndef E2E_TEST` 守卫。`libpanda.c` 中手动实例定义已删除，实例由 `UART_BUFFER` 宏自动生成。覆盖率 94% (73/77)。 |
| `drivers/interrupts.h` | 功能桩 | ✅ 已完成 | `IRQn_Type`、`interrupt` 结构体、`REGISTER_INTERRUPT` 宏移到 `fake_stm.h`。`init_interrupts(true)` 在 `jna_panda_init()` 中调用（镜像真实 `main()`）。覆盖率 96% (51/53, 仅 `interrupt_timer_handler` 内日志未覆盖)。 |
| `drivers/spi.h` | 委托桩 | ✅ 已完成 | e2e 包装器已删除，真实文件直接使用。llspi stubs 移到 `fake_stm.h`。覆盖率 94.2% (147/156)。 |
| `drivers/simple_watchdog.h` | 委托桩 | ✅ 已完成 | e2e 包装器已删除，真实文件直接使用。覆盖率 100%。 |

### 3.3 已完成去桩化

| 优先级 | 原始桩/Gen 文件 | 替换为真实代码 | 覆盖率 |
|--------|---------------|--------------|--------|
| B1 | `power_save_e2e.gen.c` + `enter_stop_mode_e2e.gen.c` | `board/sys/power_saving.h` | 95.8% |
| B2 | `bootkick_e2e.gen.c` | `board/drivers/bootkick.h` | 97.9% |
| B3/C3 | `fdcan_e2e.gen.c` + e2e 桩 `fdcan.h` | `board/stm32h7/llfdcan.h` + `board/drivers/fdcan.h` | 83.2% / ~97% |
| B4 | `can_health_e2e.gen.c` | `board/drivers/can_health_pkt.h` (新建共享文件) | 94.6% |
| B5 | `harness_detect_e2e.gen.c` + e2e 桩 `harness.h` | `board/drivers/harness.h` | 100% |
| C1 | e2e 桩 `crc.h` | `board/crc.h` | 100% |
| C2 | gen 文件内联宏 | `board/stm32h7/llfdcan_declarations.h` (真实宏) | 91.3% |
| G | e2e 桩 `pwm.h` + `led.h` | `board/drivers/pwm.h` + `board/drivers/led.h` (真实代码) | 82.2% / 96.0% |
| H | e2e 桩 `timers.h` + `interrupts.h` + `uart.h` + `llfdcan_declarations.h` | `board/drivers/timers.h` + `interrupts.h` + `uart.h` + `llfdcan_declarations.h` (真实代码) | 100% / 96% / 94% / 91.3% |

### 3.4 生产代码 `#ifdef E2E_TEST` 使用清单

`drivers/uart.h` 中 `UART_BUFFER` 调用的 `#ifndef E2E_TEST` 守卫已移除（Phase H），其余不变。共 6 个文件，14 处使用（原 16 处，删 2 处）：

**`board/drivers/harness.h` (4 处)**

| 行 | 守卫 | 用途 |
|----|------|------|
| 5 | `#ifndef` | `harness` 全局变量由 libpanda.c 定义 |
| 56 | `#ifdef` | `harness_detect_orientation()` static→公开 |
| 99 | `#ifndef` | `harness_tick()` 跳过自动方向检测 |
| 111 | `#ifndef` | `harness_init()` 跳过初始方向检测 |

**`board/drivers/fdcan.h` (5 处)**

| 行 | 守卫 | 用途 |
|----|------|------|
| 3 | `#ifndef` | `cans[3]` 由 libpanda.c 定义为 `fake_fdcan[]` |
| 24 | `#ifdef` | `can_clear_send()` 跳过 10Hz 速率限制 |
| 63 | `#ifdef` | `process_can()` 指针算术替代 uint32_t 强转 |
| 140 | `#ifdef` | `can_rx()` 指针算术替代 uint32_t 强转 |
| 214 | `#ifdef` | `can_rx()` 手动清零 RXF0S (真实硬件自动清零) |

**`board/drivers/bootkick.h` (3 处)**

| 行 | 守卫 | 用途 |
|----|------|------|
| 7 | `#ifdef` | static 局部变量提升为文件作用域 |
| 18 | `#ifdef` | `#define` 映射 `e2e_*` 到原 static 变量名 |
| 90 | `#ifdef` | `#undef` 清理 |

**`board/stm32h7/llfdcan.h` (2 处)**

| 行 | 守卫 | 用途 |
|----|------|------|
| 32 | `#ifdef` | `fdcan_exit_init()` 同时清除 CCE |
| 194 | `#ifdef` | `llcan_init()` 指针算术替代 uint32_t 强转 |

**`board/stm32h7/llfdcan_declarations.h` (1 处)**

| 行 | 守卫 | 用途 |
|----|------|------|
| 16 | `#ifndef` | `FDCAN_START_ADDRESS` — e2e 中用 0 |

**`board/sys/faults.h` (1 处)**

| 行 | 守卫 | 用途 |
|----|------|------|
| 3 | `#ifdef` | 重定义 `PERMANENT_FAULTS` 测试永久故障路径 |

---

## 四、USB 命令覆盖状态

### 4.1 panda 固件 — `board/main_comms.h` (33/34 已覆盖)

| 命令 | 功能 | Feature |
|------|------|---------|
| 0xa8 | 微秒定时器 | `timer_fan.feature` |
| 0xb0 | IR 功率 | `ir_power.feature` |
| 0xb1 | 风扇功率 | `fan_power.feature` |
| 0xb2 | 风扇转速 | `timer_fan.feature` |
| 0xb5 | 深度休眠 | `deep_sleep.feature` |
| 0xc0 | 通信重置 | `can_comms.feature` (已合并) |
| 0xc1 | 硬件类型 | `spi_version_packet.feature` (已合并) |
| 0xc2 | CAN 健康统计 | `can_health.feature` |
| 0xc3 | MCU UID | `spi_version_packet.feature` (已合并) |
| 0xc4 | 中断调用率 | `fdcan_interrupt.feature` + `interrupt_rate.feature` ✅ Phase H |
| 0xc5 | 继电器驱动 | `relay.feature` |
| 0xc6 | SOM GPIO 读取 | `som_gpio.feature` |
| 0xd0 | 序列号/Provision | `spi_version_packet.feature` (已合并) |
| 0xd1 | Bootloader 模式 | `system_reset_bootloader.feature` (已合并) |
| 0xd2 | 健康数据包 | `health.feature` |
| 0xd3/d4 | 签名 (128B) | `health.feature` (已合并) |
| 0xd6 | 固件版本 | `health.feature` (已合并) |
| 0xd8 | 系统复位 | `system_reset_bootloader.feature` (已合并) |
| 0xdb | CAN 复用模式 | `can_mode.feature` |
| 0xdc | 安全模式 | `safety_mode.feature` |
| 0xdd | 数据包版本 | `health.feature` (已合并) |
| 0xde | CAN 波特率 | `can_bitrate.feature` |
| 0xdf | 替代体验 | `alternative_experience.feature` |
| 0xe0 | UART 读取 | `spi_state_machine.feature` (已合并) |
| 0xe5 | CAN 回环 | `can_loopback.feature` |
| 0xe6 | 时钟源 | `clock_source.feature` |
| 0xe7 | 省电模式 | `power_save.feature` |
| 0xe8 | CAN FD 自动 | `can_fd_data_bitrate.feature` (已合并) |
| 0xf1 | CAN 环形缓冲清除 | `can_ring_clear.feature` |
| 0xf3 | 心跳 | `heartbeat.feature` |
| 0xf6 | 警笛 | `siren.feature` |
| 0xf8 | 禁用心跳检查 | `heartbeat.feature` |
| 0xf9 | CAN FD 数据率 | `can_fd_data_bitrate.feature` |
| 0xfc | CAN FD Non-ISO | `can_fd_data_bitrate.feature` (已合并) |

### 4.2 未覆盖固件目标

- **Bootstub**: 3 个刷写命令未覆盖 (0xb0 echo, 0xb1 unlock, 0xb2 erase)，需独立 e2e 环境
- **Jungle 固件**: 8 个命令未覆盖，需独立 e2e 环境
- **Body 固件**: 2 个命令未覆盖，需独立 e2e 环境

---

## 五、`main.c` 主循环行为覆盖

所有高/中优先级行为均已覆盖：

| 编号 | 功能 | Feature | 场景数 | 触发方式 |
|------|------|---------|--------|---------|
| P1 | `bootkick_tick()` 5 态 FSM | `bootkick.feature` | 14 | jna_call_tick_handler |
| P2 | 心跳丢失自动行为 | `heartbeat_loss.feature` | 9 | jna_call_tick_handler |
| P3 | `simple_watchdog_kick()` | `tick_paths.feature` (已合并) | 3 | jna_call_tick_handler |
| P4 | `relay_malfunction` 边沿检测 | `relay_malfunction.feature` | 3 | jna_call_tick_handler |
| P5 | `check_registers()` | `tick_paths.feature` (已合并) | 3 | jna_call_tick_handler |
| P6 | WFI 空闲路径 | `wfi_idle.feature` | 3 | JNA 直接调用 |
| P7 | `ignition_can_cnt` 复位 | `ignition_can.feature` | 2 | jna_call_tick_handler |
| P8 | `fan_state.cooldown_counter` | `fan_cooldown.feature` | 3 | jna_call_tick_handler |
| P9 | `harness_detect_orientation()` | `harness_detect.feature` | 8 | JNA 直接调用 |
| P12 | `safety_mode_cnt` 溢出回绕 | `tick_paths.feature` | 6 | jna_call_tick_handler |
| N1 | `clock_source_init()` | `clock_source.feature` (已合并) | 6 | JNA 直接调用 |
| N2 | Board `xxx_init()` | `board_init.feature` | 7 | JNA 直接调用 |
| N3 | Permanent fault | `permanent_fault.feature` | 2 | JNA 直接调用 |
| N4 | `can_common.h` 队列回绕 | `can_comms.feature` (已合并) | 5 | JNA 直接调用 |
| N5 | `libc.h` memcmp/delay | 通过 provision.h 隐式覆盖 | — | — |

### tick_handler 触发机制

`When call tick handler N times` → `jna_call_tick_handler()` → 真实 `tick_handler()` (8Hz + 1Hz 逻辑)。8 次调用 = 1 次 1Hz tick。通过 `heartbeatDisabled` 控制心跳超时。

---

## 六、覆盖率提升历程

### 第一阶段: 纯加场景 (N1-N5)
- N1: `clock_source_init()` 17.5% → 100% (3 场景)
- N2: Board `xxx_init()` 35-66% → 95% (7 场景)
- N3: Permanent fault 78.9% → 100% (2 场景)
- N4: CAN queue wrap 95.3% → 100% (5 场景)
- N5: libc.h 61.3% → 83.9% (通过真实 provision.h 覆盖 memcmp)

### 第二阶段: 去桩化 (B1-B5)
- B1: `power_saving.h` 去桩化 (0% → 95.8%), 综合 79.6% → 81.6%
- B2: `bootkick.h` 去桩化 (0% → 97.9%), 综合 81.6% → 82.2%
- B4: `can_health_pkt.h` 提取为共享文件 (0% → 94.6%)
- B5: `harness.h` 去桩化 (0% → 100%), 综合 82.2% → 90.0%

### 第三阶段: 轻量去桩化 (C1-C3)
- C1: `crc.h` 去桩化 (0% → 100%, 纯 C 算法)
- C2: `llfdcan_declarations.h` 真实宏定义进入覆盖率 (91.3%)
- C3: `llfdcan.h` + `fdcan.h` 去桩化 (316 行真实代码, 消除 gen 文件)

### 第四阶段: 低于 80% 文件提升 (D-E-F)
- D.1: `config.h` 75% → 100% (1 行)
- D.2: `unused_funcs.h` 26.1% → 100% (red 板调用 unused_* 函数)
- D.3: `can_comms.h` 56.6% → 100% (overflow buffer 分片场景, 5 场景)
- E.4: `fdcan.h` can_rx() 全路径覆盖, ~85% → ~97% (8 场景)
- F.5: `spi.h` SPI 全状态机, 13.5% → 94.2% (21 场景)

### 第五阶段: 中断/定时器去桩化 (Phase H)
- H: `timers.h` + `interrupts.h` + `uart.h` + `llfdcan_declarations.h` 去桩化
  - `timers.h`: 11% → 100% (27/27), 4/4 函数
  - `interrupts.h`: 0% → 96.2% (51/53)
  - `uart.h`: 0% → 94.8% (73/77), UART_BUFFER 直接使用, 无 E2E_TEST 守卫
  - `llfdcan_declarations.h`: 包装器删除, 直接使用真实代码 (91.3%)
- 新增 `interrupt_rate.feature` (4 场景, 13 步骤)
- 场景总数: 230 → 235

### 覆盖率基线演进

```
初始基线:  79.6%
B1 完成后: 81.6%
B2 完成后: 82.2%
B5 完成后: 90.0%
Phase D 后: 80.5% (基线重设, +33 行进入覆盖率)
Phase E 后: ~83.9%
Phase F 后: 91.1% (1989/2183) ← 本次整合前
Phase H 后: ~91% (~2100/~2300, ~40 files) ← 当前
```

---

## 七、其他固件目标

panda 代码库从同一 `board/` 目录构建三个独立固件，e2e 当前仅覆盖 panda 主固件 (`board/main.c`)：

```
board/main.c          → panda 固件    ✅ e2e 覆盖
board/bootstub.c      → bootstub      ❌ 无 e2e (3 文件)
board/jungle/main.c   → jungle 固件   ❌ 无 e2e (6 文件)
board/body/main.c     → body 固件     ❌ 无 e2e (12 文件)
board/crypto/         → 加密库        ❌ bootstub 专用 (4 文件)
```

---

## 八、CMSIS/HAL 头文件与工具脚本

以下不计入覆盖率：STM32 官方 CMSIS 头文件 (`core_cm7.h`, `stm32h7xx.h` 等 12 个)、Python 工具 (`flash.py`, `recover.py`)、未被引用的文件 (`llflash.h`, `lli2c.h`)。

---

## 九、测试设计审视

### 9.1 非端到端功能测试合并

从 52 个 feature 合并至 36 个 (净减 16 个)，覆盖率无损。合并类别：

| 类别 | 减少 | 目标文件 |
|------|------|---------|
| 纯重复 | 1 | `microsecond_timer` → 已删除 |
| 单一数据读取 | 8 | → `spi_version_packet`, `health`, `fdcan_interrupt`, `spi_state_machine` |
| 内部实现细节 | 6 | → `can_comms`, `clock_source`, `tick_paths`, `spi_state_machine`, `safety_mode` |
| 单一控制写入 | 5 | → `can_fd_data_bitrate`, `system_reset_bootloader` |

保留的 33 个真正端到端 feature（完整多步骤工作流）：CAN 通信协议 (4)、CAN 配置 (3)、安全模式 (1)、心跳超时 (2)、电源管理 (3)、SPI 协议 (2)、故障处理 (2)、CAN 中断 (1)、中断处理 (1)、设备控制 (5)、tick 流程 (2)、硬件检测 (2)、启动流程 (1)、其他 (3)。

### 9.2 非端到端 When 步骤

共 20 个非 E2E When 步骤（直接 JNA 调用内部函数/操作内部数据结构），分析结论：
- **60%** 有 E2E 等价路径，但保留 JNA 调用以测试边界条件（队列回绕、FIFO 满等）
- **30%** 是硬件初始化/主循环路径，e2e 无主循环，必须 JNA 调用
- **10%** 完全无法被 E2E 覆盖（`fault_recovered` 无公开 API、FDCAN IR 硬件标志、red `unused_set_fan_enabled` 被 `has_fan=false` 跳过）
