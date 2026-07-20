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
| `canModeCall.value` | The mode passed to `set_can_mode()` | 0 (NORMAL), 1 (OBD_CAN2) |

## Test cases

| # | Case name | param1 | canModeCall.value | Notes |
|---|-----------|--------|--------------------|-------|
| 1 | NORMAL mode with param1=0 | 0 | 0 | Shortest path; default value |
| 2 | OBD_CAN2 mode with param1=1 | 1 | 1 | Only param1 value that triggers OBD_CAN2 |
| 3 | NORMAL mode with param1=2 | 2 | 0 | Non-1 value falls back to NORMAL |

## Coverage verification

| Criterion | Covered? |
|-----------|----------|
| All code paths covered | ✅ Both branches of `param1 == 1U` |
| Each input value in ≥1 case | ✅ 0, 1, 2 all present |
| Each branch condition covered | ✅ True: case 2, False: cases 1 & 3 |
