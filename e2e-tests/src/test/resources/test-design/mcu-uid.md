# MCU UID 读取 — 测试设计文档

> 功能: get MCU UID via `comms_control_handler()` in `board/main_comms.h`
> 被测接口: USB control request 0xc3 (fetch MCU UID)

## 1. 被测功能流程图

```
get MCU UID (0xc3):
  [controlWrite(0xc3, 0, 0)]
           │
           ▼
  memcpy(resp, UID_BASE, 12)
  resp_len = 12
           │
           ▼
        (done)
```

## 2. 输入因子

| 因子 | 类型 | 等价类 | 取值 |
|------|------|--------|------|
| `request` | uint8 | 0xc3 (唯一) | 0xc3 |
| `mcuUidBytes` (前置) | byte[12] | 非零模式值 | DEADBEEF0102030405060708 |
| `mcuUidBytes` (前置) | byte[12] | 全零值 | 000000000000000000000000 |

## 3. 输出因子

| 输出 | 类型 | 说明 |
|------|------|------|
| respBuffer.len | int | resp_len = 12 |
| respBuffer.bytes[0..11] | byte[] | UID_BASE[0..11] |

## 4. 测试用例

### TC1: 预设非零 UID → 返回 12 字节
- 前置: 设 mcuUidBytes=DEADBEEF0102030405060708
- 输入: request=0xc3
- 输出: resp_len=12, bytes=[0xDE,0xAD,0xBE,0xEF,0x01,...,0x0C]

### TC2: 预设零 UID → 返回 12 个零字节
- 前置: 设 mcuUidBytes=000000000000000000000000
- 输入: request=0xc3
- 输出: resp_len=12, bytes=[0x00, ...x12]

## 5. 覆盖检查

| 条件 | TC1 | TC2 |
|------|:--:|:--:|
| 单一路径（无分支） | ✅ | ✅ |

| 取值 | TC1 | TC2 |
|------|:--:|:--:|
| mcuUidBytes = 非零 | ✅ | — |
| mcuUidBytes = 全零 | — | ✅ |

✅ 代码路径已覆盖。所有输入因子取值已覆盖。
