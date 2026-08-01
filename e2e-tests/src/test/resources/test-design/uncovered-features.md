# 端到端测试覆盖分析

> 最后更新: 2026-08-01 (Phase L: BLDC de-stubbing)
> Feature 文件: 38 个, 场景总数: 257 (cuatro/tres/red/body 合并)
> 综合行覆盖率: **79.4%** (2371/2985 lines), 48 files
> 数据来源: `e2e-tests/run_all_coverage.sh` → `e2e-tests/build/coverage/merged.lcov`

---

## 一、e2e 编译模型

### 1.1 Panda 固件

e2e 通过 `libpanda.c` 编译完整 `board/main.c`，利用 `-I` 优先级覆盖机制：
- `-I e2e-tests/src/test/c` (最高优先级 → e2e 桩)
- `-I /path/to/panda` (项目根)
- `-I /path/to/panda/board` (board 目录)

进入覆盖率的 31 个真实 `board/` 文件（panda 固件）：

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

### 1.2 Body 固件

Body 固件通过独立的 `libpanda_body.c` 编译 `board/body/main.c`（Phase K），利用相同的 `-I` 优先级覆盖机制：
- `-I e2e-tests/src/test/c` (最高优先级 → e2e 桩)
- `-I /path/to/panda` (项目根)
- `-I /path/to/panda/board` (board 目录)
- `-I /path/to/panda/board/body` (body 子目录)
- 编译宏: `-DPANDA_BODY` (激活 body 条件编译路径)

进入覆盖率的 body 固件文件（10 个，均有可执行代码）：

```
board/body/main.c                     — Body 主固件逻辑 (main/tick_handler/exti15_10_handler/bldc_tim8_handler)
board/body/main_comms.h               — Body USB 命令处理 (comms_control_handler 9 个 case + comms_endpoint2_write)
board/body/can.h                      — Body CAN 通信 (8 个函数: 发送/接收/初始化/周期)
board/body/dotstar.h                  — DotStar APA102 LED 驱动 (12 个函数: 初始化/像素/彩虹/呼吸效果)
board/body/boards/board_body.h        — Body 板级初始化 (board_body_init + board_body struct)
board/body/boards/board_declarations.h — Body 板级声明 (HW_TYPE_BODY + GPIO/CAN/DotStar 引脚定义)
board/body/bldc/bldc.h               — BLDC 电机控制 (bldc_init/bldc_step/motor_set_enable, Phase L 去桩化)
board/body/bldc/BLDC_controller.h     — FOC 矢量控制器类型定义 (RT_MODEL, ExtY, ExtU, DW, P, ConstP)
board/body/bldc/BLDC_controller.c     — FOC 矢量控制器实现 (3306 行, PI 调节器/查表/PWM 生成)
board/body/bldc/BLDC_controller_data.c — FOC 参数数据 (rtConstP 正弦表 + rtP_Left 可调参数)
```

仅宏定义、无可执行代码而未进入覆盖率的 body 文件：
```
board/body/bldc/bldc_defs.h           — BLDC 电机常量 (#define 宏，不计入行覆盖)
board/body/bldc/rtwtypes.h            — Simulink 固定宽度类型 (typedef，不计入行覆盖)
```

> Body 依赖的 `board/body/bldc/bldc.h` 在 e2e 中被 `e2e-tests/src/test/c/board/body/bldc/bldc.h` 兼容包装器替换。该包装器通过 `#include <limits.h>` 抢占 guard + 覆盖 `ULONG_MAX`/`LONG_MAX` 为 ILP32 值来绕过 Simulink 自动代码的 macOS LP64 字长检查，然后 include 真实的 BLDC_controller.h/.c/.data.c。已从 `IGNORE_REGEX` 中移除，BLDC 全部进入覆盖率。

### 1.3 未进入覆盖率的文件

```
┌─ board/ 全部 C/H 文件 (~90 个)
│
├── ✅ 已编译为真实代码 (31 panda + 10 body = 41 个)
├── ⚠️ 被 e2e 桩替换 (6 个) — 见第三节
├── ❌ 被 stm32h7_config.h 切断 — 纯硬件外设 (peripherals.h, clock.h, llfan.h 等)
├── 🚫 其他固件目标 (20 个, body 已不再算其他目标) — 见第七节
└── 📦 CMSIS/HAL 头 + 工具脚本 — 见第八节
```

---

## 二、覆盖率总览

> 基线: C3 完成后 fdcan.h / llfdcan.h / spi.h / crc.h / can_health_pkt.h / provision.h 共 6 个文件新进入覆盖率。

| 源文件 | 行覆盖 | 说明 |
|--------|--------|------|
| `board/main_comms.h` | 94.1% (253/269) | default handler + ALLOW_DEBUG + MCU UID + 0xde can_init 路径 |
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
| `board/drivers/can_health_pkt.h` | 94.6% (35/37) | data error stored path 未触发 |
| `board/drivers/gpio.h` | 84.5% (60/71) | OUTPUT_TYPE_PUSH_PULL + detect_with_pull 未覆盖 |
| `board/drivers/drivers.h` | 100% (5/5) | ✅ (已从 80% 提升) |
| `board/drivers/fdcan.h` | 94.9% (150/158) | FDCAN2/3 IRQ handlers + checksum error path |
| `board/drivers/spi.h` | 94.2% (147/156) | ✅ spi_init (8行 DMA) + 防御 print (4行) |
| `board/drivers/timers.h` | **100%** (27/27) | ✅ Phase H (timer_init, microsecond_timer_init, interrupt_timer_init, tick_timer_init) |
| `board/drivers/interrupts.h` | **96.2%** (51/53) | ✅ Phase H (init_interrupts, handle_interrupt, interrupt_timer_handler, unused_interrupt_handler) |
| `board/drivers/uart.h` | **94.8%** (73/77) | ✅ Phase H (UART_BUFFER 直接使用, 无 E2E_TEST 守卫) |
| `board/libc.h` | 83.9% (52/62) | delay() + assert_fatal(false) 不可覆盖 |
| `board/sys/faults.h` | 100% (20/20) | ✅ |
| `board/sys/power_saving.h` | 96.7% (89/92) | ✅ |
| `board/boards/board_declarations.h` | 83.3% (5/6) | 1 行未覆盖 |
| `board/boards/cuatro.h` | 87.9% (58/66) | set_ir_power default + ADC 读取路径 |
| `board/boards/tres.h` | 92.4% (85/92) | set_ir_power default + read_som_gpio |
| `board/boards/red.h` | 90.0% (63/70) | set_ir_power default + set_can_mode default + ADC 读取 |
| `board/boards/unused_funcs.h` | 91.3% (21/23) | unused_init_bootloader 空函数体 (从未被调用) |
| `board/stm32h7/llfdcan.h` | 83.2% (134/161) | timeout 路径 (19行) + data_speed 5M + low speed prescaler |
| `board/stm32h7/llfdcan_declarations.h` | 91.3% (21/23) | ✅ 真实代码 (Phase H) |
| `e2e-tests/.../fdcan_regs.h` | 94.1% (160/170) | e2e 桩 |
| `e2e-tests/.../board/stm32h7/board.h` | 100% (41/41) | e2e 桩 |
| `e2e-tests/.../board/stm32h7/lladc.h` | 88.9% (8/9) | e2e 桩 |

