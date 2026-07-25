# 端到端测试未覆盖功能清单

> 生成时间: 2026-07-25
> 基准 e2e 场景数: 142（覆盖 `board/main.c` → 34 个 USB 命令中 33 个）
> 综合行覆盖率: **65.1%** (575/884 lines), 函数覆盖率: **65.2%** (30/46 functions)
> 数据来源: `e2e-tests/run_all_coverage.sh` (cuatro + tres + red 合并)

---

## 覆盖率总览

| 源文件 | 行覆盖 | 函数覆盖 | 未覆盖原因 |
|--------|--------|---------|-----------|
| `board/main_comms.h` | 93.3% | 2/3 | `spi_cmd` 函数 (SPI 通道, 非 USB 路径) |
| `board/main.c` | 46.9% | 4/7 | 主循环 tick 路径 (ignition_can_cnt), check_registers, WFI 空闲 |
| `board/drivers/can_common.h` | 86.8% | 10/12 | can_clear_rx 未遍历路径, can_set_speed 未遍历比特率 |
| `board/drivers/gpio.h` | 72.1% | 5/7 | set_gpio_analog, restore_gpio 仅 deep_sleep 覆盖 |
| `board/sys/faults.h` | 78.9% | 2/2 | `fault_occurred` Temporary fault 路径已由 watchdog 覆盖 |
| `board/libc.h` | 60.7% | 3/5 | memset/memcpy 大量路径 |
| `board/drivers/fan.h` | 37.0% | 2/3 | fan cooldown 逻辑 (P8) |
| `board/can_comms.h` | 18.4% | 2/4 | CAN 接收/发送内层路径 |
| `board/drivers/clock_source.h` | 18.4% | 1/2 | TIM8 外部时钟模式未覆盖 |
| `board/utils.h` | 0.0% | 0/1 | 仅初始化调用, 未在测试路径中 |
| `board/boards/board_declarations.h` | — | — | 头文件 (宏/声明) |
| `board/sys/sys.h` | — | — | 头文件 (声明) |

---

## 一、USB 命令覆盖状态

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

## 二、`board/main.c` 主循环行为

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
- **状态：** ❌ 无测试

### 🟡 中优先级（状态变量 / 辅助路径）

#### P6 — WFI 空闲路径

```
文件: board/main.c:377-385
```

- CUATRO `enter_stop_mode()` ✅ 已覆盖
- 非 CUATRO 的 `__WFI()` 空闲路径 ❌ 未覆盖

#### P7 — `ignition_can_cnt` / `ignition_can` 自动复位

```
文件: board/main.c:251-253
```

- CAN 流量停止 2 秒后 `ignition_can = false`
- **状态：** ❌ 无测试

#### P8 — `fan_state.cooldown_counter` 冷却保持

- 风扇断电后继续运行 `cooldown_time * 8` 个 tick
- **状态：** ❌ 无测试

#### P9 — `harness_detect_orientation()` 线束翻转检测

```
文件: board/drivers/harness.h:52-88
```

- SBU ADC 电压检测逻辑
- **状态：** ⚠️ implicit（其他测试依赖 `harness.status`，但未直接测试翻转检测路径）

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

## 三、权限状态总结

| 优先级 | 项目 | 代码文件 | 覆盖状态 | 工作量估算 |
|--------|------|---------|----------|-----------|
| **P1** | `bootkick_tick()` FSM | `board/drivers/bootkick.h` | ✅ feature 已有 (`bootkick.feature`，14 场景) + 设计文档 (`bootkick.md`)，全部通过，通过 `jna_tick_handler` 调用真实代码 | — |
| **P2** | 心跳丢失自动行为 | `board/main.c:185-244` | ✅ `heartbeat_loss.feature` (9 场景)，全部通过，通过 `jna_call_tick_handler` 调用真实生产代码 | — |
| **P3** | `simple_watchdog` 看门狗 | `board/drivers/simple_watchdog.h` | ✅ `watchdog.feature` (3 场景)，直接 include 生产代码 | — |
| **P4** | `relay_malfunction` 故障检测 | `board/main.c:134-141` | ✅ feature 已有 (`relay_malfunction.feature`，3 场景) + 设计文档 (`relay-malfunction.md`) | — |
| **P5** | `check_registers()` | `board/drivers/registers.h` | ❌ 无测试 | 小 |
| **P6** | WFI 空闲路径 | `board/main.c:377-385` | ❌ 未覆盖 | 小 |
| **P7** | `ignition_can_cnt` 复位 | `board/main.c:251-253` | ❌ 未覆盖 (lines 189-195) | 小 |
| **P8** | `fan_state.cooldown` | `board/drivers/fan.h` | ❌ fan.h 仅 37.0% 覆盖 | 小 |
| **P9** | `harness_detect_orientation` | `board/drivers/harness.h:52-88` | ⚠️ implicit（其他测试依赖 `harness.status`，但未直接测试翻转检测路径） | 小 |
| **P10** | LED 行为 | `board/main.c:166-375` | ❌ 不需要 | — |
| **P11** | `sound_tick()` 音频 | `board/stm32h7/sound.h` | ❌ 不需要 | — |
| **P12** | `safety_mode_cnt` | `board/main.c` | ❌ 不需要 | — |
| — | Flasher 命令 (3 个) | `board/flasher.h` | ❌ 新 e2e 目标 | 大 |
| — | Jungle 命令 (8 个) | `board/jungle/main_comms.h` | ❌ 新 e2e 目标 | 大 |
| — | Body 命令 (2 个) | `board/body/main_comms.h` | ❌ 新 e2e 目标 | 小 |

---

## 四、`jna_call_tick_handler()` — 生产代码 tick 触发

`When tick handler` 步骤触发完整的生产代码 `tick_handler()`（`board/main.c`），包含所有 8Hz 和 1Hz 逻辑。通过 `heartbeatDisabled` 控制心跳超时，可精确测试 tick 累积行为。

| 特性 | 状态 | 场景数 |
|------|------|--------|
| `bootkick.feature` | ✅ 14 场景全部通过 | 14 |
| `relay_malfunction.feature` | ✅ 3 场景 | 3 |
| `watchdog.feature` | ✅ 3 场景全部通过 | 3 |
| `heartbeat_loss.feature` | ✅ 9 场景全部通过 | 9 |

8 次 `jna_call_tick_handler()` 调用 = 1 次 1Hz tick（`loop_counter` 每 8 次归零）。
使用 `When call tick handler {int} times` 批量触发多个 tick。

```
Given exists data → 设置全局状态
When call tick handler N times → 触发生产代码 tick_handler() N 次
Then control data should be → 验证结果
```

适用于：心跳超时、controls_allowed 退出、watchdog、siren_countdown、ignition_can_cnt、fan cooldown 等所有需多 tick 累积的测试。
