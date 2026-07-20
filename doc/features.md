# Panda 项目功能与测试覆盖分析报告

> 生成时间: 2026-07-16 | 最后更新: 2026-07-20 (同步 E2E 测试场景)

---

## 一、项目概览

Panda 是 comma.ai 开发的开源汽车接口固件项目，基于 STM32H725 (ARM Cortex-M7)。

```
                    ┌──────────────────────────────────┐
                    │         Python Library            │
                    │  (python/__init__.py → Panda类)  │
                    ├──────────┬───────────────────────┤
                    │   USB    │         SPI           │
                    │ (usb.py) │       (spi.py)        │
                    └────┬─────┴──────────┬────────────┘
                         │                │
              ═══════════╪════════════════╪════════════
              ║  固件    │                │            ║
              ║  ┌───────┴────────────────┴─────────┐ ║
              ║  │     Control Protocol (main_comms) │ ║
              ║  ├─── CAN ───┬── Safety ──┬─ Health ─┤ ║
              ║  │  fdcan.h  │ safety.h   │ health.h │ ║
              ║  ├── Power ──┼── Harness ─┼─ Fan ────┤ ║
              ║  │ power.h   │ harness.h  │ fan.h    │ ║
              ║  ├── LED ────┼── Sound ───┼─ UART ───┤ ║
              ║  │ led.h     │ siren.h    │ uart.h   │ ║
              ║  └───────────┴────────────┴──────────┘ ║
              ║      Board Abstraction (cuatro/tres/red)║
              ╚═════════════════════════════════════════╝
```

三个固件构建目标：`panda` / `panda_jungle` / `body`

---

## 二、完整功能清单与测试覆盖

### 2.1 核心通信功能

| # | 功能 | 固件代码 | Python 接口 | 测试覆盖 | 测试类型 |
|---|------|---------|------------|---------|---------|
| 1 | **CAN 总线 (FDCAN)** | `board/drivers/fdcan.h`, `can_common.h` | `can_send()`, `can_recv()`, `can_send_many()` | ✅ 完整 | HITL: `4_can_loopback.py` (send/recv/latency/integrity/bulk), USB: `test_comms.py` |
| 2 | **CAN 速度配置** | `fdcan.h:can_set_speed()` | `set_can_speed_kbps()`, `set_can_data_speed_kbps()` | ✅ 隐式 | 在 loopback 测试中覆盖多种速率 (10-1000 kbps) |
| 3 | **CAN-FD 自动切换** | `fdcan.h` + 控制命令 | `set_canfd_auto()` | ❌ 无 | — |
| 4 | **CAN-FD 非 ISO 模式** | 控制命令 0xfc | `set_canfd_non_iso()` | ❌ 无 | — |
| 5 | **CAN 环回模式** | 控制命令 0xe5 | `set_can_loopback()` | ✅ 完整 | HITL: `3_usb.py:test_can_loopback`; E2E: `can_loopback.feature` (4 场景) |
| 6 | **USB 设备栈** | `board/drivers/usb.h`, `llusb.h` | (内部) | ✅ 隐式 | 所有 USB 连接的 HITL 测试依赖 USB |
| 7 | **SPI 通信 (SOM)** | `board/drivers/spi.h`, `llspi.h` | (内部) | ✅ 完整 | HITL: `5_spi.py` (协议版本/错误头/校验和/不存在端点) |
| 8 | **CAN 通信协议 (编解码)** | `board/can_comms.h` | `pack_can_buffer()`, `unpack_can_buffer()` | ✅ 完整 | USB: `test_comms.py` + `test_pandalib.py` |

### 2.2 安全与健康监控

