# 微秒定时器读取 — 测试设计文档

> 功能: get microsecond timer via `comms_control_handler()` in `board/main_comms.h`
> 被测接口: USB control request 0xa8 (get microsecond timer)

## 1. 被测功能流程图

```
get microsecond timer (0xa8):
  [controlWrite(0xa8, 0, 0)]
           │
           ▼
  time = microsecond_timer_get()
           │
           ▼
  resp[0] = time & 0xFF           (LSB)
  resp[1] = (time >> 8) & 0xFF
  resp[2] = (time >> 16) & 0xFF
  resp[3] = (time >> 24) & 0xFF   (MSB)
  resp_len = 4
           │
           ▼
        (done)
```

## 2. 输入因子

| 因子 | 类型 | 等价类 | 取值 |
|------|------|--------|------|
| `request` | uint8 | 0xa8 (唯一) | 0xa8 |
| `timerValue` (前置) | uint32 | 非零值 | 0x12345678 |
| `timerValue` (前置) | uint32 | 零值边界 | 0x00000000 |

## 3. 输出因子

| 输出 | 类型 | 说明 |
|------|------|------|
| respBuffer.len | int | resp_len = 4 |
| respBuffer.bytes[0] | byte | (timerValue & 0xFF) |
| respBuffer.bytes[1] | byte | ((timerValue >> 8) & 0xFF) |
| respBuffer.bytes[2] | byte | ((timerValue >> 16) & 0xFF) |
| respBuffer.bytes[3] | byte | ((timerValue >> 24) & 0xFF) |

## 4. 测试用例

### TC1: 预设非零 timer 值 → 返回 4 字节小端编码
- 前置: 设 timerValue=0x12345678
- 输入: request=0xa8
- 输出: resp_len=4, bytes=[0x78, 0x56, 0x34, 0x12]

### TC2: 预设零 timer 值 → 返回全零字节
- 前置: 设 timerValue=0x00000000 (默认值)
- 输入: request=0xa8
- 输出: resp_len=4, bytes=[0x00, 0x00, 0x00, 0x00]

## 5. 覆盖检查

| 条件 | TC1 | TC2 |
|------|:--:|:--:|
| 单一路径（无分支） | ✅ | ✅ |

| 取值 | TC1 | TC2 |
|------|:--:|:--:|
| timerValue = 0x12345678 | ✅ | — |
| timerValue = 0x00000000 | — | ✅ |

✅ 代码路径已覆盖。所有输入因子取值已覆盖。
