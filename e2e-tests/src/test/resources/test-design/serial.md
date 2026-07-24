# 序列号/Provision 读取 — 测试设计文档

> 功能: get serial number / provision chunk via `comms_control_handler()` in `board/main_comms.h`
> 被测接口: USB control request 0xd0 (fetch serial)

## 1. 被测功能流程图

```
fetch serial (0xd0):
  [controlWrite(0xd0, param1, 0)]
           │
           ▼
  param1 == 1?
     ├── Y → memcpy(resp, DEVICE_SERIAL_NUMBER_ADDRESS, 16)
     │        resp_len = 16
     └── N → get_provision_chunk(resp)
              resp_len = PROVISION_CHUNK_LEN (32)
```

## 2. 输入因子

| 因子 | 类型 | 等价类 | 取值 |
|------|------|--------|------|
| `request` | uint8 | 0xd0 (唯一) | 0xd0 |
| `param1` | uint16 | == 1 | 1 |
| `param1` | uint16 | != 1 | 0 |
| `serialBytes` (前置) | byte[16] | 非零模式 | DEADC0DE12345678BEEFCAFE0000FEED |
| `provisionBytes` (前置) | byte[32] | 非零模式 | 01020304...1F20 |

## 3. 输出因子

| 输出 | 类型 | 说明 |
|------|------|------|
| respBuffer.len | int | 16 (serial) 或 32 (provision) |
| respBuffer.bytes[0..N] | byte[] | 对应缓冲区的原始字节 |

## 4. 测试用例

### TC1: param1=1 → 返回 16 字节序列号
- 前置: serialBytes=DEADC0DE12345678BEEFCAFE0000FEED
- 输入: request=0xd0, param1=1
- 输出: resp_len=16, bytes[0]=0xDE, bytes[1]=0xAD, ..., bytes[15]=0xED

### TC2: param1=0 → 返回 32 字节 provision chunk
- 前置: provisionBytes=0102030405060708090A0B0C0D0E0F101112131415161718191A1B1C1D1E1F20
- 输入: request=0xd0, param1=0
- 输出: resp_len=32, bytes[0]=0x01, bytes[15]=0x10, bytes[31]=0x20

## 5. 覆盖检查

| 条件 | TC1 | TC2 |
|------|:--:|:--:|
| param1 == 1 = Y | ✅ | — |
| param1 == 1 = N | — | ✅ |

| 取值 | TC1 | TC2 |
|------|:--:|:--:|
| param1 = 1 | ✅ | — |
| param1 = 0 | — | ✅ |

✅ 所有代码路径已覆盖。所有条件分支已覆盖。
