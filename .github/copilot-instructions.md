# Panda Copilot 指令

## 构建、测试与 Lint 命令

```bash
# 完整 CI 流水线：环境准备 → 构建 → lint → 测试
./test.sh

# 安装依赖（使用 uv，创建 .venv）
./setup.sh

# 构建固件（debug 模式，输出到 board/obj/）
scons

# 构建 release 固件
CERT=board/certs/debug RELEASE=1 scons

# Python 代码 lint
ruff check .

# 运行全部 Python 测试
pytest

# 运行单个测试文件
pytest tests/usbprotocol/test_comms.py

# 运行 MISRA 合规检查（需先执行 scons 构建）
tests/misra/test_misra.sh

# 运行 MISRA 变异测试
pytest tests/misra/test_mutation.py

# 运行端到端测试（Cucumber BDD，无需硬件）
cd e2e-tests && ./gradlew cucumber

# 运行单个端到端测试场景
cd e2e-tests && ./gradlew cucumber -Pfile='src/test/resources/features/safety_mode.feature:7'

# 运行 HITL 测试（需要真实 panda 硬件 + panda jungle）
cd tests/hitl && pytest test_file_name.py
```

## 架构

### 同一代码库构建三个固件目标

`board/` 目录包含面向 STM32H725（ARM Cortex-M7）的裸机 C 固件。SCons 从同一代码库构建三个独立的固件镜像：

```
board/main.c          → panda 固件
board/jungle/main.c   → panda_jungle 固件（测试夹具）
board/body/main.c     → body 固件
```

每个目标通过预处理器宏（`PANDA_JUNGLE`、`PANDA_BODY`）区分，在共享源文件中用 `#ifdef` 控制条件编译。

### 硬件抽象：`struct board`

文件：`board/boards/board_declarations.h`

硬件变体（cuatro、tres、red）通过一个充满函数指针的 `struct board` 进行抽象。`board/main.c` 中所有操作都通过 `current_board->` 调用：LED 控制、CAN 收发器、蜂鸣器、红外功率、风扇等。这使得主循环与硬件无关。各板级实现位于 `board/boards/cuatro.h`、`red.h`、`tres.h`。

### Python 库分层

```
python/__init__.py   → Panda 类（高层接口：CAN、刷写、健康监控）
python/usb.py        → PandaUsbHandle（USB 控制/批量传输）
python/spi.py        → PandaSpiHandle（SPI 传输，仅 comma four 使用）
python/serial.py     → PandaSerial（UART 调试控制台）
python/dfu.py        → PandaDFU（STM32 DFU 模式恢复）
python/base.py       → 抽象 BaseHandle 和 BaseSTBootloaderHandle
```

`Panda()` 自动检测 USB 与 SPI 传输方式。`BaseHandle` 抽象基类定义了接口契约：`controlWrite`、`controlRead`、`bulkWrite`、`bulkRead`。

### 安全模型（opendbc）

