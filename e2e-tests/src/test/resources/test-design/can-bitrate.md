# CAN 波特率设置 — 测试设计文档

> 功能: `can_init()` via `comms_control_handler()` in `board/main_comms.h`
> 被测接口: USB control request 0xde (set can bitrate)
> Phase J: 修复 TC1 (param2: 0 → 5000) + 新增 J7 低速 prescaler 场景

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
            │     │     └── speed < 2500? → prescaler *= 16  (J7)
            │     └── can_clear_send → FDCAN TXBC
            │
            └── (done)
```

## 2. 输入因子

| 因子 | 类型 | 等价类 | 取值 |
|------|------|--------|------|
| `request` | uint8 | 0xde (唯一) | 0xde |
| `param1` (bus) | uint16 | <3 (valid), >=3 (invalid) | 0, 3 |
| `param2` (speed) | uint16 | valid: 5000 (500k), 1000 (100k, <2500 低速); invalid: 1 | 5000, 1000, 1 |

## 3. 输出因子

| 输出 | 类型 | 说明 |
|------|------|------|
| fdcanRegs[0].cccr | List\<Byte\> | FDCAN CCCR 寄存器 |
| fdcanRegs[0].nbtp | List\<Byte\> | Nominal Bit Timing (低速时 prescaler×16) |
| fdcanRegs[0].dbtp | List\<Byte\> | Data Bit Timing |

## 4. 测试用例

### TC1 (J8 修复): 有效 bus + 有效速度 (500 kbps) → FDCAN 初始化
- 前置: 默认 SILENT 模式
- 输入: param1=0, param2=5000
- 输出: cccr=[0b0010_0000, 0b0101_0011], nbtp/dbtp 已设置
- 路径: 通过守卫 → can_init(0) → llcan_set_speed(5000)

### TC2: 无效 bus → no-op
- 输入: param1=3, param2=5000
- 路径: param1>=3 → 守卫失败 → no-op

### TC3: 无效速度 → no-op
- 输入: param1=0, param2=1
- 路径: is_speed_valid(1) 失败 → 守卫失败 → no-op

### TC4 (J7): 低速触发 prescaler×16
- 输入: param1=0, param2=1000 (100 kbps, < 2500)
- 输出: nbtp 使用 prescaler×16 计算
- 路径: speed < 2500 → BITRATE_PRESCALER * 16 → llfdcan.h:73-74

## 5. 覆盖检查

| 条件 | TC1 | TC2 | TC3 | TC4 |
|------|:--:|:--:|:--:|:--:|
| param1 < 3 (valid bus) | ✅ | — | ✅ | ✅ |
| param1 >= 3 (invalid) | — | ✅ | — | — |
| is_speed_valid = true | ✅ | — | — | ✅ |
| is_speed_valid = false | — | — | ✅ | — |
| speed < 2500 (prescaler×16) | — | — | — | ✅ |

✅ 所有条件分支已覆盖 (Phase J 新增 TC4)。

## 覆盖率

> 数据来源: `run_all_coverage.sh` 合并报告
> 综合行覆盖率: **92.9%** (全量)

| 源文件 | 行覆盖 | 说明 |
|--------|--------|------|
| `main_comms.h` | 97.0% (261/269) | USB 命令处理 (Phase J: J8 修复 0xde) |
| `llfdcan.h` | 85.1% (137/161) | FDCAN 低速 prescaler 路径 (Phase J: J7) |