### 2.2 Body 固件覆盖率

> Body 固件通过 `libpanda_body.c` 独立编译，覆盖率由 `run_all_coverage.sh` 合并采集。
> 现有 `@body` 测试仅通过 JNA 调用 `jna_body_control_write()` → `comms_control_handler()`，从未执行 `body_main()` 主循环。
> Phase L 去桩化后，`board/body/bldc/` 下 4 个文件（bldc.h + BLDC_controller.h/.c/.data.c）新进入覆盖率。

| 源文件 | 行覆盖 | 说明 |
|--------|--------|------|
| `board/body/main_comms.h` | ~30% | 仅 0xb3/0xb4/0xc1 3 个 case 被覆盖；0xd1(含 2 个子分支 bootloader/softloader)、0xd3、0xd4、0xd6、0xd8、0xdd 及 `comms_endpoint2_write` 均未覆盖 |
| `board/body/main.c` | 0% | `body_main()` 未执行：主循环（dotstar 彩虹/呼吸/电机启停逻辑）、`tick_handler()`（CAN 健康检查+LED 翻转）、`exti15_10_handler()`（点火消抖+充电检测）、`bldc_tim8_handler()`（→ `bldc_step()`）、`enable_fpu()`、`__initialize_hardware_early()`、`debug_ring_callback()` 全部未覆盖 |
| `board/body/can.h` | 0% | 全部 8 个函数未覆盖：`body_can_send_motor_speeds()`、`body_can_send_var_values()`、`body_can_send_body_data()`、`body_can_process_target()`、`body_can_rx()`、`body_can_init()`、`body_can_periodic()`、`body_can_send_motor_speeds` 中的 0x222 v2 ID 帧 |
| `board/body/dotstar.h` | 0% | 全部 14 个函数未覆盖：`dotstar_show()`、`dotstar_init()`、`dotstar_set_pixel()`、`dotstar_fill()`、`dotstar_set_global_brightness()`、`dotstar_hue_to_rgb()`、`dotstar_run_rainbow()`、`dotstar_apply_breathe()` 及低层 `dotstar_set_clk()`、`dotstar_set_data()`、`dotstar_write_byte()`、`dotstar_latch_len()`、`dotstar_send_start_frame()`、`dotstar_send_end_frame()` |
| `board/body/boards/board_body.h` | 0% | `board_body_init()`（GPIO/CAN/EXTI/电源初始化）仅在 `body_main()` 中调用，未执行 |
| `board/body/boards/board_declarations.h` | — | 仅 `#define` 宏，无可执行代码 |
| **BLDC 电机控制 (Phase L 新入)** | | |
| `board/body/bldc/bldc.h` (e2e 包装器) | 0% | `bldc_init()` (Simulink 模型初始化 + TIM1/TIM8 PWM + hall GPIO)、`bldc_step()` (ADC 校准+FOC 控制+PWM 输出)、`motor_set_enable()`、`motor_encoder_get_speed_rpm()` — 仅在 `body_main()` / `bldc_tim8_handler()` 中调用，均未覆盖 |
| `board/body/bldc/BLDC_controller.h` | — | 仅类型定义 (RT_MODEL, ExtY, ExtU, DW, P, ConstP)，无可执行代码 |
| `board/body/bldc/BLDC_controller.c` | 0% | 3306 行真实 FOC 矢量控制算法 (`BLDC_controller_initialize` + `BLDC_controller_step`)，仅在 `bldc_init()`/`bldc_step()` 中调用，未覆盖 |
| `board/body/bldc/BLDC_controller_data.c` | 0% | 查表数据 (`rtConstP` 正弦表 6×181 + iq_maxSca 表) + 可调参数 (`rtP_Left`)，编译到 dylib 中但从未读取 |

> **根因**：`libpanda_body.c` 提供了 JNA 入口函数 `jna_body_control_write()` / `jna_body_get_rpm_left()` 等来调用 `comms_control_handler()` 和读取全局变量，但从未提供调用 `body_main()` 或 `bldc_init()` / `bldc_step()` 的 JNA 入口。所有通过主循环或 BLDC 中断触发的代码路径因此全部未覆盖。

---

## 三、e2e 桩库存与去桩化状态

### 3.1 编译模型

#### Panda 固件

