# CAN FD Non-ISO 模式 — 测试设计文档

> 功能: `bus_config.canfd_non_iso` + `can_init()` via `comms_control_handler()` in `board/main_comms.h`
> 被测接口: USB control request 0xfc (set CAN FD non-ISO mode)

## 1. 被测功能流程图

```
set CAN FD non-ISO (0xfc):
  [controlWrite(0xfc, param1, param2)]
           │
     ┌─────┴──────────────────────┐
     │ param1 < PANDA_CAN_CNT(3) ? │
     └─────┬──────────────────────┘
        N  │  Y
     (no-op)│
            ├── bus_config[param1].canfd_non_iso = (param2 != 0)
            ├── can_init(CAN_NUM_FROM_BUS_NUM(param1))
            │     └── FDCAN CCCR NISO bit updated
            │
            └── (done)
```

## 2. 输入因子

| 因子 | 类型 | 等价类 | 取值 |
|------|------|--------|------|
| `request` | uint8 | 0xfc (唯一) | 0xfc |
| `param1` (bus) | uint16 | <3 (valid), >=3 (invalid) | 0, 3 |
| `param2` | uint16 | ==0 (ISO), !=0 (non-ISO) | 0, 1 |

## 3. 输出因子

| 输出 | 类型 | 说明 |
|------|------|------|
| canfdNonIso0 | boolean | bus 0 non-ISO 标志 |
| fdcanRegs[0].cccr | List\<Byte\> | FDCAN CCCR（含 NISO bit） |

## 4. 测试用例

### TC1: 禁用 non-ISO 模式 (ISO)
- 输入: param1=0, param2=0
- 输出: canfdNonIso0=false, cccr=[0x20, 0x53]

### TC2: 启用 non-ISO 模式
- 输入: param1=0, param2=1
- 输出: canfdNonIso0=true, cccr=[0x20, 0xD3] (NISO bit set)

### TC3: 无效 bus → no-op
- 输入: param1=3, param2=1
- 输出: canfdNonIso 全 false, cccr 不变 = [0x20, 0x53]

## 5. 覆盖检查

| 条件 | TC1 | TC2 | TC3 |
|------|-----|-----|-----|
| param1 < 3 (valid) | ✅ | ✅ | — |
| param1 >= 3 (invalid) | — | — | ✅ |
| param2 == 0 (ISO) | ✅ | — | — |
| param2 != 0 (non-ISO) | — | ✅ | — |
| NISO bit = 0 (ISO mode) | ✅ | — | — |
| NISO bit = 1 (non-ISO mode) | — | ✅ | — |

✅ 所有条件分支和 FDCAN 寄存器变化已覆盖。

## 覆盖率

> 数据来源: `run_all_coverage.sh` 合并报告 (cuatro + tres + red)
> 综合行覆盖率: **65.1%** (全量), 本功能涉及以下源文件:

| 源文件 | 行覆盖 | 说明 |
|--------|--------|------|
| `main_comms.h` | 93.3% (251/269) | USB 命令处理 |
| `can_common.h` | 86.9% (93/107) | CAN 通用操作 |


## C3 更新

禁用场景新增 `Then FDCAN interrupt handlers are registered` 步骤，验证 `can_init()` 中的 `REGISTER_INTERRUPT` 正确填充了 `interrupts[]` 数组（6 个 FDCAN IRQ 处理器 + max_call_rate=16000）。
