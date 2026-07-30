# 中断处理与频率限制 — 测试设计文档

> **✅ 独立 feature**: 原 `interrupt_rate.feature` 于 2026-07-29 从 `fdcan_interrupt.feature` 分离，扩展为独立 feature（Phase H）。移除 `interrupts.h`/`timers.h` e2e 包装器，所有类型/宏集中到 `fake_stm.h`，`init_interrupts(true)` 在 `jna_panda_init()` 中直接调用。

> 被测功能: `board/drivers/interrupts.h` + `board/drivers/timers.h`
> 被测接口: JNA 直接调用 `handle_interrupt()`、`interrupt_timer_handler()` + USB control request 0xc4 验证结果

## 1. 被测功能流程图

```
jna_panda_init():
  [init_interrupts(true)]
          │
          ├→ check_interrupt_rate = true
          ├→ for i=0..162: interrupts[i].handler = unused_interrupt_handler
          └→ interrupt_timer_init()
                ├→ enable_interrupt_timer()  (stub)
                ├→ REGISTER_INTERRUPT(54, interrupt_timer_handler, 2U, FAULT_INTERRUPT_RATE_INTERRUPTS)
                ├→ register_set INTERRUPT_TIMER (TIM6)
                └→ NVIC_EnableIRQ(54)  (stub)

  [tick_timer_init()]
          │
          ├→ timer_init(TICK_TIMER, ...)
          └→ NVIC_EnableIRQ(0)  (stub)

handle_interrupt(irq_type):
  [increment call_counter]
          │
          ▼
  [call interrupts[irq_type].handler()]
          │
          ├→ unused_interrupt_handler() → fault_occurred(FAULT_UNUSED_INTERRUPT_HANDLED)
          ├→ tick_handler() → skips body (TICK_TIMER->SR == 0)
          └→ interrupt_timer_handler() → if SR != 0: 重置计数器, 计算 interrupt_load
          │
          ▼
  [rate check: call_counter > max_call_rate?]
          ├→ Y → fault_occurred(call_rate_fault)
          └→ N → (nothing)

interrupt_timer_handler():  (1 秒定时器 ISR)
  if INTERRUPT_TIMER->SR != 0:
    for i=0..162:
      call_rate[i] = call_counter[i]
      call_counter[i] = 0
    interrupt_load = busy_time / (busy_time + idle_time)
  INTERRUPT_TIMER->SR = 0
```

## 2. 输入因子

| 因子 | 类型 | 等价类 | 取值 |
|------|------|--------|------|
| `irqn` (handle_interrupt) | int | 未注册 IRQ | 1 |
| `irqn` (handle_interrupt) | int | 已注册 IRQ (tick_handler) | 0 |
| `irqn` (handle_interrupt) | int | 已注册 IRQ (TIM6) | 54 |
| `count` (重复调用次数) | int | < max_call_rate | 5 |
| `count` (重复调用次数) | int | > max_call_rate | 11 (trigger rate limit) |
| `interrupt_timer_tick` | — | 触发 1s 定时器 | — |
| `USB 0xc4 param1` | uint16 | IRQ 索引 | 0, 54 |

## 3. 输出因子

| 输出 | 类型 | 说明 |
|------|------|------|
| `readFaults` | int | 故障位掩码 (faults) |
| `respBuffer.bytes[0..3]` | byte[] | call_rate 小端编码 (USB 0xc4) |
| `respBuffer.len` | int | 响应长度 (4 或 0) |

## 4. 测试用例

### TC1: 未注册中断触发 FAULT_UNUSED_INTERRUPT_HANDLED
- 输入: handle_interrupt(1)（IRQ 1 从未注册）
- 输出: readFaults = 2 (bit 1)

### TC2: 频率限制 → FAULT_INTERRUPT_RATE_TICK
- 输入: handle_interrupt(0) × 11（TICK_TIMER_IRQ, max_call_rate=10）
- 输出: readFaults = 2097152 (bit 21)

### TC3: 故障状态在 init 后清零
- 确保 jna_panda_init 后 faults=0

### TC4: interrupt_timer_handler 重置计数器
- 前置: handle_interrupt(0) × 5 → call_counter[0]=5
- 输入: interrupt_timer_tick() → 触发 interrupt_timer_handler
- 输入: USB 0xc4 param1=0
- 输出: resp_len=4, bytes=[0x05, 0x00, 0x00, 0x00]

### TC5 (J6): 频率超标触发 print 警告
- 输入: handle_interrupt(0) × 11 (超过 max_call_rate=10)
- 输入: interrupt_timer_tick() → 触发 interrupt_timer_handler
- 路径: call_counter(11) > max(10) → print("Interrupt 0x0 fired too often...")
- 验证: USB 0xc4 param1=0 → resp bytes=[0x0B, 0x00, 0x00, 0x00] ✅ Phase J

## 5. 覆盖检查

| 代码路径 | TC1 | TC2 | TC3 | TC4 | TC5 |
|---------|:--:|:--:|:--:|:--:|:--:|
| init_interrupts(true) → 初始化 163 handler | — | — | ✅ | ✅ | ✅ |
| unused_interrupt_handler → fault_occurred(2) | ✅ | — | — | — | — |
| handle_interrupt 递增 call_counter | ✅ | ✅ | — | ✅ | ✅ |
| handle_interrupt 调用已注册 handler | — | ✅ | — | ✅ | ✅ |
| handle_interrupt 频率检查 (call_counter > max) | — | ✅ | — | — | ✅ |
| handle_interrupt 频率检查 (call_counter ≤ max) | — | — | — | ✅ | — |
| interrupt_timer_handler 重置计数器 | — | — | — | ✅ | ✅ |
| interrupt_timer_handler 计算 interrupt_load | — | — | — | ✅ | ✅ |
| print("fired too often") (J6) | — | — | — | — | ✅ |
| timer_init() / tick_timer_init() / interrupt_timer_init() | — | — | ✅ | ✅ | ✅ |
| microsecond_timer_init() / microsecond_timer_get() | — | — | ✅ | ✅ | ✅ |

✅ 所有核心代码路径已覆盖 (Phase J 新增 TC5)。

## 覆盖率

> 数据来源: `run_all_coverage.sh` 合并报告
> 综合行覆盖率: **92.9%** (全量)

| 源文件 | 行覆盖 | 说明 |
|--------|--------|------|
| `interrupts.h` | 100% (53/53) | ✅ Phase J: J6 rate print 全覆盖 |
| `timers.h` | 100% (27/27) | timer_init + microsecond_timer_init + interrupt_timer_init + tick_timer_init |
| `main_comms.h` | 97.0% (261/269) | USB 0xc4 命令处理 |

