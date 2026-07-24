# UART 读取 — 测试设计文档

> 功能: uart read via `comms_control_handler()` in `board/main_comms.h`
> 被测接口: USB control request 0xe0 (uart read)

## 1. 被测功能流程图

```
uart read (0xe0):
  [controlWrite(0xe0, param1, 0)]
           │
           ▼
  ur = get_ring_by_number(param1)
           │
     ┌─────┴─────┐
     ▼           ▼
   NULL       valid ring
     │           │
     ▼           ▼
   break    req_length = MIN(length, USBPACKET_MAX_SIZE)
            while resp_len < req_length && get_char():
                read byte, resp_len++
```

## 2. 输入因子

| 因子 | 类型 | 等价类 | 取值 |
|------|------|--------|------|
| `request` | uint8 | 0xe0 (唯一) | 0xe0 |
| `param1` | uint16 | 无效 ring 号 | 99 |
| `param1` | uint16 | ring 0 (debug) 空 | 0 |
| `param1` | uint16 | ring 0 (debug) 有数据 | 0 |
| `length` | uint16 | 非零请求长度 | 5 |
| `uartData` (前置) | String | 预填充"HELLO" | "HELLO" |

## 3. 输出因子

| 输出 | 类型 | 说明 |
|------|------|------|
| respBuffer.len | int | 读取的字节数 |
| respBuffer.bytes | byte[] | 读取到的字符 |

## 4. 测试用例

### TC1: 无效 ring 号 → NULL → 零长度响应
- 输入: request=0xe0, param1=99
- 输出: resp_len=0

### TC2: 有效 ring 空数据 → 零长度响应
- 输入: request=0xe0, param1=0, length=5
- 输出: resp_len=0

### TC3: 有效 ring 有"HELLO" → 读取 5 字节
- 前置: uartData="HELLO"
- 输入: request=0xe0, param1=0, length=5
- 输出: resp_len=5, bytes=[H,E,L,L,O]

## 5. 覆盖检查

| 条件 | TC1 | TC2 | TC3 |
|------|:--:|:--:|:--:|
| get_ring_by_number == NULL | ✅ | — | — |
| ring exists, empty | — | ✅ | — |
| ring exists, has data | — | — | ✅ |

✅ 所有分支已覆盖。