固件内嵌来自 [opendbc](https://github.com/commaai/opendbc) 的车辆特定 CAN 安全逻辑。`set_safety_hooks()` 在 `board/main.c` 中被调用，安全模型会对每条 CAN 消息进行校验和转换。若主机未发送心跳包，panda 将在 2-5 秒后回退到 `SAFETY_SILENT` 模式。

### 固件内存布局

- **Bootstub**（0x8000000）：最小引导程序，用于固件刷写，实现 USB DFU 和 SPI 刷写功能
- **App**（0x8020000）：主固件，使用 RSA-1024 签名

两者均由 `SConscript` 构建，输出 `.bin` 文件到 `board/obj/`。

### CAN 消息传输格式

自定义 6 字节头部 + 变长数据：
- 字节 0：`[data_len_code:4][bus:2][reserved:1][fd:1]`
- 字节 1-4：29 位地址（扩展帧标志位于字节 1 的第 2 位）
- 字节 5：头部 + 数据的 XOR 校验和

Python 打包/解包函数：`python/__init__.py` 中的 `pack_can_buffer()`、`unpack_can_buffer()`。

### 测试分类

| 目录 | 类型 | 需要硬件？ |
|-----------|------|--------------------|
| `tests/usbprotocol/` | 单元测试（CAN 打包、通信协议） | 否 |
| `tests/libpanda/` | C 代码编译为 `.so` 供 usbprotocol 测试使用 | 否 |
| `tests/misra/` | MISRA C:2012 静态分析 + 变异测试 | 否 |
| `tests/hitl/` | 硬件在环测试（真实 panda + jungle） | 是 |
| `e2e-tests/` | 端到端 BDD 测试（Cucumber JVM） | 否 |

## 关键约定

- **SCons 是构建系统**，不是 Make/CMake。构建命令写在 `SConscript` 中。运行 MISRA 或安全测试前必须先构建固件。
- **uv 管理 Python 依赖**（不直接用 pip）。`pyproject.toml` 是唯一配置来源。`.venv` 位于仓库根目录。
- **仅 Python 3.11-3.12**。3.13 因 opendbc 中的 pycapnp 兼容性问题被排除。
- **ruff 代码检查**，规则配置在 `pyproject.toml` 中。特别注意：`pytest.main` 被禁止使用（flake8-tidy-imports 规则）。
- **固件编译选项极其严格**：`-Wall -Wextra -Wstrict-prototypes -Werror -fmax-errors=1 -nostdlib -fno-builtin`。没有标准库可用 —— `board/libc.h` 提供最小化的 libc 替代实现。
- **MISRA C:2012 合规是强制要求**，适用于 `board/` 中的固件代码。覆盖率表（`tests/misra/coverage_table`）已纳入版本管理，代码变更后必须重新生成。抑制项配置在 `tests/misra/suppressions.txt`。
- **版本号自动生成**：`SConscript` 执行 `git rev-parse --short=8 HEAD` 并将结果写入 `board/obj/gitversion.h`。结构体头文件（`health.h`、`can.h`、`jungle_health.h`）通过 SHA256 哈希生成数据包版本号宏 —— 结构体布局变化时这些宏会自动变化。
- **电源管理**：当 `power_save_enabled` 且 SOM GPIO 为低时，主循环进入 STOP 模式（深度休眠）。CAN 活动或 SBU 信号可唤醒。唤醒且非省电模式时 LED 会呼吸渐变。
- **心跳看门狗**：主机必须在 2-5 秒内发送健康数据包，否则 panda 进入 SILENT 安全模式 + 省电模式。这是关键安全特性 —— 不理解其影响前绝不要绕过。
- **HITL 测试使用自定义 pytest 标记**：`@pytest.mark.test_panda_types`、`@pytest.mark.skip_panda_types`、`@pytest.mark.panda_expect_can_error`、`@pytest.mark.timeout`。测试默认超时 60 秒，可通过标记覆盖。
- **测试隔离**：HITL 测试在每次测试前重置 panda，在 teardown 中验证健康状态（故障、CAN 错误）。`tests/hitl/conftest.py` 通过 fixture 管理这些流程。

## 端到端测试（`e2e-tests/`）

基于 Cucumber JVM + test-charm 框架，将 `board/main.c` 编译为宿主共享库，通过 JNA 在 Java 中直接调用真实 C 代码。无需硬件即可运行，支持变异测试。

### 三层客户端

测试自动选择通信层：`PandaUsbClient`（真实硬件）→ `NativePandaClient`（C 编译库）→ `StubPandaClient`（纯 Java 回退）。

### 变异测试

修改 `board/main.c` 代码 → `cd e2e-tests/src/test/c && ./build.sh` 重新编译 `.dylib` → `./gradlew cucumber` 验证测试捕获回归。

### 架构

```
board/main.c（完整源码）
  └── + 硬件 stub 头文件 + libpanda.c
       └── clang → libpanda.dylib
            └── JNA → NativePandaClient.java → Cucumber BDD
```

### 关键文件

| 文件 | 作用 |
|------|------|
| `e2e-tests/build.gradle` | Gradle 构建（仅 cucumber + jfactory + JNA） |
| `e2e-tests/src/test/c/build.sh` | awk 提取 + clang 编译脚本 |
| `e2e-tests/src/test/c/panda_safety.c` | JNA wrapper，硬件 stub |
| `e2e-tests/src/test/c/board/` | 硬件头文件 stub（覆盖真实 STM32 HAL 头文件） |
| `e2e-tests/src/test/java/.../NativePandaClient.java` | JNA 调用 C 库 |
| `e2e-tests/src/test/resources/features/safety_mode.feature` | Gherkin BDD 场景 |

详细机制见 `doc/e2e-tests.md`。