```
libpanda.c (2026-07-31 现状):
  #include "board/main.c"                    ← ✅ 完整固件
  #include "board/drivers/fan.h"             ← ✅ 真实代码 (100%)
  ...
  #include "board/drivers/clock_source.h"    ← ✅ 真实代码 (100%)
  #include "board/drivers/simple_watchdog.h" ← ✅ 真实代码 (100%)
  #include "board/libc.h"                    ← ✅ 真实代码 (83.9%)
  #include "board/drivers/registers.h"       ← ✅ 真实代码 (97.8%)
  #include "board/sys/faults.h"              ← ✅ 真实代码 (100%)
  #include "board/drivers/harness.h"         ← ✅ 真实代码 (90.0%, harness_init 未在 e2e 调用)
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

#### Body 固件

```
libpanda_body.c (Phase L, 2026-08-01):
  #include "fake_stm.h"                       ← ⚠️ e2e 桩 (共享 CMSIS 类型)
  #include "stm32h7xx.h"                      ← ⚠️ e2e 桩 (UID_BASE, FDCAN_BASE, CMSIS 类型)
  #include "config.h"                         ← ✅ 真实代码 (构建配置)
  #include "board/stm32h7/stm32h7_config.h"   ← ⚠️ e2e 桩 (CMSIS 切断 + include 转发)
  #include "fdcan_regs.h"                     ← ⚠️ e2e 桩 (FDCAN 寄存器类型)
  #include "board/drivers/gpio.h"             ← ✅ 真实代码 (84.5%)
  #include "board/body/boards/board_declarations.h" ← ✅ 真实代码 (body 引脚/HW_TYPE_BODY 宏定义)
  #include "board/body/boards/board_body.h"   ← ✅ 真实代码 (board_body struct + board_body_init)
  #include "board/libc.h"                     ← ✅ 真实代码 (delay, memcpy)
  #include "board/drivers/led.h"              ← ✅ 真实代码 (PWM LED, 96.0%)
  #include "board/drivers/pwm.h"              ← ✅ 真实代码 (PWM 定时器, 82.2%)
  #include "board/stm32h7/llfdcan.h"          ← ✅ 真实代码 (FDCAN 寄存器, 83.2%)
  #include "board/drivers/fdcan.h"            ← ✅ 真实代码 (FDCAN 高层, 94.9%)
  #include "board/drivers/interrupts.h"       ← ✅ 真实代码 (中断处理, 96.2%)
  #include "board/stm32h7/lladc.h"            ← ⚠️ e2e 桩 (ADC 拦截)
  #include "board/body/bldc/bldc.h"           ← ✅ 兼容包装器 (Phase L: include 真实 BLDC_controller.h/.c/.data.c, 覆盖 ULONG_MAX 绕过 macOS LP64 检查)
  #include "board/body/main.c"                ← ✅ 完整 body 固件 (通过 #define BLDC_H 跳过真实 bldc.h)
```

> **BLDC 兼容包装器内部链**：`bldc.h` (e2e) → `#include <limits.h>` 抢占 guard → 覆盖 `ULONG_MAX`/`LONG_MAX` → `#include "board/body/bldc/BLDC_controller.h"` → `#include "board/body/bldc/BLDC_controller.c"` (3306 行 FOC) → `#include "board/body/bldc/BLDC_controller_data.c"` → 真实 `bldc_init()`/`bldc_step()` 实现。ulong_T 保持 64-bit（实际未被模型结构体使用），只覆盖了编译期字长检查宏。
> **未被包含的真实 body 文件**：`board/body/can.h`、`board/body/dotstar.h` 通过 `board/body/main.c` 的 `#include` 间接进入编译。`board/body/bldc/bldc_defs.h`、`board/body/bldc/rtwtypes.h` 仅含 `#define`/`typedef`，无可执行代码。

### 3.2 桩文件清单 (14 个, 9 已完成) 与去桩化评估

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
| **L** | e2e 桩 `board/body/bldc/bldc.h` (no-op) | **兼容包装器**：include `<limits.h>` + 覆盖 `ULONG_MAX`/`LONG_MAX` + 真实 `BLDC_controller.h/.c/.data.c` (3700 行 FOC) + 真实 `bldc_init()`/`bldc_step()` | 0% (新入, 待测试调用) |

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

### 4.3 Body 固件 — `board/body/main_comms.h` (3/9 已覆盖)

> `comms_control_handler()` 共有 9 个 case（不含 default），现有测试仅覆盖 3 个。`comms_endpoint2_write()`（空实现）也未覆盖。

| 命令 | 功能 | 状态 | Feature |
|------|------|------|---------|
| 0xb3 | 设置电机转速 | ✅ 已覆盖 | `body_commands.feature` |
| 0xb4 | 电机启停 | ✅ 已覆盖 | `body_commands.feature` |
| 0xc1 | 获取硬件类型 | ✅ 已覆盖 | `body_shared_commands.feature` |
| 0xd1 | 进入 bootloader / softloader | ❌ 未覆盖 | 含 2 个子分支 (param1=0 bootloader, param1=1 softloader, default) |
| 0xd3 | 签名字节 (offset=0, 64B) | ❌ 未覆盖 | 读取 `_app_start[0]` + offset 位置的前 64 字节 |
| 0xd4 | 签名字节 (offset=64, 64B) | ❌ 未覆盖 | 读取 `_app_start[0]` + offset 位置的后 64 字节 |
| 0xd6 | 固件版本 (`gitversion`) | ❌ 未覆盖 | 返回 18 字节 gitversion 字符串 |
| 0xd8 | 系统复位 (NVIC_SystemReset) | ❌ 未覆盖 | 直接触发 NVIC_SystemReset() |
| 0xdd | 数据包版本哈希 | ❌ 未覆盖 | 返回 `{HEALTH_PACKET_VERSION, CAN_PACKET_VERSION_HASH}` 8 字节 |

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

### 5.2 Body 固件主循环

Body 固件 (`board/body/main.c`) 的 `body_main()` 主循环为简单轮询模式（无 tick handler FSM），执行如下逻辑：

```
while (true) {
  充电中?  → motor_set_enable(false) + dotstar_apply_breathe(橙色)  ──→ dotstar_show()
  点火中?  → dotstar_run_rainbow                                    ──→ dotstar_show()
  否则     → dotstar_apply_breathe(绿色)                             ──→ dotstar_show()
  点火中?  → motor_set_enable(true) + body_can_periodic()
  否则     → motor_set_enable(false)
}
```

**当前状态：全部未覆盖 (0%)**。`libpanda_body.c` 仅提供 `jna_body_control_write()` / `jna_body_get_*()` 入口，未提供调用 `body_main()` 的 JNA 入口。

| 代码路径 | 所在文件 | 说明 |
|---------|---------|------|
| `body_main()` 主循环 | `board/body/main.c:89-144` | 初始化序列（中断/时钟/USB/CAN/DotStar/BLDC）+ while(true) 轮询。未执行 |
| `tick_handler()` | `board/body/main.c:50-61` | CAN 健康检查（`transmit_error_cnt >= 128` → `llcan_init`）+ LED 翻转 + `tick_count++`。未覆盖 |
| `exti15_10_handler()` | `board/body/main.c:63-87` | 充电检测（`CHARGING_DETECT_PIN` 边沿）+ 点火消抖（200ms 防抖 → 翻转 ignition → GPIO 输出）。未覆盖 |
| `bldc_tim8_handler()` | `board/body/main.c:43-48` | TIM8 更新中断 → `bldc_step()`（BLDC 电机一步）。e2e 桩为 no-op。未覆盖 |
| `enable_fpu()` | `board/body/main.c:34-36` | FPU 使能（`SCB->CPACR`），body 专用。未覆盖 |
| `__initialize_hardware_early()` | `board/body/main.c:38-41` | 调用 `enable_fpu()` + `early_initialization()`。未覆盖 |
| `debug_ring_callback()` | `board/body/main.c:27-32` | UART 调试回环（`get_char` → `injectc`）。未覆盖 |
| `dotstar_run_rainbow()` | `board/body/dotstar.h:164-179` | 彩虹效果（HSV 颜色轮 + 呼吸亮度）。仅通过 `body_main()` 调用的 body 专用函数。未覆盖 |
| `dotstar_apply_breathe()` | `board/body/dotstar.h:181-210` | 呼吸效果（线性三角波亮度）。未覆盖 |
| `body_can_periodic()` | `board/body/can.h:91-118` | 周期 CAN 发送（10ms 间隔）：电机转速帧 + 变量值帧 + 电池数据帧 + 0x222 v2 ID 帧。仅通过 `body_main()` 调用。未覆盖 |
| `body_can_init()` | `board/body/can.h:82-89` | CAN 初始化（safety hooks + CAN transceiver + can_init_all）。仅通过 `body_main()` 调用。未覆盖 |
| `board_body_init()` | `board/body/boards/board_body.h:3-40` | GPIO/CAN 引脚/EXTI 中断/电源初始化。仅通过 `body_main()` → `current_board->init()` 调用。未覆盖 |

