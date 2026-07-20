# 数据包版本读取 — 测试设计文档

> 功能: get health and CAN packet versions via `comms_control_handler()` in `board/main_comms.h`
> 被测接口: USB control request 0xdd

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

## 4. 测试用例

### TC1: 读取数据包版本号
- 前置: 初始状态
- 输入: request=0xdd
- 输出: healthVersion=0, canVersionHash=0 (e2e 环境常量值)
- 路径: 读取两个编译时常量 → 写入 response buffer

## 5. 覆盖检查

| 条件 | TC1 |
|------|-----|
| request == 0xdd | ✅ |

✅ 代码路径已覆盖。