| # | 功能 | 固件代码 | Python 接口 | 测试覆盖 | 测试类型 |
|---|------|---------|------------|---------|---------|
| 9 | **安全模型 (Safety)** | `opendbc/safety/safety.h`, `main.c:set_safety_mode()` | `set_safety_mode()` | ✅ 完整 | HITL: `6_safety.py`; E2E: `safety_mode.feature` (8 场景: SILENT/NOOUTPUT/ALLOUTPUT/ELM327/TOYOTA/非法回退/队列清理) |
| 10 | **安全模式切换** | `main.c` (SILENT/NOOUTPUT/ELM327/ALLOUTPUT + 车辆特定) | `set_safety_mode()` | ✅ 完整 | E2E: `safety_mode.feature` 覆盖全部切换路径 + 队列清理 + FDCAN 重初始化 |
| 11 | **OBD 多路复用** | 控制命令 0xdb | `set_obd()` | ❌ 无 | — |
| 12 | **心跳看门狗** | `main.c:tick_handler()` | `send_heartbeat()`, `set_heartbeat_disabled()` | ✅ 完整 | HITL: `2_health.py:test_heartbeat` |
| 13 | **健康数据包 (Health)** | `board/health.h`, `main_comms.h:get_health_pkt()` | `health()` | ✅ 部分 | HITL: `2_health.py:test_voltage` |
| 14 | **CAN 健康统计** | `fdcan.h:update_can_health_pkt()` | `can_health()` | ⚠️ 隐式 | conftest teardown 检查，无专项测试 |
| 15 | **故障检测系统** | `board/sys/faults.h`, `registers.h` | (health 中) | ⚠️ 隐式 | conftest teardown 检查 `faults==0` |
| 16 | **中断管理/速率限制** | `board/drivers/interrupts.h` | `get_interrupt_call_rate()` | ❌ 无 | — |
| 17 | **简单看门狗** | `board/drivers/simple_watchdog.h` | (无直接接口) | ❌ 无 | — |

### 2.3 电源与系统管理

| # | 功能 | 固件代码 | Python 接口 | 测试覆盖 | 测试类型 |
|---|------|---------|------------|---------|---------|
| 18 | **省电模式** | `board/sys/power_saving.h` | `set_power_save()` | ❌ 无 | — |
| 19 | **深度休眠 (STOP)** | `power_saving.h:enter_stop_mode()` | `enter_stop_mode()` | ✅ 完整 | HITL: `8_misc.py:test_stop_mode` (仅 Cuatro) |
| 20 | **唤醒 (CAN/ignition)** | `main.c` + `harness.h` | (隐式，stop 后自动) | ✅ 部分 | `test_stop_mode` 测试 CAN/ignition 唤醒 |
| 21 | **Bootkick (SOM 管理)** | `board/drivers/bootkick.h` | (无 Python 接口) | ❌ 无 | — |
| 22 | **Tick 定时器 (8Hz)** | `board/drivers/timers.h`, `main.c` | (内部) | ❌ 无 | — |
| 23 | **微秒定时器** | `timers.h:microsecond_timer_get()` | `get_microsecond_timer()` | ✅ 完整 | HITL: `2_health.py:test_microsecond_timer` |
| 24 | **时钟源输出** | `board/drivers/clock_source.h` | `set_clock_source_timer_params()` | ❌ 无 | — |
| 25 | **系统复位** | `main.c` (NVIC reset) | `reset()`, `reconnect()` | ✅ 完整 | HITL: `8_misc.py:test_boot_time`, 所有 HITL 测试 reset 前置 |

### 2.4 固件刷写与恢复

| # | 功能 | 固件代码 | Python 接口 | 测试覆盖 | 测试类型 |
|---|------|---------|------------|---------|---------|
| 26 | **固件刷写 (Flash)** | `board/bootstub.c`, control 0xd1 | `flash()`, `flash_static()` | ✅ 完整 | HITL: `1_program.py:test_flash` |
| 27 | **DFU 恢复模式** | bootstub → STM32 ROM bootloader | `recover()`, `PandaDFU.recover()` | ✅ 完整 | HITL: `1_program.py:test_dfu`, `test_recover` |
| 28 | **Bootstub 兼容性** | `board/bootstub.c` | (内部) | ✅ 完整 | HITL: `1_program.py:test_known_bootstub` |
| 29 | **RSA 签名验证** | `board/crypto/rsa.c`, `sha.c` | `get_signature()` | ⚠️ 隐式 | 刷写时隐式验证 (签名错误则刷写失败) |
| 30 | **固件版本管理** | SConscript (git hash) | `get_version()`, `up_to_date()` | ⚠️ 部分 | 无专项测试 |

### 2.5 设备身份与配置