> **可覆盖路径**：若要覆盖上述代码，需要在 `libpanda_body.c` 中新增 `jna_body_main_init()` / `jna_body_main_tick()` 等 JNA 入口，在测试中按需调用 `body_main()` 的初始化序列和主循环片段。中断处理函数可通过 `REGISTER_INTERRUPT` → 手动触发中断号来覆盖。

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
Phase J 后: **92.9%** (2304/2479, ~40 files) ← 最新 ✅
Phase K 后: **79.4%** (2371/2985, 48 files) ← body 合并后
```

> **注**：Phase K 合并 body 固件覆盖率后，分母增加了 ~506 行新文件（`board/body/main.c`、`board/body/main_comms.h`、`board/body/can.h`、`board/body/dotstar.h` 等），导致百分比下降。分子从 2304 提升至 2371（+67 行覆盖），但分母从 2479 增至 2985（+506 行新入覆盖率的代码）
> **Phase L 去桩化后**：分母进一步增加 ~3700 行 BLDC 控制器代码（`BLDC_controller.c` 3306 行 + `BLDC_controller_data.c` 380 行 + `bldc.h` 310 行），覆盖率将进一步下降。

### 第六阶段：Body 固件可补测试缺口分析 (2026-08-01)

基于 §2.2 和 §5.2 的 body 固件覆盖率分析，逐文件列出可补测试点。所有 body 测试都通过 `jna_body_*` JNA 入口调用 C 代码。

#### 6.1 可直接补端到端测试 ✅

| # | 优先级 | 文件 | 未覆盖内容 | 测试方案 |
|---|--------|------|-----------|---------|
| B1 | 🔴 高 | `main_comms.h` | 0xd6 固件版本 (18B gitversion) | `jna_body_control_write(0xd6, 0, 0)` → 验证返回 19 字节 gitversion 字符串 |
| B2 | 🔴 高 | `main_comms.h` | 0xdd 数据包版本 (8B) | `jna_body_control_write(0xdd, 0, 0)` → 验证返回 `{HEALTH_PACKET_VERSION, CAN_PACKET_VERSION_HASH}` |
| B3 | 🟡 中 | `main_comms.h` | 0xd8 系统复位 | `jna_body_control_write(0xd8, 0, 0)` → 验证 `NVIC_SystemReset()` 被调用（NVIC 计数器归零） |
| B4 | 🟡 中 | `main_comms.h` | 0xd3 签名 (offset=0) | `jna_body_control_write(0xd3, 0, 0)` → 验证返回前 64 字节 |
| B5 | 🟡 中 | `main_comms.h` | 0xd4 签名 (offset=64) | `jna_body_control_write(0xd4, 0, 0)` → 验证返回后 64 字节 |
| B6 | 🟢 低 | `main_comms.h` | 0xd1 bootloader 模式 (param1=0) | `jna_body_control_write(0xd1, 0, 0)` → 验证 `enter_bootloader_mode = ENTER_BOOTLOADER_MAGIC` |
| B7 | 🟢 低 | `main_comms.h` | 0xd1 softloader 模式 (param1=1) | `jna_body_control_write(0xd1, 1, 0)` → 验证 `enter_bootloader_mode = ENTER_SOFTLOADER_MAGIC` |

> B1-B2 最优先：只需在 `body_shared_commands.feature` 中新增 2 个场景，覆盖 `main_comms.h` 中 2 个常用命令。

#### 6.2 需新增 JNA 入口后可补 ⚙️

这些代码需要先修改 `libpanda_body.c` / `BodyPandaClient.java` 新增 JNA 入口：

| # | 优先级 | 文件 | 未覆盖内容 | 所需 JNA 入口 | 测试方案 |
|---|--------|------|-----------|--------------|---------|
| B8 | 🔴 高 | `body/bldc/bldc.h` | `bldc_init()` (Simulink 模型初始化 + TIM PWM + hall GPIO) | `jna_bldc_init()` | 调用 `bldc_init()` → 验证 `rtM_Left->defaultParam` 非 NULL、`LEFT_TIM->CR1` 已设置 `CEN` |
| B9 | 🔴 高 | `body/bldc/bldc.h` + `BLDC_controller.c` | `bldc_step()` → `BLDC_controller_step()` (3306 行 FOC 算法) | `jna_bldc_init()` + `jna_bldc_step()` | 先 `bldc_init()`，设置 `rpm_left=100` / `rpm_right=200`，循环调用 `bldc_step()` ×2000 (跳过 ADC 校准) → 验证 `rtY_Left.DC_phaA/B/C` 和 `LEFT_TIM->CCR1/2/3` 有 PWM 输出 |
| B10 | 🟡 中 | `body/dotstar.h` | `dotstar_init()` + `dotstar_show()` + `dotstar_fill()` + `dotstar_set_pixel()` + `dotstar_set_global_brightness()` | `jna_dotstar_init()` + `jna_dotstar_fill()` + `jna_dotstar_show()` + `jna_dotstar_get_pixel()` | 调用 `dotstar_init()` → 验证 `dotstar_state.initialized=true`。`dotstar_fill(r,g,b)` → `dotstar_show()` → 读取 `dotstar_state.pixels[0-9]` 验证颜色 |
| B11 | 🟡 中 | `body/dotstar.h` | `dotstar_run_rainbow()` (HSV 彩虹 + 呼吸亮度) | `jna_dotstar_init()` + `jna_dotstar_run_rainbow()` + `jna_dotstar_get_pixel()` / `jna_dotstar_get_brightness()` | `dotstar_init()` + `dotstar_run_rainbow(t_us)` → 读取 `dotstar_state.global_brightness` 和 `pixels[0]` 颜色，验证非零 |
| B12 | 🟡 中 | `body/dotstar.h` | `dotstar_apply_breathe()` (三角波呼吸效果) | `jna_dotstar_init()` + `jna_dotstar_apply_breathe()` + `jna_dotstar_get_pixel()` | `dotstar_init()` + `dotstar_apply_breathe({r,g,b}, t_us, cycle_us)` → 验证像素颜色随 phase 变化 |
| B13 | 🔴 高 | `body/can.h` | `body_can_init()` (safety hooks + CAN transceiver + can_init_all) | `jna_body_can_init()` | 调用 `body_can_init()` → 验证 `can_silent=false`, `can_loopback=false`, safety hooks 已设置 |
| B14 | 🟡 中 | `body/can.h` | `body_can_send_motor_speeds()` + `body_can_send_var_values()` + `body_can_send_body_data()` + 0x222 v2 ID | `jna_body_can_periodic()` 或单独 JNA 入口 | 先 `body_can_init()`，然后调用各发送函数 → 通过 `can_pop_tx_buffer()` 读取 CAN TX 队列，验证帧 ID/数据 |
| B15 | 🟡 中 | `body/can.h` | `body_can_rx()` → `body_can_process_target()` (CAN RX 电机目标解析) | `jna_body_can_rx()` | 构造 0x250 CAN 帧 `{left_hi, left_lo, right_hi, right_lo}` → 调用 `body_can_rx(&msg)` → 验证 `rpm_left`/`rpm_right` 正确解析 |
| B16 | 🟡 中 | `body/can.h` | `body_can_periodic()` 超时逻辑 (`BODY_CAN_CMD_TIMEOUT_US`) | `jna_body_can_init()` + `jna_body_can_periodic()` + `jna_set_microsecond_timer()` | 设置 `rpm_left=100` + `last_can_cmd_timestamp_us` 为旧值 → `body_can_periodic(now, ...)` 当 `now - last > 100ms` → 验证 `rpm_left=0` (超时归零) |
| B17 | 🟢 低 | `body/can.h` | `body_can_periodic()` 周期发送 (10ms 间隔) | `jna_body_can_periodic()` + `jna_get_microsecond_timer()` | `body_can_init()` → 连续 2 次 `body_can_periodic()` 相隔 < 10ms → 第一次发送，第二次跳过；相隔 ≥ 10ms → 两次都发送 |
| B18 | 🟡 中 | `body/main.c` | `tick_handler()` (CAN 健康检查 + LED 翻转 + tick_count) | `jna_call_body_tick_handler()` | 设置 `can_health[0].transmit_error_cnt = 128` → 调用 `tick_handler()` → 验证 `llcan_init(CANIF_FROM_CAN_NUM(0))` 被调用 + `tick_count++` |
| B19 | 🟡 中 | `body/main.c` | `exti15_10_handler()` 点火消抖 (200ms 防抖) | `jna_trigger_exti15_10()` + `jna_get_ignition_state()` + `jna_set_gpio_input()` | 模拟 `CHARGING_DETECT_PIN` / `IGNITION_SW_PIN` GPIO 电平变化 → 触发 EXTI15_10 IRQ → 验证 `ignition` 状态翻转和 `OBDC_IGNITION_ON_PIN` 输出 |
| B20 | 🟡 中 | `body/main.c` | `bldc_tim8_handler()` → `bldc_step()` | `jna_bldc_init()` + `jna_trigger_tim8_irq()` | `bldc_init()` 后设置 `LEFT_TIM->SR = TIM_SR_UIF` → 触发 TIM8_UP IRQ → `bldc_tim8_handler()` → `bldc_step()` → 验证 `rtY_Left.DC_phaA` 变化 |
| B21 | 🟢 低 | `body/boards/board_body.h` | `board_body_init()` (GPIO/CAN/EXTI/电源初始化) | `jna_board_body_init()` (或通过 `jna_body_main_init()`) | 调用 `board_body_init()` → 验证 `SYSCFG->EXTICR[3]`、`EXTI->IMR1`、`OBDC_POWER_ON_PORT` 等寄存器值 |

> B8-B9 最优先：BLDC 控制器 3700 行是最大的覆盖率缺口。只需 2 个新 JNA 入口 (`jna_bldc_init` + `jna_bldc_step`)，即可覆盖 `board/body/bldc/` 下全部核心代码。
> B13-B17 CAN 函数次优先：2-3 个 JNA 入口覆盖 `body/can.h` 全部 8 个函数。

#### 6.3 所需 JNA 入口汇总

| # | JNA 入口 | C 函数 | 覆盖文件 | 说明 |
|---|---------|--------|---------|------|
| J1 | `jna_bldc_init()` | `bldc_init()` | `bldc.h`, `BLDC_controller.c`, `BLDC_controller_data.c` | 模型初始化，一次性覆盖 ~500 行 |
| J2 | `jna_bldc_step()` | `bldc_step()` | `bldc.h`, `BLDC_controller.c` | FOC 一步，需先调 `bldc_init()` + 跳过 2000 次校准 |
| J3 | `jna_body_can_init()` | `body_can_init()` | `body/can.h` | CAN 初始化 |
| J4 | `jna_body_can_periodic(now, ignition, charging)` | `body_can_periodic()` | `body/can.h` | CAN 周期发送 + 超时检查 |
| J5 | `jna_body_can_rx(msg)` | `body_can_rx()` | `body/can.h` | CAN 帧接收 |
| J6 | `jna_dotstar_init()` | `dotstar_init()` | `body/dotstar.h` | LED 初始化 |
| J7 | `jna_dotstar_show()` | `dotstar_show()` | `body/dotstar.h` | 发送 SPI 帧到 LED |
| J8 | `jna_dotstar_get_pixel(idx)` | 读取 `dotstar_state.pixels[idx]` | `body/dotstar.h` | 验证颜色设置 |
| J9 | `jna_dotstar_get_brightness()` | 读取 `dotstar_state.global_brightness` | `body/dotstar.h` | 验证呼吸效果 |

> J1-J2 是核心入口，可以覆盖 BLDC 控制器的 `BLDC_controller_initialize()` + `BLDC_controller_step()` 两条路径。J3-J5 覆盖 body CAN 通信。J6-J9 覆盖 dotstar LED 驱动。

#### 6.4 不可补 / 暂不推荐补 ❌

| 类别 | 行数 | 文件 | 原因 |
|------|------|------|------|
| `body_main()` while(true) 无限循环 | ~55 | `body/main.c:122-143` | e2e 无法执行无限循环，但循环体内的函数可通过单独 JNA 入口覆盖（见 B9-B17） |
| `body_main()` 硬件启动序列 | ~33 | `body/main.c:89-121` | 中断/时钟/USB 初始化依赖硬件外设；但 `enable_fpu()` (2 行) 可通过 `jna_enable_fpu` 入口覆盖 |
| `debug_ring_callback()` | 5 | `body/main.c:27-32` | UART 调试回环，非核心功能 |
| `NVIC_SystemReset()` 触发路径 | 2 | `main_comms.h` 0xd1/0xd8 | `NVIC_SystemReset()` 是 e2e 桩 (no-op)，调用后无法验证真实行为；但可通过验证调用计数间接测试 |
| BLDC Simulink 查表数据 | ~600 | `BLDC_controller_data.c` (rtConstP 表) | 常量数据无执行路径，仅通过 `bldc_init()` 引用时产生隐式覆盖 |

#### 6.5 覆盖率预估

```
当前 body 覆盖率:    ~6%  (仅 main_comms.h 的 3/9 case)
B1-B7 完成后 (USB):  ~15% (main_comms.h → ~90%)
B8-B9 完成后 (BLDC): ~45% (+3700 行 BLDC 控制器)
B10-B12 完成后 (LED): ~52% (+dotstar.h)
B13-B17 完成后 (CAN): ~65% (+can.h)
B18-B21 完成后:       ~75% (+main.c 中断 + board_body.h)
```

---


## 七、其他固件目标

panda 代码库从同一 `board/` 目录构建三个独立固件，e2e 当前仅覆盖 panda 主固件和 body 固件：

```
board/main.c          → panda 固件    ✅ e2e 覆盖
board/bootstub.c      → bootstub      ❌ 无 e2e (3 文件)
board/jungle/main.c   → jungle 固件   ❌ 无 e2e (6 文件)
board/body/main.c     → body 固件     ✅ e2e 覆盖 (Phase K, libpanda_body.dylib)
board/crypto/         → 加密库        ❌ bootstub 专用 (4 文件)
```

### Body 固件 e2e 详情

Body 固件通过独立的 `libpanda_body.c` → `libpanda_body.dylib` 编译链实现 e2e 覆盖：

- **C 入口**：`e2e-tests/src/test/c/libpanda_body.c`（独立于 panda 的 `libpanda.c`）
- **关键桩**：`board/body/bldc/bldc.h`（Phase L 兼容包装器，include 真实 BLDC_controller.c/.data.c）、`stm32h7xx.h`（CMSIS 最小桩）、`fake_stm.h`（共享 GPIO/TIM 类型）
- **BodyPandaClient**：`reloadLibrary()` 每场景重新加载 dylib（仿 PandaClient 模式）
- **Step 定义**：`BodyCommandsStepDefs` 使用 jfactory + DAL 模式（`When body control write:` / `Then body control data should be:`）
- **覆盖命令**：0xb3（电机转速）、0xb4（电机启停）、0xc1（硬件类型）、0xd6（固件版本）、0xdd（数据包版本哈希）
- **Feature 文件**：`body_commands.feature`（5 场景）+ `body_shared_commands.feature`（1 场景），均带 `@body` 标签

---

## 八、CMSIS/HAL 头文件与工具脚本

以下不计入覆盖率：STM32 官方 CMSIS 头文件（`core_cm7.h`、`stm32h7xx.h` 等 12 个）、Python 工具（`flash.py`、`recover.py`）、未被引用的文件（`llflash.h`、`lli2c.h`）。

---

## 九、测试设计审视

### 9.1 非端到端功能测试合并

从 52 个 feature 合并至 38 个（net -14），覆盖率无损。合并类别：

| 类别 | 减少 | 目标文件 |
|------|------|---------|
| 纯重复 | 1 | `microsecond_timer` → 已删除 |
| 单一数据读取 | 8 | → `spi_version_packet`、`health`、`fdcan_interrupt`、`spi_state_machine` |
| 内部实现细节 | 6 | → `can_comms`、`clock_source`、`tick_paths`、`spi_state_machine`、`safety_mode` |
| 单一控制写入 | 5 | → `can_fd_data_bitrate`、`system_reset_bootloader` |

保留的 33 个真正端到端 feature（完整多步骤工作流）：CAN 通信协议（4）、CAN 配置（3）、安全模式（1）、心跳超时（2）、电源管理（3）、SPI 协议（2）、故障处理（2）、CAN 中断（1）、中断处理（1）、设备控制（5）、tick 流程（2）、硬件检测（2）、启动流程（1）、其他（3）。

### 9.2 非端到端 When 步骤

共 20 个非 E2E When 步骤（直接 JNA 调用内部函数/操作内部数据结构），分析结论：
- **60%** 有 E2E 等价路径，但保留 JNA 调用以测试边界条件（队列回绕、FIFO 满等）
- **30%** 是硬件初始化/主循环路径，e2e 无主循环，必须 JNA 调用
- **10%** 完全无法被 E2E 覆盖（`fault_recovered` 无公开 API、FDCAN IR 硬件标志、red `unused_set_fan_enabled` 被 `has_fan=false` 跳过）
## 十、Phase J: 可补端到端测试缺口分析 (2026-07-30)

基于 `e2e-tests/build/coverage/merged.lcov` (91.2%, 2259/2478, 40 files)，逐个分析未覆盖行的可测试性。

### 10.1 可直接补端到端测试 ✅ 已全部完成 (9/9, +34 lines)

| # | 状态 | 文件 | 行号 | 未覆盖内容 | 实现 |
|---|------|------|------|-----------|------|
| J1 | ✅ | `gpio.h` | 42-43 | `OUTPUT_TYPE_PUSH_PULL` (else 分支) | `gpio_harness.feature`: PUSH_PULL 清除 OTYPER bit3 |
| J2 | ✅ | `harness.h` | 104-118 | `harness_init()` 整函数 | `gpio_harness.feature`: 验证 gpioaOtyper=520, gpioaOdr=520 |
| J3 | ✅ | `fdcan.h` | 109-110 | `total_tx_checksum_error_cnt` 递增 | `fdcan_interrupt.feature`: can_push_direct (无 checksum) + process_can |
| J4 | ✅ | `fdcan.h` | 227-234 | FDCAN1/2/3 全部 6 个静态 IRQ 包装器 | `fdcan_interrupt.feature`: handle interrupt 19/21/20/22/159/160 |
| J5 | ✅ | `uart.h` | 71-72, 93-94 | put_char + injectc overwrite (r_ptr 前移) | `uart_overwrite.feature`: uartTxRPtr=2, uartRxRPtr=2 |
| J6 | ✅ | `interrupts.h` | 53-54 | 中断频率超标 print | `interrupt_rate.feature`: 11 次 IRQ + interrupt_timer_tick → print |
| J7 | ✅ | `llfdcan.h` | 73-74 | `prescaler = BITRATE_PRESCALER * 16` (speed < 2500) | `can_bitrate.feature`: 0xde param2=1000 (100kbps) |
| J8 | ✅ | `main_comms.h` | 239-241 | `0xde` 命令中 `can_init()` 调用 | `can_bitrate.feature`: 修复 param2: 0→5000 |
| J9 | ✅ | `llfdcan.h` | 87 | `CAN_SP_DATA_5M` (data_speed=50000) | `can_fd_data_bitrate.feature`: 0xf9 param2=-15536 (5Mbps) |

### 10.2 有条件可补 — 全部完成 (5/5, +45 lines)

| # | 状态 | 文件 | 行号 | 未覆盖内容 | 障碍 |
|---|------|------|------|-----------|------|
| J10 | ✅ | `gpio.h` | 93-101 | `detect_with_pull()` | `gpio_harness.feature`: JNA 直接调用 `detect_with_pull(GPIOF, 7, PULL_UP)` |
| J11 | ✅ | `can_health_pkt.h` | 29-30 | `last_data_stored_error` | `can_health.feature`: `ControlSetup: {fdcanPsr: 256}` 设置 DLEC=1 |
| J12 | ✅ | `pwm.h` | 23-26 | `pwm_init` channel 4 | 已被现有 @tres `board_init` 测试覆盖 (`pwm_init(TIM3, 4)`) |
| J13 | ✅ | `spi.h` | 88-95 | `spi_init()` | `spi_state_machine.feature`: JNA 直接调用 `spi_init()`，验证状态机初始化为 HEADER |
| J14 | ✅ | `power_saving.h` | 39 | `llcan_irq_enable(cans[0])` (flipped harness) | `power_save.feature`: flipped harness → 开省电 → 关省电，覆盖 disable 路径的 cans[0] 分支 |

### 10.3 不可补 (❌ No, ~165 lines)

硬件依赖、编译条件或架构限制。

| 类别 | 行数 | 代表性文件 | 原因 |
|------|------|-----------|------|
| `main()` 函数 + 启动初始化 | 81 | `main.c:270-389` | e2e 无主循环，硬件启动序列 |
| LL 超时/错误路径 | 19 | `llfdcan.h:18-25,40-47,115-118` | 依赖真实硬件时序的超时和 print |
| 硬件地址/寄存器直接访问 | ~~7~~→3 | ~~`main_comms.h:132-135` (MCU UID) ✅ 已覆盖~~, 剩余: `llfdcan.h` timeout print | `0xc3` USB 命令已在 e2e 中可用 |
| 调试/编译条件守卫 | 7 | `main_comms.h:101-107` (ALLOW_DEBUG), `registers.h:39` (DEBUG_FAULTS) | 编译期 `#ifdef` 守卫 |
| 死代码/不可达分支 | 10 | `pwm.h:27-28,53-54` (default 分支), `main_comms.h:332-336` (default handler) | 仅在无效输入时触发 |
| ~~系统复位/硬件崩溃~~ | ~~3→0~~ | ~~`power_saving.h:120-121` (NVIC_SystemReset)~~ ✅ J12c 已覆盖 | `enter_stop_mode()` ignition ON 路径通过 JNA 直接触发 |
| 忙等待/无限循环 | 10 | `libc.h:3-8,12-17` (delay, assert_fatal) | e2e 中无限循环导致超时 |
| ADC/电压读取 | 3 | `red.h:70-72` | 依赖 ADC 外设。~~`cuatro.h:28-34`~~ ✅ 已通过 ADC stub + 真实函数覆盖 |
| 预处理器宏定义 | 3 | `board_declarations.h:51`, `led.h:2`, `llfdcan_declarations.h:10` | `#define` 不被计入执行覆盖 |
| 未调用函数 | 4 | `unused_funcs.h:3-4`, `llfdcan_declarations.h:39` | `unused_init_bootloader` 从未被调用, FDCAN3 三元分支 |
| 板型默认分支 | 8 | `boards/{cuatro,tres,red}.h` default cases | switch-default 路径在不合法输入时 |
| 防御性 print | 5 | `spi.h:156-157,172-173`, `fdcan.h` | DEBUG 日志，正常流程不触发 |

