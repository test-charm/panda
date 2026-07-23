# 端到端测试机制说明

## 概览

`e2e-tests/` 是基于 Cucumber JVM + test-charm 框架的端到端测试项目。与 `tests/hitl/` 不同，这些测试**不需要 panda 硬件**即可运行。

核心思路：将 `board/main.c` 中的固件 C 代码编译为宿主共享库 (`.dylib`)，通过 JNA 在 Java 中直接调用真实的生产代码进行测试。修改 `board/main.c` 后重新构建即可验证测试是否捕获回归。

```
修改 board/main.c 生产代码
        │
        ▼
  src/test/c/build.sh
  └── clang 编译 → libpanda.dylib
        │
        ▼ JNA
  PandaClient.java
        │
        ▼
  ./gradlew cucumber  →  87 scenarios, 291 steps
```

## 目录结构

```
e2e-tests/
├── build.gradle                        # Gradle 构建：cucumber + jfactory + JNA
├── src/test/
│   ├── c/                              # C 源码 + 宿主编译
│   │   ├── build.sh                    # 编译脚本（编译完整 board/main.c）
│   │   ├── libpanda.c                  # JNA wrapper，提供硬件 stub
│   │   └── board/                      # 硬件头文件 stub（覆盖真实头文件）
│   │       ├── drivers/                # led.h, pwm.h, usb.h, fdcan.h ...
│   │       ├── sys/power_saving.h
│   │       ├── obj/gitversion.h
│   │       └── ...
│   ├── java/com/panda/e2e/
│   │   ├── PandaClient.java              # JNA 接口 + 状态读取
│   │   ├── SafetyModeSteps.java          # BDD 步骤定义
│   │   ├── ApplicationSteps.java         # Spring Boot 配置
│   │   ├── CucumberConfiguration.java    # Spring 上下文
│   │   ├── Factories.java                # JFactory 注册
│   │   └── spec/
│   │       ├── UsbControlRequests.java   # 控制请求 Spec（Heartbeat, SetSafetyMode, CanLoopback, DisableHeartbeat）
│   │       └── CanSendRequests.java      # CAN 发送 Spec
│   └── resources/
│       ├── features/                    # 22 个 feature 文件，74 个场景
│       │   ├── safety_mode.feature
│       │   ├── can_loopback.feature
│       │   ├── heartbeat.feature
│       │   ├── health.feature
│       │   ├── can_mode.feature
│       │   ├── relay.feature
│       │   ├── power_save.feature
│       │   ├── alternative_experience.feature
│       │   ├── siren.feature
│       │   ├── can_comms_reset.feature
│       │   ├── can_ring_clear.feature
│       │   ├── get_version.feature
│       │   ├── packet_versions.feature
│       │   ├── ir_power.feature
│       │   ├── hw_type.feature
│       │   ├── can_bitrate.feature
│       │   ├── can_fd_auto.feature
│       │   ├── can_fd_non_iso.feature
│       │   ├── can_fd_data_bitrate.feature
│       │   ├── clock_source.feature
│       │   └── timer_fan.feature
│       └── test-design/                # 21 个测试设计文档
│           ├── safety-mode.md
│           ├── can_loopback.md
│           ├── heartbeat.md
│           ├── health-packet.md
│           ├── can_mode.md
│           ├── relay.md
│           ├── power-save.md
│           ├── alternative-experience.md
│           ├── siren.md
│           ├── can-comms-reset.md
│           ├── can-ring-clear.md
│           ├── get-version.md
│           ├── packet-versions.md
│           ├── ir-power.md
│           ├── hw-type.md
│           ├── can-bitrate.md
│           ├── can-fd-auto.md
│           ├── can-fd-non-iso.md
│           ├── can-fd-data-bitrate.md
│           ├── clock-source.md
│           └── timer-fan.md
```

## 架构

所有测试通过 JNA 直接调用编译后的 C 固件代码，无需三层回退：

