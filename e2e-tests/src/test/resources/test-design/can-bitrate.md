# CAN 波特率设置 — 测试设计文档

> 功能: `can_init()` via `comms_control_handler()` in `board/main_comms.h`
> 被测接口: USB control request 0xde (set can bitrate)

## 1. 被测功能流程图

```
set can bitrate (0xde):
  [controlWrite(0xde, param1, param2)]
           │
     ┌─────┴──────────────────────┐
     │ param1 < PANDA_CAN_CNT(3)   │
     │ && is_speed_valid(param2)?  │
     └─────┬──────────────────────┘
        N  │  Y
     (no-op)│
            ├── bus_config[param1].can_speed = param2
            ├── can_init(CAN_NUM_FROM_BUS_NUM(param1))
            │     ├── llcan_set_speed → FDCAN NBTP/DBTP/CCCR
            │     └── can_clear_send → FDCAN TXBC
            │
            └── (done)
```

e2e 环境中 `speeds={0}`，仅 `param2=0` 为有效速度。

## 2. 输入因子

| 因子 | 类型 | 等价类 | 取值 |
|------|------|--------|------|
| `request` | uint8 | 0xde (唯一) | 0xde |
| `param1` (bus) | uint16 | <3 (valid), >=3 (invalid) | 0, 3 |
| `param2` (speed) | uint16 | 0 (valid, in speeds[]), !=0 (invalid) | 0, 1 |

## 3. 输出因子

| 输出 | 类型 | 说明 |
|------|------|------|
| fdcanRegs[0].cccr | List\<Byte\> | FDCAN CCCR 寄存器 |

## 4. 测试用例

### TC1: 有效 bus + 有效速度 → FDCAN 初始化
- 前置: 默认 SILENT 模式
- 输入: param1=0, param2=0
- 输出: cccr=[0b0010_0000, 0b0101_0011]
- 路径: 通过守卫 → can_init(0)

### TC2: 无效 bus → no-op
- 前置: 默认 SILENT 模式
- 输入: param1=3, param2=0
- 输出: cccr 不变 (SILENT 默认值)
- 路径: param1>=3 → 守卫失败 → no-op

### TC3: 无效速度 → no-op
- 前置: 默认 SILENT 模式
- 输入: param1=0, param2=1
- 输出: cccr 不变 (SILENT 默认值)
- 路径: is_speed_valid(1) 失败 → 守卫失败 → no-op

## 5. 覆盖检查

| 条件 | TC1 | TC2 | TC3 |
|------|-----|-----|-----|
| param1 < 3 (valid bus) | ✅ | — | ✅ |
| param1 >= 3 (invalid) | — | ✅ | — |
| is_speed_valid = true | ✅ | — | — |
| is_speed_valid = false | — | — | ✅ |

✅ 所有条件分支已覆盖。
