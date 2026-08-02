# AGENTS.md

This file provides guidance to agentic tools (e.g. Claude Code, Gemini CLI, GitHub Copilot) when working with code in this repository.

## 项目总览

Panda 是 comma.ai 的汽车 CAN 总线接口固件项目。同一代码库通过 SCons 构建三个固件目标（panda、panda_jungle、body），面向 STM32H725 裸机 C。Python 库提供主机端 CAN 通信、刷写和健康监控。

## 架构总览

### 固件 (C)

- **目标**：STM32H725 (ARM Cortex-M7)，裸机 C，`-nostdlib -fno-builtin`
- **构建**：SCons（非 Make/CMake），`SConscript` 定义构建逻辑
- **硬件抽象**：`struct board`（`board/boards/board_declarations.h`）通过函数指针统一 cuatros、tres、red 等变体，所有操作走 `current_board->`
- **内存布局**：Bootstub (0x8000000) → App (0x8020000)，RSA-1024 签名
- **条件编译**：三个目标以 `PANDA_JUNGLE` / `PANDA_BODY` 宏区分，`#ifdef` 控制共享代码

### Python 库

```
python/__init__.py   → Panda（高层接口）
python/usb.py        → PandaUsbHandle（USB 传输）
python/spi.py        → PandaSpiHandle（SPI 传输）
python/serial.py     → PandaSerial（UART 调试）
python/dfu.py        → PandaDFU（DFU 恢复）
python/base.py       → BaseHandle 抽象基类
```

`Panda()` 自动检测 USB/SPI 传输方式。

### 安全模型

固件内嵌 [opendbc](https://github.com/commaai/opendbc) 车辆安全逻辑。主机必须在 2-5 秒内发送健康心跳，否则 panda 自动回退到 `SAFETY_SILENT` 模式。**不理解其影响前绝不要绕过此机制。**

## 常用开发命令

```bash
# 完整 CI 流水线
./test.sh

# 安装依赖（uv + pyproject.toml，创建 .venv）
./setup.sh

# 构建固件
scons                              # debug
CERT=board/certs/debug RELEASE=1 scons  # release

# Python
ruff check .                       # lint
pytest                             # 全部测试
pytest tests/usbprotocol/test_comms.py  # 单个文件

# MISRA（需先 scons 构建）
tests/misra/test_misra.sh
pytest tests/misra/test_mutation.py

# 端到端测试（Cucumber BDD，无需硬件）
cd e2e-tests && ./gradlew cucumber
cd e2e-tests && ./gradlew cucumber -Pfile='src/test/resources/features/safety_mode.feature:7'

# HITL（需要真实 panda + jungle 硬件）
cd tests/hitl && pytest test_file_name.py
```

## 关键约定

- **SCons 是唯一构建系统**。运行 MISRA 测试前必须先 `scons`。
- **uv 管理 Python 依赖**，`pyproject.toml` 唯一配置来源。仅 Python 3.11-3.12。
- **MISRA C:2012 强制合规**。覆盖率表 `tests/misra/coverage_table` 纳入版本管理，代码变更后必须重新生成。
- **HITL 测试**：自定义 pytest 标记 `test_panda_types` / `skip_panda_types` / `panda_expect_can_error` / `timeout`。每次测试前重置 panda，teardown 验证健康状态。
- **版本号**：`SConscript` 执行 `git rev-parse --short=8 HEAD` 写入 `board/obj/gitversion.h`。结构体头文件通过 SHA256 生成数据包版本号宏。

## 测试体系

| 目录 | 类型 | 需硬件 |
|------|------|--------|
| `tests/usbprotocol/` | 单元测试（CAN 打包、通信协议） | 否 |
| `tests/misra/` | MISRA C:2012 静态分析 + 变异测试 | 否 |
| `tests/hitl/` | 硬件在环测试 | 是 |
| `e2e-tests/` | 端到端 BDD 测试（Cucumber JVM） | 否 |

### 端到端测试

基于 Cucumber JVM + test-charm，将 `board/main.c` 编译为 macOS `.dylib`，通过 JNA 在 Java 中调用真实 C 代码，无需硬件。

```
board/main.c + 硬件 stub → clang → libpanda.dylib → JNA → NativePandaClient → Cucumber
```

关键文件：
- `e2e-tests/src/test/c/build.sh` — 编译脚本
- `e2e-tests/src/test/c/panda_safety.c` — JNA wrapper + 硬件 stub
- `e2e-tests/src/test/java/.../NativePandaClient.java` — JNA 入口
- `e2e-tests/src/test/resources/features/` — Gherkin BDD 场景

test-charm 框架参考：https://github.com/leeonky/test-charm-java，主要是下面几个，可通过 MCP 服务 "test-charm" 咨询。详细机制见 `doc/e2e-tests.md`。
- jfactory - 准备数据核心库
- jfactory-cucumber - 桥接了 cucumber 和 jfactory
- RESTful-cucumber - 发api请求，通过 DAL-java 来验证结果，也可以通过 jfactory 来准备请求数据
- DAL-java - 验证结果核心库
- DAL-extension-basic - 验证相关的各种扩展
- DAL-extension-jfactory - 将 DAL-java 的语法与 jfactory 结合，可以更加灵活的准备数据
