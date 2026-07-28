# 数据包版本读取 — 测试设计文档

> 功能: get health and CAN packet versions via `comms_control_handler()` in `board/main_comms.h`
> 被测接口: USB control request 0xdd
> 最后更新: 2026-07-28 (新增 `canInitTimeoutMs` 配置常量验证)

## 1. 被测功能流程图

```
get packet versions (0xdd):
  [controlWrite(0xdd, 0, 0)]
           │
           ▼
  versions[0] = HEALTH_PACKET_VERSION
  versions[1] = CAN_PACKET_VERSION_HASH
  memcpy(resp, versions, 8)
  resp_len = 8
           │
           ▼
        (done)
```

代码路径为直线，无分支。返回两个 uint32 版本号到 response buffer。

## 2. 输入因子

| 因子 | 类型 | 等价类 | 取值 |
|------|------|--------|------|
| `request` | uint8 | 0xdd (唯一) | 0xdd |

## 3. 输出因子

| 输出 | 类型 | 说明 |
|------|------|------|
| healthVersion | int | HEALTH_PACKET_VERSION (e2e: 0) |
| canVersionHash | int | CAN_PACKET_VERSION_HASH (e2e: 0) |
| canInitTimeoutMs | int | `CAN_INIT_TIMEOUT_MS` 编译时常量 (500) — Phase D.1 通过 JNA getter 验证 |

## 4. 测试用例

### TC1: 读取数据包版本号和配置常量
- 前置: 初始状态
- 输入: request=0xdd
- 输出: healthVersion=0, canVersionHash=0 (e2e 环境常量值), canInitTimeoutMs=500
- 路径: 读取两个编译时常量 → 写入 response buffer；验证 `CAN_INIT_TIMEOUT_MS` 宏值

## 5. 覆盖检查

| 条件 | TC1 |
|------|-----|
| request == 0xdd | ✅ |
| CAN_INIT_TIMEOUT_MS == 500 | ✅ Phase D.1 |

✅ 代码路径已覆盖。

## 覆盖率

> 数据来源: `run_all_coverage.sh` 合并报告 (cuatro + tres + red)
> 综合行覆盖率: **78.9%** (全量), 本功能涉及以下源文件:

| 源文件 | 行覆盖 | 说明 |
|--------|--------|------|
| `main_comms.h` | 95.5% (257/269) | USB 命令处理 |
| `config.h` | 100% (4/4) | ✅ Phase D.1 (`CAN_INIT_TIMEOUT_MS` 已覆盖) |

