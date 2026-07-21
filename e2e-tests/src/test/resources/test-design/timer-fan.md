# 微秒定时器与风扇转速 — 测试设计文档

> 功能: get microsecond timer (0xa8) and fan RPM (0xb2) via `comms_control_handler()`
> 被测接口: USB control request 0xa8 / 0xb2

## 1. 被测功能流程图

```
get microsecond timer (0xa8):
  [controlWrite(0xa8, 0, 0)]
           │
           ▼
  time = microsecond_timer_get()
  resp[0..3] = time (little-endian)
  resp_len = 4
           │
           ▼
        (done)

get fan RPM (0xb2):
  [controlWrite(0xb2, 0, 0)]
           │
           ▼
  resp[0..1] = fan_state.rpm (little-endian)
  resp_len = 2
           │
           ▼
        (done)
```

## 2. 输入因子

| 因子 | 类型 | 等价类 | 取值 |
|------|------|--------|------|
| `request` | uint8 | 0xa8 / 0xb2 | 0xa8, 0xb2 |
| `MICROSECOND_TIMER->CNT` (前置) | uint32 | 非零值 | 0x12345678 |
| `fan_state.rpm` (前置) | uint16 | 非零值 | 0x1234 |

## 3. 输出因子

| 输出 | 类型 | 说明 |
|------|------|------|
| respBuffer.len | int | 4 (timer) / 2 (fan) |
| respBuffer.bytes | List\<Byte\> | little-endian 拆分值 |

## 4. 测试用例

### TC1: 读取 microsecond timer
- 前置: 设 CNT=0x12345678 (305419896)
- 输入: request=0xa8
- 输出: resp_len=4, bytes=[0x78, 0x56, 0x34, 0x12]

### TC2: 读取 fan RPM
- 前置: 设 rpm=0x1234 (4660)
- 输入: request=0xb2
- 输出: resp_len=2, bytes=[0x34, 0x12]

## 5. 覆盖检查

| 条件 | TC1 | TC2 |
|------|-----|-----|
| request 0xa8 | ✅ | — |
| request 0xb2 | — | ✅ |

✅ 所有代码路径已覆盖。
