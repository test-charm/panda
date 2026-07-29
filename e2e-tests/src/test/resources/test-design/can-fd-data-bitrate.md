# CAN FD 配置 — 测试设计文档

> 功能: CAN FD 数据波特率 (0xf9) + Non-ISO 模式 (0xfc) + 自动切换 (0xe8)
> 被测接口: USB control request 0xf9 / 0xfc / 0xe8
> 合并自: `can-fd-data-bitrate.md` + `can-fd-non-iso.md` + `can-fd-auto.md` (第十三节 D1+D2 合并)

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

## 覆盖率

> 数据来源: `run_all_coverage.sh` 合并报告 (cuatro + tres + red)
> 综合行覆盖率: **65.1%** (全量), 本功能涉及以下源文件:

| 源文件 | 行覆盖 | 说明 |
|--------|--------|------|
| `main_comms.h` | 93.3% (251/269) | USB 命令处理 |
| `can_common.h` | 86.9% (93/107) | CAN 通用操作 |

---

## 6. CAN FD Non-ISO 模式 (0xfc)

### 被测功能流程图

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

### 输入因子

| 因子 | 类型 | 等价类 | 取值 |
|------|------|--------|------|
| `request` | uint8 | 0xfc (唯一) | 0xfc |
| `param1` (bus) | uint16 | <3 (valid), >=3 (invalid) | 0, 3 |
| `param2` | uint16 | ==0 (ISO), !=0 (non-ISO) | 0, 1 |

### 输出因子

| 输出 | 类型 | 说明 |
|------|------|------|
| canfdNonIso0 | boolean | bus 0 non-ISO 标志 |
| fdcanRegs[0].cccr | List\<Byte\> | FDCAN CCCR（含 NISO bit） |

### 测试用例

#### TC-N1: 禁用 non-ISO 模式 (ISO)
- 输入: param1=0, param2=0
- 输出: canfdNonIso0=false, cccr=[0x20, 0x53]

#### TC-N2: 启用 non-ISO 模式
- 输入: param1=0, param2=1
- 输出: canfdNonIso0=true, cccr=[0x20, 0xD3] (NISO bit set)

#### TC-N3: 无效 bus → no-op
- 输入: param1=3, param2=1
- 输出: canfdNonIso 全 false, cccr 不变 = [0x20, 0x53]

### 覆盖检查

| 条件 | TC-N1 | TC-N2 | TC-N3 |
|------|:--:|:--:|:--:|
| param1 < 3 (valid) | ✅ | ✅ | — |
| param1 >= 3 (invalid) | — | — | ✅ |
| param2 == 0 (ISO) | ✅ | — | — |
| param2 != 0 (non-ISO) | — | ✅ | — |
| NISO bit = 0 | ✅ | — | — |
| NISO bit = 1 | — | ✅ | — |

✅ 所有条件分支和 FDCAN 寄存器变化已覆盖。

> C3 更新: 禁用场景新增 `Then FDCAN interrupt handlers are registered` 步骤，验证 `can_init()` 中的 `REGISTER_INTERRUPT` 正确填充了 `interrupts[]` 数组（6 个 FDCAN IRQ 处理器 + max_call_rate=16000）。

---

## 7. CAN FD 自动切换 (0xe8)

### 被测功能流程图

```
set CAN FD auto (0xe8):
  [controlWrite(0xe8, param1, param2)]
           │
           ▼
  bus_config[param1].canfd_auto = (param2 > 0)
           │
           ▼
        (done)
```

代码路径为直线，无分支。不调用 `can_init()`，无 FDCAN 副作用。

### 输入因子

| 因子 | 类型 | 等价类 | 取值 |
|------|------|--------|------|
| `request` | uint8 | 0xe8 (唯一) | 0xe8 |
| `param1` (bus) | uint16 | 0, 1, 2 (任意 bus) | 0, 1 |
| `param2` | uint16 | ==0 (disable), !=0 (enable) | 0, 1, 255 |

### 输出因子

| 输出 | 类型 | 说明 |
|------|------|------|
| canfdAutoN | boolean | bus N 的 CAN FD 自动切换标志 |

### 测试用例

#### TC-A1: 禁用 CAN FD 自动切换
- 输入: param1=0, param2=0
- 输出: canfdAuto0=false

#### TC-A2: 启用 bus 0 自动切换
- 输入: param1=0, param2=1
- 输出: canfdAuto0=true, canfdAuto1=false

#### TC-A3: 任意非零 param2 启用
- 输入: param1=1, param2=255
- 输出: canfdAuto1=true

### 覆盖检查

| 条件 | TC-A1 | TC-A2 | TC-A3 |
|------|:--:|:--:|:--:|
| param2 == 0 | ✅ | — | — |
| param2 != 0 | — | ✅ | ✅ |

✅ 所有等价类已覆盖。
