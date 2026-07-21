# CAN FD 数据波特率设置 — 测试设计文档

> 功能: `bus_config.can_data_speed` + `canfd_enabled`/`brs_enabled` + `can_init()`
> 被测接口: USB control request 0xf9 (set CAN FD data bitrate)

## 1. 被测功能流程图

```
set CAN FD data bitrate (0xf9):
  [controlWrite(0xf9, param1, param2)]
           │
     ┌─────┴──────────────────────────┐
     │ param1 < PANDA_CAN_CNT(3) &&    │
     │ is_speed_valid(param2,          │
     │   data_speeds)?                  │
     └─────┬──────────────────────────┘
        N  │  Y
     (no-op)│
            ├── bus_config[param1].can_data_speed = param2
            ├── canfd_enabled = (param2 >= can_speed)
            ├── brs_enabled = (param2 > can_speed)
            ├── can_init(CAN_NUM_FROM_BUS_NUM(param1))
            │
            └── (done)
```

e2e 环境: `data_speeds={0}`, `can_speed=5000`，仅 `param2=0` 有效。
`canfd_enabled = (0 >= 5000) → false`, `brs_enabled = (0 > 5000) → false`。

## 2. 输入因子

| 因子 | 类型 | 等价类 | 取值 |
|------|------|--------|------|
| `request` | uint8 | 0xf9 (唯一) | 0xf9 |
| `param1` (bus) | uint16 | <3 (valid), >=3 (invalid) | 0, 3 |
| `param2` (data speed) | uint16 | 0 (valid), !=0 (invalid) | 0, 1 |

## 3. 输出因子

| 输出 | 类型 | 说明 |
|------|------|------|
| canfdEnabled0 | boolean | bus 0 CAN FD 使能标志 |
| brsEnabled0 | boolean | bus 0 BRS 使能标志 |
| fdcanRegs[0].cccr | List\<Byte\> | FDCAN CCCR（初始化后） |

## 4. 测试用例

### TC1: 有效 bus + 有效速度
- 输入: param1=0, param2=0
- 输出: canfdEnabled0=false, brsEnabled0=false, cccr=[0x20, 0x53]
- 路径: 通过守卫 → 设置标志 → can_init

### TC2: 无效 bus → no-op
- 输入: param1=3, param2=0
- 输出: 所有标志为 false, cccr 不变

### TC3: 无效速度 → no-op
- 输入: param1=0, param2=1
- 输出: canfdEnabled0=false, brsEnabled0=false, cccr 不变

## 5. 覆盖检查

| 条件 | TC1 | TC2 | TC3 |
|------|-----|-----|-----|
| param1 < 3 (valid bus) | ✅ | — | ✅ |
| param1 >= 3 (invalid) | — | ✅ | — |
| is_speed_valid = true | ✅ | — | — |
| is_speed_valid = false | — | — | ✅ |

✅ 所有条件分支已覆盖。