```
Cucumber BDD (Gherkin)
        │
        ▼
  SafetyModeSteps.java
        │  JFactory 准备请求数据
        │  DAL-java expect(...).should(...) 验证结果
        │
        ▼
  PandaClient.java ──JNA──→ libpanda.dylib
        │                        │
        │ controlWrite()          │ comms_control_handler()
        │ canSend()              │ can_send()
        │ getHeartbeat*()        │ heartbeat_counter, heartbeat_lost ...
        │ getSafetyTxBlocked()   │ safety_tx_blocked
        │ rxQueue() / txQueue()  │ can_rx_q / can_tx*_q
        │ relayCall()            │ set_intercept_relay stub
        │ canModeCall()          │ set_can_mode stub
        │ fdcanRegs()            │ fake FDCAN registers
        │ getHealthPacket()      │ get_health_pkt()
        │ getPowerSaveTracking() │ irq_enable/disable, ir_power, can_transceivers stubs
        │ getRespBuffer()        │ jna_resp / jna_resp_len
        │ setMicrosecondTimer()  │ MICROSECOND_TIMER->CNT
        ▼                        ▼
  编译后的 board/main.c (真实生产代码) + 硬件 stub
```

| 被测对象 | 覆盖方式 |
|---------|---------|
| `comms_control_handler()` | `jna_control_write()` → 完整固件路径 |
| `can_send()` → safety hooks | `jna_can_send()` → 安全校验流水线 |
| heartbeat 状态 | `jna_get_heartbeat_*()` → 心跳全局变量 |
| FDCAN 寄存器 | `jna_get_fdcan_*()` → 虚拟外设状态 |
| relay / can mode | stub 记录最后调用参数 |
| 省电硬件调用 | `llcan_irq_enable/disable`, `enable_can_transceivers`, `set_ir_power` 追踪 |
| response buffer | `jna_get_resp_len/byte()` → `jna_resp` 内容 |
| TIM 寄存器 (时钟源) | fake_TIM1/fake_TIM8 实例 |

## 被测功能覆盖

| 功能 | Feature 文件 | 场景数 | USB 请求 |
|------|-------------|--------|----------|
| 安全模式切换 | `safety_mode.feature` | 7 | 0xdc |
| CAN 回环模式 | `can_loopback.feature` | 4 | 0xe5 |
| 心跳机制 | `heartbeat.feature` | 6 | 0xf3, 0xf8 |
| 健康数据包 | `health.feature` | 3 | 0xd2 |
| OBD CAN 多路复用 | `can_mode.feature` | 3 | 0xdb |
| 拦截继电器 | `relay.feature` | 6 | 0xc5 |
| 省电模式 | `power_save.feature` | 6 | 0xe7 |
| 替代体验模式 | `alternative_experience.feature` | 5 | 0xdf |
| 警笛控制 | `siren.feature` | 3 | 0xf6 |
| CAN 通信重置 | `can_comms_reset.feature` | 3 | 0xc0 |
| CAN 环形缓冲区清除 | `can_ring_clear.feature` | 4 | 0xf1 |
| 固件版本读取 | `get_version.feature` | 1 | 0xd6 |
| 数据包版本读取 | `packet_versions.feature` | 1 | 0xdd |
| IR 功率设置 | `ir_power.feature` | 3 | 0xb0 |
| 硬件类型读取 | `hw_type.feature` | 1 | 0xc1 |
| CAN 波特率设置 | `can_bitrate.feature` | 3 | 0xde |
| CAN FD 自动切换 | `can_fd_auto.feature` | 3 | 0xe8 |
| CAN FD Non-ISO 模式 | `can_fd_non_iso.feature` | 3 | 0xfc |
| CAN FD 数据波特率 | `can_fd_data_bitrate.feature` | 3 | 0xf9 |
| 自定义时钟源 | `clock_source.feature` | 3 | 0xe6 |
| 微秒定时器 / 风扇转速 | `timer_fan.feature` | 2 | 0xa8, 0xb2 |
| 风扇功率控制 | `fan_power.feature` | 5 | 0xb1 |
| 系统复位 | `reset_st.feature` | 1 | 0xd8 |
| SOM GPIO 读取 | `som_gpio.feature` | 1 | 0xc6 |
| CAN 健康统计 | `can_health.feature` | 6 | 0xc2 |

## C 代码编译机制

### 编译

```bash
cc -std=gnu11 -fPIC -shared -O0 -g \
  -I src/test/c \        # 硬件 stub 头文件（优先级最高）
  -I . \                  # 项目根目录
  -I board/ \             # 真实固件头文件
  -I .venv/.../opendbc \  # opendbc 头文件
  -D main=panda_main \    # 重命名 main() 避免符号冲突
  -o libpanda.dylib
```

### 硬件依赖 stub

编译路径 `-I src/test/c` 优先级最高，其中的 stub 头文件覆盖了真实固件中依赖 STM32 HAL 的硬件头文件：

