# CAN 环形缓冲区清除 — 测试设计文档

> 功能: CAN 环形缓冲区清除 via `comms_control_handler()` in `board/main_comms.h`
> 被测接口: USB control request 0xf1 (clear CAN ring buffer)

## 1. 被测功能流程图

```
clear CAN ring (0xf1):
  [controlWrite(0xf1, param1)]
           │
     ┌─────┼──────────────────────────┐
     │ param1 == 0xFFFF ?              │
     └─────┬──────────────────────────┘
        Y  │  N
     ┌─────┴──────┐
     │             │
  can_clear     param1 < PANDA_CAN_CNT(3) ?
  (&can_rx_q)      │
                ┌──┴──┐
             Y  │     │ N
          ┌──────┴──┐  │
          │          │  │
     can_clear    print error
     (can_queues  (no-op)
      [param1])
```

## 2. 输入因子

| 因子 | 类型 | 等价类 | 取值 |
|------|------|--------|------|
| `request` | uint8 | 0xf1 (唯一) | 0xf1 |
| `param1` | uint16 | ==0xFFFF (清除 RX), <3 (清除 TX bus N), >=3 (无效) | -1(0xFFFF), 0, 1, 2, 3 |

## 3. 输出因子

| 输出 | 类型 | 说明 |
|------|------|------|
| rxQueue | list | CAN RX 队列 (清空后为空) |
| txQueue[0] | list | CAN TX bus 0 队列 |
| txQueue[1] | list | CAN TX bus 1 队列 |
| txQueue[2] | list | CAN TX bus 2 队列 |

## 4. 测试用例

### TC1: 清除 RX 队列 (param1=0xFFFF/-1)
- 前置: 发送被阻止的 CAN 消息 (进入 can_rx_q)
- 输入: request=0xf1, param1=0xFFFF (-1 as short)
- 输出: rxQueue=[]
- 路径: param1==0xFFFF → can_clear(&can_rx_q)

### TC2: 清除 TX bus 0 队列 (param1=0)
- 前置: ALLOUTPUT 模式发送一条消息 (进入 can_tx1_q)
- 输入: request=0xf1, param1=0
- 输出: txQueue[0]=[]
- 路径: param1 < 3 → can_clear(can_queues[0])

### TC3: 清除 TX bus 1 队列 (param1=1)
- 前置: ALLOUTPUT 模式发送一条消息
- 输入: request=0xf1, param1=1
- 输出: txQueue[1]=[]
- 路径: param1 < 3 → can_clear(can_queues[1])

### TC4: 无效 bus 编号 (param1=3)
- 前置: ALLOUTPUT 模式发送一条消息
- 输入: request=0xf1, param1=3
- 输出: txQueue[0] 仍有消息 (不清除)
- 路径: param1 >= 3 → print error → no-op

## 5. 覆盖检查

| 条件 | TC1 | TC2 | TC3 | TC4 |
|------|-----|-----|-----|-----|
| param1 == 0xFFFF | ✅ | — | — | — |
| param1 < 3 (TX bus) | — | ✅ | ✅ | — |
| param1 >= 3 (invalid) | — | — | — | ✅ |

✅ 所有代码路径已覆盖。