### 10.4 最终结果 (Phase J 基线)

```
初始基线:  91.2% (2259/2478, 40 files)
Phase J 后: 92.9% (2304/2479, 40 files, +45 lines covered)

逐文件提升:
  harness.h:        90.0% → 100.0% (+7, J2 harness_init)
  gpio.h:            87.5% → 100.0% (+9, J1 PUSH_PULL + J10 detect_with_pull)
  uart.h:            97.4% → 100.0% (+2, J5 injectc overwrite)
  interrupts.h:     96.2% → 100.0% (+2, J6 rate print)
  fdcan.h:           98.7% → 100.0% (+2, J3 checksum + J4 FDCAN1/2/3 handlers)
  main_comms.h:     94.1% →  97.0% (+8, J8 0xde fix + 0xc3 MCU UID)
  llfdcan.h:         83.2% →  85.1% (+3, J7 low speed + J9 5M)
  llfdcan_declarations.h: 91.3% → 95.7% (+1, J9 side effect)

100% 文件新增: harness.h, gpio.h, uart.h, interrupts.h, fdcan.h

剩余不可覆盖 (~158 lines):
  main() 启动序列 (81 lines), llfdcan timeout (24 lines), libc delay/assert (10 lines),
  pwm default 分支 (8 lines), 板型 ADC/default (11 lines), 宏定义/防御 print (19 lines)
```

