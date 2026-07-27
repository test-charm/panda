# CAN 队列指针回绕 — 测试设计文档

> 功能: `can_pop()` / `can_push()` / `can_slots_empty()` in `board/drivers/can_common.h`
> 被测路径: 环形队列满时 w_ptr/r_ptr 回绕到 0、push 失败返回 false、w_ptr < r_ptr 时 slots_empty 计算
> 调用: 直接 JNA 操作队列状态 (`jna_set_can_queue_state` / `jna_can_push_direct` / `jna_can_pop_direct` / `jna_can_slots_empty`)

## 1. 被测功能流程图

```
can_pop(q):
  [w_ptr != r_ptr?]  ──N──→ return false (空队列)
        │ Y
        ▼
  *elem = q->elems[r_ptr]
        │
  [r_ptr+1 == fifo_size?]
   ┌──Y──┐          ┌──N──┐
   │     │          │     │
   ▼     │          ▼     │
  r_ptr  │        r_ptr++ │
  = 0    │                │
   │     │          │     │
   └──┬──┘          └──┬──┘
      ▼                ▼
  return true


can_push(q, elem):
  [w_ptr+1 == fifo_size?]
   ┌──Y──┐          ┌──N──┐
   │     │          │     │
   ▼     │          ▼     │
  next   │        next    │
  = 0    │        = w_ptr+1
   │     │          │     │
   └──┬──┘          └──┬──┘
      ▼                ▼
  [next != r_ptr?]  ──N──→ return false (队列满)
        │ Y
        ▼
  elems[w_ptr] = elem
  w_ptr = next
  return true


can_slots_empty(q):
  [w_ptr >= r_ptr?]
   ┌──Y──┐          ┌──N──┐
   │     │          │     │
   ▼     │          ▼     │
  fifo   │        r_ptr    │
  -1-w   │        -w_ptr   │
  +r     │        -1       │
   │     │          │     │
   └──┬──┘          └──┬──┘
      ▼                ▼
  return ret
```

## 2. e2e 测试机制

`can_common.h` 中队列很大（TX: 416, RX: 4096），正常 push/pop 需要大量操作才能触发回绕。测试通过 JNA 直接设置 `w_ptr` / `r_ptr` 到接近 `fifo_size` 的位置，用少量操作触发回绕条件。

新增 JNA 函数（`e2e-tests/src/test/c/libpanda.c`）：

| JNA 函数 | 作用 |
|---------|------|
| `jna_set_can_queue_state(idx, w, r)` | 直接设置队列 w_ptr / r_ptr |
| `jna_get_can_queue_state(idx, &w, &r, &f)` | 读取队列当前 w_ptr / r_ptr / fifo_size |
| `jna_can_push_direct(idx, addr, bus, data, len)` | 直接调用 `can_push()`（绕过 safety hook） |
| `jna_can_pop_direct(idx, &addr, &bus, &data, &len)` | 直接调用 `can_pop()` |
| `jna_can_slots_empty(idx)` | 调用 `can_slots_empty()` |

队列编号: `queue_idx`: 0=rx_q, 1=tx1_q, 2=tx2_q, 3=tx3_q。测试使用 `queue_idx=1`（tx1_q, `fifo_size=416`）。

因为 DAL 表达式不支持带参 getter（如 `canQueueState(1).wPtr`），改为使用存储字段：
- `lastQueueWPtr` / `lastQueueRPtr` / `lastQueueFifoSize` — 通过 `When refresh queue {int} state` 刷新
- `lastCanSlotsEmptyVal` — 通过 `When refresh can slots empty for queue {int}` 刷新
- `canPushResult` — `When can push direct to queue {int}` 自动存储

Given 前置使用 `CanQueue` 表驱动 (jfactory spec + DataRepository)，自动调用 `jna_set_can_queue_state`：
```gherkin
Given exists data:
  """
  CanQueue: | queueNum | w_ptr | r_ptr |
            | 1        | 415   | 0     |
  """
```

## 3. 关键常量

| 常量 | 值 | 含义 |
|------|----|------|
| `CAN_TX_BUFFER_SIZE` | 416 | TX 队列大小 (index 1-3) |
| `CAN_RX_BUFFER_SIZE` | 4096 | RX 队列大小 (index 0) |
| `fifo_size - 1` (TX) | 415 | 回绕触发点 |

## 4. 输入因子

| 因子 | 类型 | 等价类 | 说明 |
|------|------|--------|------|
| w_ptr | uint32_t | 任意, <415, =415 | 写指针位置 |
| r_ptr | uint32_t | 任意, <415, =415 | 读指针位置 |
| 操作 | enum | pull, push, slots_empty | 被测函数 |
| push data | byte[] | 空/非空 | 推入数据 |

## 5. 输出因子

| 输出 | 类型 | 说明 |
|------|------|------|
| `lastQueueWPtr` | int | 操作后 w_ptr |
| `lastQueueRPtr` | int | 操作后 r_ptr |
| `lastQueueFifoSize` | int | 队列容量 |
| `canPushResult` | boolean | push 是否成功 |
| `lastCanSlotsEmptyVal` | int | 空闲槽位数 |

