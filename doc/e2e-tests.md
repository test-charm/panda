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
  NativePandaClient.java
        │
        ▼
  ./gradlew cucumber  →  7 scenarios, 40 steps
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
│   │   ├── RunCucumberTest.java        # JUnit 平台入口（备选）
│   │   ├── client/
│   │   │   ├── PandaClient.java        # 统一接口
│   │   │   ├── PandaUsbClient.java     # 真实硬件：JNA → libusb
│   │   │   ├── NativePandaClient.java  # 无硬件：JNA → 编译后的 C 代码
│   │   │   └── StubPandaClient.java    # 纯 Java 回退桩
│   │   ├── context/TestContext.java    # Cucumber 共享状态
│   │   └── steps/SafetyModeSteps.java  # BDD 步骤定义
│   └── resources/
│       ├── features/safety_mode.feature # Gherkin 场景
│       └── test-design/safety-mode.md   # 测试设计文档
```

## 三层客户端架构

测试根据运行环境自动选择客户端实现：

```
SafetyModeSteps.createClient()
        │
   ┌────┴──── 尝试 PandaUsbClient (libusb)
   │         └─ 成功 → 真实 USB 硬件测试
   │
   └──── 失败 → 尝试 NativePandaClient (JNA)
             └─ 成功 → 真实 C 代码测试（无硬件）
             └─ 失败 → StubPandaClient (纯 Java)
```

| 客户端 | 被测代码 | 需要硬件 | 变异测试 |
|--------|---------|---------|---------|
| `PandaUsbClient` | 真实固件（STM32） | ✅ | ✅（需刷写） |
| `NativePandaClient` | 真实 C 代码（宿主编译） | ❌ | ✅ |
| `StubPandaClient` | Java 复现 | ❌ | ❌ |

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
- `set_intercept_relay()`, `can_clear_send()`, `can_init_all()` 等硬件函数

## JNA 接口

`NativePandaClient.SafetyLib` 通过 JNA 绑定到 `.dylib` 中的 C 函数：

```java
public interface SafetyLib extends Library {
    SafetyLib INSTANCE = Native.load(".../libpanda.dylib", SafetyLib.class);
    void jna_set_safety_mode(short mode, short param);
    byte  jna_get_can_silent();
}
```

C 侧导出的 JNA 函数：

```c
void jna_set_safety_mode(uint16_t mode, uint16_t param) {
    set_safety_mode(mode, param);  // 调用 board/main.c 的真实代码
}

bool jna_get_can_silent(void) {
    return can_silent;             // 读取 C 全局变量
}
```

## 运行命令

```bash
cd e2e-tests

# 运行全部端到端测试
./gradlew cucumber

# 运行单个场景（按行号）
./gradlew cucumber -Pfile='src/test/resources/features/safety_mode.feature:27'

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
# 7 scenarios (7 passed)
```
