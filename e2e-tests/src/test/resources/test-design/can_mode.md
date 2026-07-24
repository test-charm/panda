# OBD CAN Multiplexing Mode (0xdb) — Test Design

## Feature overview

USB control request `0xdb` sets the CAN multiplexing mode via `current_board->set_can_mode()`:
- `param1 == 1` → `CAN_MODE_OBD_CAN2` (value 1)
- `param1 != 1` → `CAN_MODE_NORMAL` (value 0)

## Flowchart

```
[USB request 0xdb]
        │
        ▼
  param1 == 1?
   ┌───Y───┐
   │       │
   N       │
   │       ▼
   │   set_can_mode(CAN_MODE_OBD_CAN2)  [value=1]
   ▼
set_can_mode(CAN_MODE_NORMAL)           [value=0]
```

## Input factors

| Factor | Type | Equivalence classes | Boundary values |
|--------|------|---------------------|-----------------|
| `param1` | uint16_t | `= 1` (OBD_CAN2), `≠ 1` (NORMAL) | 0, 1, 2 |

## Output factors

| Factor | Description | Values |
|--------|-------------|--------|
| `stopModeRegs.gpioBModer` | GPIOB MODER (pin alternate function) | board-dependent bit patterns |
| `stopModeRegs.gpioBOdr` | GPIOB ODR (CAN transceiver enable) | board-dependent |
| `stopModeRegs.gpioBPupdr` | GPIOB pull-up/down | 0 (no pull) |

> 设计原则: `set_can_mode()` 的所有路径均通过寄存器验证 (`stopModeRegs`)，包括 `param1=2` 场景 —— 该场景虽不触发 GPIO 模式变化（已在 NORMAL 模式），但寄存器值仍可证明函数被正确调用。

## Test cases

| # | Case name | param1 | 寄存器验证 | Notes |
|---|-----------|--------|------------|-------|
| 1 | NORMAL mode with param1=0 | 0 | gpioBModer/gpioBOdr/gpioBPupdr | Default value; register verification covers set_can_mode() |
| 2 | OBD_CAN2 mode with param1=1 | 1 | gpioBModer/gpioBOdr | Only param1=1 triggers OBD_CAN2; register verification covers |
| 3 | NORMAL mode with param1=2 | 2 | gpioBModer/gpioBOdr/gpioBPupdr | Non-1 value falls back to NORMAL; registers prove set_can_mode(0) called |

## Coverage verification

| Criterion | Covered? |
|-----------|----------|
| All code paths covered | ✅ Both branches of `param1 == 1U` |
| Each input value in ≥1 case | ✅ 0, 1, 2 all present |
| Each branch condition covered | ✅ True: case 2, False: cases 1 & 3 |