### 10.5 Phase J 补充 (J11-J14 + J12b-J12c)

J11-J14 + J12b-J12c 在 Phase J 之后补充完成，新增覆盖：

```
J11 can_health_pkt.h:  +2 lines (last_data_stored_error via DLEC=1)
J12 pwm.h:             已覆盖  (existing @tres board_init → pwm_init(TIM3, 4))
J12b pwm.h:            +8 lines (pwm_init channel 3, llfan stub path, @tres JNA)
J12c power_saving.h:   +1 line  (NVIC_SystemReset at L120, enter_stop_mode ignition ON)
J13 spi.h:             +8 lines (spi_init path, llspi_init + llspi_mosi_dma)
J14 power_saving.h:    +1 line  (llcan_irq_enable(cans[0]) flipped harness disable)
```

新增测试文件改动：
- `libpanda.c`: +20 lines (J11 `jna_get_can_health_last_data_stored_error`, J13 `jna_spi_init`, J12b `jna_pwm_init_channel_3`, J12c `jna_enter_stop_mode_ignition_on`)
- `PandaClient.java`: +25 lines (J11 `lastDataStoredError`, J13 `spiInit()`, J12b `pwmInitChannel3()`, J12c `enterStopModeIgnitionOn()`, `resetNvicCount()`)
- `PandaSteps.java`: +20 lines (J13 `spi init`, J12b `pwm init channel 3`, J12c `enter stop mode with ignition on`, `reset nvic count`)
- `can_health.feature`: +16 lines (J11 DLEC scenario)
- `spi_state_machine.feature`: +17 lines (J13 spi_init scenario)
- `power_save.feature`: +30 lines (J14 flipped harness disable scenario)
- `led_pwm.feature`: +16 lines (J12b pwm_init channel 3 scenario)
- `deep_sleep.feature`: +30 lines (J12c ignition ON NVIC_SystemReset scenario)

