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
| `canModeCall.value` | The mode passed to `set_can_mode()` (仅无寄存器操作的场景使用) | 0 (NORMAL), 1 (OBD_CAN2) |

> 设计原则: 寄存器验证 (`stopModeRegs`) 已覆盖 `set_can_mode()` 行为时，不再重复验证 `canModeCall`。仅当场景无寄存器操作时（如 `param1=2` 不触发 GPIO 配置）才保留 `canModeCall` 验证。

## Test cases

| # | Case name | param1 | canModeCall.value | 寄存器验证 | Notes |
|---|-----------|--------|--------------------|------------|-------|
| 1 | NORMAL mode with param1=0 | 0 | — | gpioBModer/gpioBOdr/gpioBPupdr | Default value; register verification covers set_can_mode() |
| 2 | OBD_CAN2 mode with param1=1 | 1 | — | gpioBModer/gpioBOdr | Only param1=1 triggers OBD_CAN2; register verification covers |
| 3 | NORMAL mode with param1=2 | 2 | 0 | (none) | Non-1 value falls back to NORMAL, no GPIO reconfiguration |

## Coverage verification

| Criterion | Covered? |
|-----------|----------|
| All code paths covered | ✅ Both branches of `param1 == 1U` |
| Each input value in ≥1 case | ✅ 0, 1, 2 all present |
| Each branch condition covered | ✅ True: case 2, False: cases 1 & 3 |
