# 固件签名读取 — 测试设计文档

> 功能: get firmware signature via `comms_control_handler()` in `board/main_comms.h`
> 被测接口: USB control request 0xd3 (first 64 bytes) / 0xd4 (second 64 bytes)

## 1. 被测功能流程图

```
get signature (0xd3 / 0xd4):
  [controlWrite(request, 0, 0)]     request = 0xd3 or 0xd4
           │
           ▼
  code = (char*)_app_start
  code_len = _app_start[0]
  offset = code_len + (request == 0xd4 ? 64 : 0)
  memcpy(resp, &code[offset], 64)
  resp_len = 64
```

## 2. 输入因子

| 因子 | 类型 | 等价类 | 取值 |
|------|------|--------|------|
| `request` | uint8 | 0xd3 (第一块) | 0xd3 |
| `request` | uint8 | 0xd4 (第二块) | 0xd4 |
| `codeLen` (前置) | int | 非零偏移 | 256 |
| `signatureChunk0` (前置) | byte[64] | 非零模式 | 32x AABB + 32x CCDD |
| `signatureChunk1` (前置) | byte[64] | 非零模式 | 32x 0102 + 32x 0304 |

## 3. 输出因子

| 输出 | 类型 | 说明 |
|------|------|------|
| respBuffer.len | int | 64 |
| respBuffer.bytes[0..63] | byte[] | 签名块原始字节 |

## 4. 测试用例

### TC1: 0xd3 读取第一块签名
- 前置: codeLen=256, signatureChunk0=32xAABB+32xCCDD
- 输入: request=0xd3
- 输出: resp_len=64, bytes[0]=0xAA, bytes[31]=0xAA, bytes[63]=0xDD

### TC2: 0xd4 读取第二块签名
- 前置: codeLen=256, signatureChunk1=32x0102+32x0304
- 输入: request=0xd4
- 输出: resp_len=64, bytes[0]=0x01, bytes[31]=0x01, bytes[63]=0x04

## 5. 覆盖检查

| 条件 | TC1 | TC2 |
|------|:--:|:--:|
| request == 0xd3 | ✅ | — |
| request == 0xd4 | — | ✅ |

✅ 所有代码路径已覆盖。