| Stub 文件 | 覆盖的真实文件 | 原因 |
|-----------|--------------|------|
| `board/drivers/led.h` | PWM LED 控制 | 依赖 TIM3 寄存器 |
| `board/drivers/pwm.h` | 硬件 PWM | 依赖 TIM3 |
| `board/drivers/usb.h` | USB 设备栈 | 依赖 USB OTG HS 寄存器 |
| `board/drivers/fdcan.h` | FDCAN 驱动 | 仅需 CANIF_FROM_CAN_NUM 宏 |
| `board/drivers/harness.h` | 线束检测 | 依赖 GPIO、ADC |
| `board/sys/power_saving.h` | 省电管理 | 依赖 PWR 寄存器 |
| `board/early_init.h` | 早期初始化 | 依赖 VTOR、时钟 |
| `board/main_comms.h` | 通信协议 | 依赖 USB/SPI 端点 |

`libpanda.c` 中的显式 stub：
- `current_board` — board 结构体实例
- `can_silent`, `safety_tx_blocked` 等全局变量
- `set_intercept_relay()`, `set_power_save_state()`, `can_clear_send()`, `can_init_all()` 等硬件函数
- 生成文件 `fdcan_e2e.gen.c`, `power_save_e2e.gen.c`, `clock_source_e2e.gen.c` — 从生产代码自动提取
- `jna_resp` / `jna_resp_len` — 控制请求响应 buffer，供 read 型请求测试使用

## JNA 接口

`PandaClient.PandaLib` 通过 JNA 绑定到 `.dylib` 中的 C 函数：

```java
public interface PandaLib extends Library {
    PandaLib INSTANCE = Native.load(".../libpanda.dylib", PandaLib.class);

    // 控制请求（走完整 comms_control_handler 路径）
    void jna_control_write(byte request, short param1, short param2);

    // CAN 发送（走完整 can_send → safety hooks 路径）
    int  jna_can_send(int addr, byte bus, byte[] data, byte len);

    // CAN 队列
    boolean jna_can_pop_rx(...);
    boolean jna_can_pop_tx(int queueIdx, ...);
    void jna_can_clear_all();

    // 安全状态
    int jna_get_safety_tx_blocked();

    // Relay / CAN mode stub 记录
    int jna_get_relay_call_count();
    int jna_get_relay_a();
    int jna_get_relay_b();
    void jna_clear_relay_calls();
    int jna_get_can_mode_call_count();
    int jna_get_can_mode();
    void jna_clear_can_mode_calls();

    // 心跳状态
    int jna_get_heartbeat_counter();
    int jna_get_heartbeat_lost();
    int jna_get_heartbeat_disabled();
    int jna_get_heartbeat_engaged();
    void jna_reset_heartbeat();

    // FDCAN 寄存器检查
    void jna_reset_fdcan();
    int  jna_get_fdcan_cccr(int n);
    int  jna_get_fdcan_ie(int n);
    // ... 其他寄存器 ...

    // 健康数据包
    void jna_read_health_pkt();
    int  jna_get_health_uptime();
    // ...

    // 省电模式硬件调用追踪
    int  jna_get_irq_enable_call_count();
    int  jna_get_irq_disable_call_count();
    // ...

    // Response buffer 检查（用于 read 型请求）
    int  jna_get_resp_len();
    int  jna_get_resp_byte(int index);

    // 测试前置设定
    void jna_set_microsecond_timer(int val);
    void jna_set_fan_rpm(int val);
    void jna_set_hw_type(int val);
    void jna_set_gitversion(String val);
}
```

## 运行命令

```bash
cd e2e-tests

# 运行全部端到端测试
./gradlew cucumber

# 运行单个场景（按行号）
./gradlew cucumber -Pfile='src/test/resources/features/heartbeat.feature:4'

# 手工重建 C 库（通常 ./gradlew cucumber 自动触发）
cd src/test/c && ./build.sh
```

## 变异测试流程

证明测试能捕获生产代码回归：

```bash
# 1. 修改 board/main.c（引入 bug）
#    例如：can_silent = true → can_silent = false

# 2. 重建 C 库
cd e2e-tests/src/test/c && ./build.sh

# 3. 运行测试 → 预期失败
cd .. && ./gradlew cucumber
# SILENT mode blocks CAN transmission  ✘ FAILED

# 4. 还原修改

# 5. 重建 + 验证全绿
cd src/test/c && ./build.sh && cd .. && ./gradlew cucumber
# 87 scenarios (87 passed)
```