### 10.6 需关注的回退

以下文件覆盖率较上次记录下降：

| 文件 | 上次 | 当前 | 变化 | 原因 |
|------|------|------|------|------|
| `harness.h` | 100% (70/70) | 90.0% (63/70) | -7 | `run_all_coverage.sh` 不再将 `harness.h` 从 ignore regex 排除，`harness_init()` 仅在 `main.c` 中调用，e2e 不执行 main() |
| `unused_funcs.h` | 100% (23/23) | 91.3% (21/23) | -2 | `unused_init_bootloader` 函数体 (空函数) 在合并多板 LCOV 后显式为未覆盖 |
| `drivers.h` | 80.0% (4/5) | 100% (5/5) | +1 | ✅ 提升 |

### 10.7 Phase K: Body 固件 e2e 支持 (2026-07-31)

新增独立 body 固件 e2e 测试环境：

| 文件 | 变更 |
|------|------|
| `libpanda_body.c` (+270 lines) | 新 body C 入口：假寄存器（GPIO/ADC/FDCAN/TIM1/TIM8）+ JNA 访问器 |
| `fake_stm.h` (+15 lines) | +TIM_CR1_CMS_0, TIM_SR_UIF, TIM_CCER_CC1NE, EXTI15_10_IRQn, FDCAN IRQn, GPIO_OSPEEDR_OSPEED5, CORE_FREQ |
| `stm32h7xx.h` (+32 lines) | 最小 CMSIS 桩（UID_BASE, FDCAN_BASE） |
| `build.sh` (+20 lines) | +body 目标（-DPANDA_BODY, -I board/body/, -DHEALTH_PACKET_VERSION 等） |
| `board/body/bldc/bldc.h` (+70 lines) | BLDC Simulink 桩（跳过 macOS LP64 字长检查）→ **Phase L 升级为兼容包装器** |
| `BodyPandaClient.java` (+80 lines) | JNA 接口 + reloadLibrary() + DAL 访问器 |
| `BodyCommandsStepDefs.java` (+50 lines) | jfactory + expect().should() 模式 |
| `BodyUsbControlRequests.java` (+75 lines) | 5 个 body spec（SetMotorSpeed, SetMotorEnable 等） |
| `body_commands.feature` | 5 场景：0xb3/0xb4 电机命令 |
| `body_shared_commands.feature` | 1 场景：0xc1 硬件类型 |
| `run_all_coverage.sh` (+10 lines) | +body 构建/测试/合并 |