| # | 功能 | 固件代码 | Python 接口 | 测试覆盖 | 测试类型 |
|---|------|---------|------------|---------|---------|
| 31 | **硬件类型识别** | `board/boards/` | `get_type()` | ✅ 完整 | HITL: `2_health.py:test_hw_type` |
| 32 | **MCU UID** | 控制命令 0xc3 | `get_uid()` | ⚠️ 隐式 | HW type 测试中隐式使用 |
| 33 | **Dongle ID (Provisioning)** | `board/provision.h` | `get_serial()` | ❌ 无 | — |
| 34 | **密钥 (Secret)** | (内部) | `get_secret()` | ❌ 无 | — |
| 35 | **固件签名** | `board/crypto/` | `get_signature()` | ⚠️ 部分 | 刷写测试隐式验证 |

### 2.6 硬件 I/O 控制

| # | 功能 | 固件代码 | Python 接口 | 测试覆盖 | 测试类型 |
|---|------|---------|------------|---------|---------|
| 36 | **LED 控制 (RGB)** | `board/drivers/led.h`, `pwm.h` | (无直接 Python 接口) | ❌ 无 | — |
| 37 | **风扇控制** | `board/drivers/fan.h`, `llfan.h` | `set_fan_power()`, `get_fan_rpm()` | ✅ 完整 | HITL: `7_internal.py` (曲线+冷却) |
| 38 | **IR 功率** | 控制命令 0xb0 | `set_ir_power()` | ❌ 无 | — |
| 39 | **蜂鸣器/警报** | `board/drivers/fake_siren.h` | `set_siren()` | ❌ 无 | — |
| 40 | **音频编解码器** | `board/stm32h7/sound.h` | (无 Python 接口) | ❌ 无 | — |
| 41 | **继电器驱动** | `board/drivers/harness.h` | `force_relay_drive()` (DEBUG) | ❌ 无 | — |
| 42 | **SOM GPIO 读取** | 控制命令 0xc6 (DEBUG) | `read_som_gpio()` | ❌ 无 | — |
| 43 | **PWM 输出** | `board/drivers/pwm.h` | (内部，供 fan/led 使用) | ⚠️ 隐式 | 风扇测试中隐式使用 |

### 2.7 线束与点火检测

| # | 功能 | 固件代码 | Python 接口 | 测试覆盖 | 测试类型 |
|---|------|---------|------------|---------|---------|
| 44 | **线束方向检测** | `board/drivers/harness.h` | (health 中) | ✅ 完整 | HITL: `9_harness.py:test_harness_status` |
| 45 | **点火检测** | `harness.h:harness_check_ignition()` | (health 中) | ✅ 完整 | HITL: `9_harness.py` (含 ignition on/off) |
| 46 | **SBU 电压检测** | `lladc.h` | (health 中) | ✅ 完整 | HITL: `9_harness.py` |
| 47 | **CAN 总线路由** | `harness.h` | (自动) | ✅ 完整 | HITL: `9_harness.py` (验证方向翻转时 bus 0↔2 交换) |

### 2.8 调试与诊断

| # | 功能 | 固件代码 | Python 接口 | 测试覆盖 | 测试类型 |
|---|------|---------|------------|---------|---------|
| 48 | **UART 串口** | `board/drivers/uart.h`, `lluart.h` | `serial_read()`, `serial_write()` | ⚠️ 最小 | HITL: `3_usb.py:test_serial_debug` (仅一个请求) |
| 49 | **UART 波特率/校验** | `uart.h` | `set_uart_baud()`, `set_uart_parity()` | ❌ 无 | — |
| 50 | **UART 回调** | `uart.h` | `set_uart_callback()` | ❌ 无 | — |
| 51 | **替代体验模式** | 控制命令 0xdf | `set_alternative_experience()` | ❌ 无 | — |
| 52 | **ADC 测量** | `board/stm32h7/lladc.h` | (内部，health 中) | ⚠️ 隐式 | 电压测试中隐式使用 |
| 53 | **CRC 工具** | `board/crc.h` | (内部) | ❌ 无 | — |

### 2.9 板级抽象