## 6. 测试用例

### TC1: r_ptr wraps to 0 when can_pop reads last element
- 前置: w_ptr=1, r_ptr=415 (=fifo_size-1)
- 步骤: `can_push_direct` → `can_pop_direct`
- 验证: lastQueueWPtr=2, lastQueueRPtr=0 (r_ptr 从 415 回绕到 0)
- 路径: `can_pop` → `w_ptr != r_ptr` → `r_ptr+1 == fifo_size` → `r_ptr = 0`
- 场景: `can_queue_wrap.feature:19`
- 覆盖行: 47

### TC2: w_ptr wraps to 0 (next_w_ptr) when can_push at end of queue
- 前置: w_ptr=415, r_ptr=1 (队列未满)
- 步骤: `can_push_direct`
- 验证: lastQueueWPtr=0, lastQueueRPtr=1 (w_ptr 从 415 回绕到 0)
- 路径: `can_push` → `w_ptr+1 == fifo_size` → `next_w_ptr = 0` → `next_w_ptr != r_ptr` → push 成功
- 场景: `can_queue_wrap.feature:35`
- 覆盖行: 64

### TC3: can_push fails when queue is full (w_ptr at end, r_ptr at 0)
- 前置: w_ptr=415, r_ptr=0 (next_w_ptr=0 == r_ptr → 满)
- 步骤: `can_push_direct`
- 验证: lastQueueWPtr=415, lastQueueRPtr=0 (不变), canPushResult=false
- 路径: `can_push` → `next_w_ptr = 0` → `next_w_ptr == r_ptr` → push 失败 → `!ret` 闭合
- 场景: `can_queue_wrap.feature:50`
- 覆盖行: 90

### TC4: can_slots_empty returns correct count when w_ptr < r_ptr (wrap)
- 前置: w_ptr=100, r_ptr=200 (w_ptr < r_ptr, 回绕态)
- 步骤: `jna_can_slots_empty(1)`
- 验证: lastCanSlotsEmptyVal=99 (= 200 - 100 - 1)
- 路径: `can_slots_empty` → `w_ptr < r_ptr` (else 分支) → `ret = r_ptr - w_ptr - 1`
- 场景: `can_queue_wrap.feature:66`
- 覆盖行: 101, 102

### TC5: can_slots_empty with w_ptr >= r_ptr (non-wrap) for regression
- 前置: w_ptr=200, r_ptr=100 (w_ptr >= r_ptr, 正常态)
- 步骤: `jna_can_slots_empty(1)`
- 验证: lastCanSlotsEmptyVal=315 (= 416 - 1 - 200 + 100)
- 路径: `can_slots_empty` → `w_ptr >= r_ptr` (if 分支)
- 场景: `can_queue_wrap.feature:80`

## 7. 覆盖检查

| 被测行 | 代码 | TC1 | TC2 | TC3 | TC4 | TC5 |
|--------|------|-----|-----|-----|-----|-----|
| 47 | `q->r_ptr = 0` (r_ptr 回绕) | ✅ | — | — | — | — |
| 64 | `next_w_ptr = 0` (w_ptr 回绕) | — | ✅ | ✅ | — | — |
| 90 | `}` (push 失败闭合) | — | — | ✅ | — | — |
| 101 | `ret = q->r_ptr - q->w_ptr - 1U` | — | — | — | ✅ | — |
| 102 | `}` (else 闭合) | — | — | — | ✅ | — |
| 44 | `w_ptr != r_ptr` (pop 非空) | ✅ | — | — | — | — |
| 49 | `r_ptr += 1U` (正常 r_ptr) | — | — | — | — | — |
| 66 | `next_w_ptr = q->w_ptr + 1U` | ✅ | — | — | — | — |
| 68 | `next_w_ptr != q->r_ptr` (push 成功) | ✅ | ✅ | — | — | — |
| 98-99 | `w_ptr >= r_ptr` + formula | ✅ | ✅ | ✅ | — | ✅ |

## 8. 与其他测试的关系

| 路径 | can_comms | can_mode | can_ring_clear | can_queue_wrap (本次) |
|------|:--:|:--:|:--:|:--:|
| can_pop 正常 r_ptr++ | ✅ | ✅ | — | — |
| can_pop r_ptr 回绕 | — | — | — | ✅ |
| can_push 正常 w_ptr++ | ✅ | ✅ | — | — |
| can_push w_ptr 回绕 | — | — | — | ✅ |
| can_push 队满返回 false | — | — | — | ✅ |
| can_slots_empty w_ptr >= r_ptr | ✅ | ✅ | — | ✅ |
| can_slots_empty w_ptr < r_ptr | — | — | — | ✅ |
| can_clear | — | — | ✅ | — |

## 覆盖率

> 数据来源: `run_all_coverage.sh` 合并报告 (cuatro + tres + red)
> 生成时间: 2026-07-27 (N4 完成)

| 源文件 | 行覆盖 | 说明 |
|--------|--------|------|
| `can_common.h` | **100%** (107/107) | can_pop / can_push / can_slots_empty / can_clear 全路径 |