**架构差异**：Body 使用独立 `libpanda_body.c`（非 `libpanda.c`）和 `-DPANDA_BODY` 编译 `board/body/main.c`，因为 body 依赖 BLDC 电机、DotStar LED 等 panda 没有的外设。

### 10.8 Phase L: BLDC 控制器去桩化 (2026-08-01)

将 `board/body/bldc/` 下的 no-op e2e 桩替换为包含真实 Simulink 自动代码的兼容包装器，约 3700 行 FOC 矢量控制器代码新进入覆盖率。

**LP64 兼容技术**：macOS (LP64) 的 `unsigned long` 为 64 位，而 Simulink 模型为 ARM Cortex-M (ILP32) 生成。解决方案：
1. 在 e2e `bldc.h` 中先 `#include <limits.h>` 抢占 `BLDC_controller.c` 的 `#ifndef UCHAR_MAX` guard
2. 然后 `#undef ULONG_MAX` / `#undef LONG_MAX`，重定义为 ILP32 值
3. 再 include 真实的 `BLDC_controller.h/.c/.data.c` — `#if` 字长检查通过
4. `ulong_T` 保持 64-bit（实际未被模型结构体使用）

| 文件 | 变更 |
|------|------|
| `bldc.h` (e2e) | no-op 桩 (74 lines) → 兼容包装器 (365 lines): include 真实 BLDC_controller.h/.c/.data.c + 真实 `bldc_init()`/`bldc_step()` |
| `libpanda_body.c` | 移除重复的 `batt_voltage_raw`/`batt_percentage` 定义（现在由 bldc.h 定义） |
| `run_all_coverage.sh` | `IGNORE_REGEX` 移除 `bldc/bldc\.h`，释放 BLDC 文件进入覆盖率 |
| `uncovered-features.md` | §1.2 body 文件 6→10 个, §2.2 新增 BLDC 覆盖表, §3.3 新增 Phase L 去桩化 |

**新入覆盖率的文件**：`board/body/bldc/bldc.h`、`BLDC_controller.h`、`BLDC_controller.c` (3306 行)、`BLDC_controller_data.c`。dylib 从 ~200KB → ~569KB。现有 6 个 @body 场景全部通过 ✅。BLDC 代码当前覆盖率 0%，需新增 JNA 入口调用 `bldc_init()`/`bldc_step()` 来产生覆盖。

---