| # | 功能 | 固件代码 | Python 接口 | 测试覆盖 | 测试类型 |
|---|------|---------|------------|---------|---------|
| 54 | **Cuatro 板** | `board/boards/cuatro.h` | (自动检测) | ✅ 部分 | 所有带 Cuatro 硬件的 HITL 测试 |
| 55 | **Tres 板** | `board/boards/tres.h` | (自动检测) | ✅ 部分 | 部分 HITL 测试 |
| 56 | **Red Panda 板** | `board/boards/red.h` | (自动检测) | ✅ 部分 | `3_usb.py` 专属 Red Panda |

### 2.10 Jungle 扩展

| # | 功能 | 固件代码 | Python 接口 | 测试覆盖 | 测试类型 |
|---|------|---------|------------|---------|---------|
| 57 | **CAN 转发** | `can_common.h:can_set_forwarding()` | (内部) | ⚠️ 隐式 | 所有 panda↔jungle CAN 测试 |
| 58 | **Jungle 健康** | `board/jungle/` | (内部) | ❌ 无 | — |
| 59 | **按钮检测** | `board/jungle/main.c` | (内部) | ❌ 无 | — |

### 2.11 Body 扩展

| # | 功能 | 固件代码 | Python 接口 | 测试覆盖 | 测试类型 |
|---|------|---------|------------|---------|---------|
| 60 | **BLDC 电机控制** | `board/body/bldc/bldc.h` | (无 Python 接口) | ❌ 无 | — |
| 61 | **Dotstar LED** | `board/body/dotstar.h` | (无 Python 接口) | ❌ 无 | — |
| 62 | **Body 点火控制** | `board/body/main.c` | (无 Python 接口) | ❌ 无 | — |

### 2.12 代码质量

| # | 功能 | 工具 | 测试覆盖 | 测试类型 |
|---|------|------|---------|---------|
| 63 | **MISRA C:2012 合规** | `cppcheck` | ✅ 完整 | `test_misra.sh` (127 规则) + `test_mutation.py` |
| 64 | **Python 代码质量** | `ruff` | ✅ 完整 | CI 中通过 `ruff check .` 执行 |

---

## 三、测试覆盖统计

```
总功能数:  64
├── ✅ 有完整测试:  26 (40.6%)
├── ⚠️ 有部分/隐式测试: 12 (18.8%)
└── ❌ 无测试:      26 (40.6%)
```

### 按测试类型分布

| 测试套件 | 文件数 | 测试数 | 需要硬件 |
|----------|--------|--------|---------|
| USB 协议单元测试 | 2 | 6 | ❌ |
| E2E 端到端测试 (Cucumber BDD) | 2 | 12 | ❌ |
| MISRA 静态分析 | 2 | 2 | ❌ |
| HITL 硬件在环 | 9 | 29 | ✅ |
| **总计** | **15** | **49** | — |

---

## 四、端到端测试空白 (Top Gaps)

以下是无测试覆盖的高优先级功能，建议优先添加端到端测试：

### 🔴 高优先级 (核心 / 安全相关)

| 功能 | 风险 | 建议测试方式 |
|------|------|-------------|
| **CAN-FD 功能** (自动切换、非 ISO) | 完全未测试 | HITL: 需要 CAN-FD 兼容设备 |
| **OBD 多路复用** | 完全未测试 | HITL: 设置 OBD 模式，验证总线路由 |
| **省电模式** | 完全未测试 | HITL: 启用/禁用省电，验证功耗变化 |
| **故障检测** (寄存器发散、继电器故障等) | 仅 teardown 检查 | HITL: 模拟故障条件，验证检测 |
| **CAN 健康统计** | 无专项测试 | HITL: 发送错误帧，验证计数器 |

### 🟡 中优先级 (硬件 I/O)

| 功能 | 风险 | 建议测试方式 |
|------|------|-------------|
| **UART 串口通信** | 仅 1 个调试测试 | HITL: 回环测试、波特率变更 |
| **蜂鸣器/警报** | 完全未测试 | HITL: 验证 DAC 输出 |
| **IR 功率控制** | 完全未测试 | HITL: 测量电流变化 |
| **LED 控制** | 完全未测试 | 视觉验证或电流测量 |
| **设备身份** (Dongle ID, Secret) | 完全未测试 | HITL: 读取验证格式 |
| **时钟源输出** | 完全未测试 | HITL: 外部测量频率 |

