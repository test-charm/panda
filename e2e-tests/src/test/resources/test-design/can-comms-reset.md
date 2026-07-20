# CAN 通信重置 — 测试设计文档

> 功能: `comms_can_reset()` via `comms_control_handler()` in `board/main_comms.h`
> 被测接口: USB control request 0xc0 (reset communications state)

## 1. 被测功能流程图

```
reset CAN comms (0xc0):
  [controlWrite(0xc0, 0, 0)]
           │
           ▼
     comms_can_reset()
           │
     ┌─────┴─────────────────────────┐
     │  can_read_buffer.ptr = 0       │
     │  can_read_buffer.tail_size = 0 │
     │  can_write_buffer.ptr = 0      │
     │  can_write_buffer.tail_size = 0│
     └───────────────────────────────┘
           │
           ▼
        (done)
```

代码路径为直线，无分支。重置 USB/SPI CAN 通信缓冲区，不影响 CAN 硬件队列或安全模式。

## 2. 输入因子

| 因子 | 类型 | 等价类 | 取值 |
|------|------|--------|------|
| `request` | uint8 | 0xc0 (唯一) | 0xc0 |
| `param1` | uint16 | 未使用 (忽略) | 0 |
| `param2` | uint16 | 未使用 (忽略) | 0 |

## 3. 输出因子

| 输出 | 类型 | 说明 |
|------|------|------|
| readBufferPtr | int | can_read_buffer.ptr |
| readBufferTail | int | can_read_buffer.tail_size |
| writeBufferPtr | int | can_write_buffer.ptr |
| writeBufferTail | int | can_write_buffer.tail_size |
| safetyTxBlocked | int | 安全模式不变 |
| relayCall | RelayCall | 继电器不变 |

## 4. 测试用例

### TC1: 重置从干净状态 — 缓冲区均为 0
- 前置: 初始状态 (所有缓冲区 = 0)
- 输入: request=0xc0, param1=0
- 输出: readBufferPtr=0, writeBufferPtr=0, readBufferTail=0, writeBufferTail=0
- 路径: comms_can_reset() → 全置零

### TC2: 重置不影响安全模式和 relay 状态
- 前置: SILENT 模式
- 输入: request=0xc0, param1=0
- 输出: safetyTxBlocked=0, relay=a=false/b=false
- 路径: 重置仅操作通信缓冲区，不影响其他状态

### TC3: 切换安全模式后重置 — 现有状态不变 (ALLOUTPUT)
- 前置: ALLOUTPUT 模式 (relay_a=true)
- 输入: request=0xc0, param1=0
- 输出: relay.a=true, relay.b=false (ALLOUTPUT 状态不变)
- 路径: 验证重置不会回退安全模式

## 5. 覆盖检查

| 条件 | TC1 | TC2 | TC3 |
|------|-----|-----|-----|
| 缓冲区初始化清零 | ✅ | — | — |
| 不影响安全模式 | — | ✅ | — |
| 不影响 relay | — | ✅ | ✅ |
| 不影响 CAN 队列 | ✅ | — | — |

✅ 所有代码路径已覆盖。
