# 中断调用率读取 — 测试设计文档

> 功能: get interrupt call rate via `comms_control_handler()` in `board/main_comms.h`
> 被测接口: USB control request 0xc4 (get interrupt call rate)

## 1. 被测功能流程图

```
get interrupt call rate (0xc4):
  [controlWrite(0xc4, param1, 0)]
           │
           ▼
  param1 < NUM_INTERRUPTS (16)?
     ├── Y → load = interrupts[param1].call_rate
     │        resp[0..3] = LE(load)
     │        resp_len = 4
     └── N → (nothing, resp_len stays 0)
```

## 2. 输入因子

| 因子 | 类型 | 等价类 | 取值 |
|------|------|--------|------|
| `request` | uint8 | 0xc4 (唯一) | 0xc4 |
| `param1` | uint16 | 在范围内 0..15 | 7 |
| `param1` | uint16 | 在范围内 0..15 | 0 |
| `param1` | uint16 | 超出范围 >=16 | 16 |
| `interruptCallRate` (前置) | uint32 | 非零值 | 0x12345678 |
| `interruptCallRate` (前置) | uint32 | 零值 | 0 |

## 3. 输出因子

| 输出 | 类型 | 说明 |
|------|------|------|
| respBuffer.len | int | 4 (范围内) 或 0 (范围外) |
| respBuffer.bytes[0..3] | byte[] | call_rate 小端编码 |

## 4. 测试用例

### TC1: 索引越界 → 零长度响应
- 输入: request=0xc4, param1=16（>=NUM_INTERRUPTS）
- 输出: resp_len=0

### TC2: 有效索引+预设值 → 返回 4 字节
- 前置: 设 interruptIndex=7, interruptCallRate=0x12345678
- 输入: request=0xc4, param1=7
- 输出: resp_len=4, bytes=[0x78, 0x56, 0x34, 0x12]

### TC3: 有效索引+零值 → 返回全零
- 前置: 设 interruptIndex=0, interruptCallRate=0
- 输入: request=0xc4, param1=0
- 输出: resp_len=4, bytes=[0, 0, 0, 0]

## 5. 覆盖检查

| 条件 | TC1 | TC2 | TC3 |
|------|:--:|:--:|:--:|
| param1 < NUM_INTERRUPTS = Y | — | ✅ | ✅ |
| param1 < NUM_INTERRUPTS = N | ✅ | — | — |

| 取值 | TC1 | TC2 | TC3 |
|------|:--:|:--:|:--:|
| param1 = 16 (越界) | ✅ | — | — |
| param1 = 7 (有效) | — | ✅ | — |
| param1 = 0 (有效+边界) | — | — | ✅ |
| interruptCallRate = 0x12345678 | — | ✅ | — |
| interruptCallRate = 0 | — | — | ✅ |

✅ 所有代码路径已覆盖。所有条件分支判断点已覆盖。