### 🟢 低优先级 (辅助 / 调试)

| 功能 | 风险 | 建议测试方式 |
|------|------|-------------|
| **中断调用率** | 无测试 | HITL: 读取验证非零 |
| **替代体验模式** | 无测试 | HITL: 切换验证 |
| **SOM GPIO/Bootkick** | 无测试 | 需要 SOM 连接 |
| **音频编解码器** | 无测试 | 需要音频分析设备 |
| **BLDC 电机** | 无测试 | 需要电机连接 |
| **Jungle 按钮** | 无测试 | 需要 Jungle |

---

## 五、测试架构

```
┌─────────────────────────────────────────────────┐
│                  CI Pipeline                      │
│  test.sh                                         │
│  ├── setup.sh (依赖安装)                          │
│  ├── scons (固件构建)                             │
│  ├── ruff check . (Python lint)                  │
│  ├── tests/misra/test_misra.sh (MISRA)           │
│  ├── pytest tests/misra/test_mutation.py         │
│  ├── pytest tests/usbprotocol/ (USB 协议)        │
│  ├── cd e2e-tests && ./gradlew cucumber (E2E)    │
│  └── pytest tests/hitl/ (需要硬件)               │
│      ├── conftest.py: panda + jungle fixtures    │
│      │   - 每次测试前 reset panda                │
│      │   - 每次测试后检查健康状态                  │
│      │   - 自定义 markers: test_panda_types,     │
│      │     skip_panda_types, timeout 等           │
│      └── 测试文件 (1_program ~ 9_harness)        │
└─────────────────────────────────────────────────┘
```

### HITL 硬件需求

| 硬件 | 需要的测试 |
|------|-----------|
| Panda (任意) | 所有 HITL 测试 |
| Panda Jungle | `4_can_loopback.py`, `9_harness.py`, `8_misc.py`, `2_health.py` |
| Red Panda | `3_usb.py` (USB CAN 环回) |
| Cuatro | `8_misc.py:test_stop_mode` |
| Internal Panda | `7_internal.py` (风扇测试) |


---

## 六、E2E 端到端测试场景 (Cucumber BDD)

无需硬件，将 `board/main.c` 编译为宿主共享库，通过 JNA 直接调用真实 C 代码。

### can_loopback.feature (4 场景)

```
启用环回 → FDCAN TEST + MON 位
禁用环回 → 清除 TEST 位，保留 silent 的 MON 位
重新启用环回 → 清空 CAN TX 队列
环回模式下 CAN 发送 → 消息仍可正常发送
```

### safety_mode.feature (8 场景)

```
SILENT    → 阻断 CAN TX，relay 关闭
NOOUTPUT  → 阻断 CAN TX，relay 关闭
ALLOUTPUT → 放行所有 CAN TX，relay 开启
ELM327 OBD_CAN2 → 放行合法 OBD-II TX，总线 1
ELM327 NORMAL   → 放行合法 OBD-II TX，总线 0
TOYOTA    → 阻断非 TOYOTA CAN TX
非法安全模式 → 回退到 SILENT
切换安全模式 → 清空 TX 队列 + 重新初始化 FDCAN 寄存器
```

详见 `doc/e2e-tests.md`。

---

## 七、推荐的新增端到端测试

按优先级排序：

1. **`tests/hitl/11_power.py`** — 省电模式启用/禁用 + 心跳丢失自动省电
2. **`tests/hitl/12_can_health.py`** — CAN 健康统计 (错误计数器、bus-off 检测)
3. **`tests/hitl/13_uart.py`** — UART 读写、波特率变更、校验位
4. **`tests/hitl/14_canfd.py`** — CAN-FD 自动切换 + 非 ISO 模式
5. **`tests/hitl/15_io.py`** — IR/蜂鸣器/LED/时钟源 硬件 I/O
6. **`tests/hitl/16_identity.py`** — Dongle ID/Secret/UID 完整验证
7. **`tests/usbprotocol/test_safety.py`** — 安全模型单元测试 (利用 libpanda.so)
