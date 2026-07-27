# 永久故障处理 — 测试设计文档

> 功能: `fault_occurred()` / `fault_recovered()` in `board/sys/faults.h`
> 被测路径: `fault_occurred(PERMANENT_FAULTS)` → `fault_status = PERMANENT` → `fault_recovered()` 拒绝恢复
> 调用: 直接 JNA 调用（通过 `jna_trigger_fault` / `jna_recover_fault`）

## 1. 被测功能流程图

```
fault_occurred(fault)
        │
        ▼
  faults 已含该位?  ───Y──→ 跳过 (幂等)
        │
        N
        ▼
  (PERMANENT_FAULTS & fault)?
   ┌───Y───┐              ┌───N───┐
   │       │              │       │
   ▼       │              ▼       │
  print    │             print     │
  "Permanent│            "Temporary│
   fault"  │              fault"  │
   ▼       │              ▼       │
  fault_   │             fault_   │
  status = │             status = │
  PERMANENT│             TEMPORARY│
   │       │              │       │
   └───┬───┘              └───┬───┘
       ▼                      ▼
  faults |= fault ←───────────┘


fault_recovered(fault)
        │
        ▼
  (PERMANENT_FAULTS & fault) == 0?
   ┌───Y───┐              ┌───N───┐
   │       │              │       │
   ▼       │              ▼       │
  faults   │             print     │
  &= ~fault│             "Cannot   │
  (临时故障│             recover" │
  可恢复)  │             (永久故障│
           │             不可恢复)│
           │              faults   │
           │              不变     │
   └───┬───┘              └───┬───┘
       └────────── 结束 ←──────┘
```

## 2. e2e 测试机制

生产代码中 `PERMANENT_FAULTS` 定义为 `0U`（无故障为永久），所有现有故障均为临时故障。
e2e 构建通过 `#ifdef E2E_TEST` 块覆盖该定义：

```c
#ifdef E2E_TEST
#undef PERMANENT_FAULTS
#define PERMANENT_FAULTS FAULT_UNUSED_INTERRUPT_HANDLED
#endif
```

`FAULT_UNUSED_INTERRUPT_HANDLED` (bit 1 = 2) 在 e2e tick 路径中从未被触发，因此可安全用于永久故障测试。

测试通过 JNA 直接调用 `jna_trigger_fault()` / `jna_recover_fault()` 注入故障，
不依赖 tick handler 路径。

## 3. 关键常量

| 常量 | 值 | 含义 |
|------|----|------|
| `FAULT_STATUS_NONE` | 0 | 无故障 |
| `FAULT_STATUS_TEMPORARY` | 1 | 临时故障 |
| `FAULT_STATUS_PERMANENT` | 2 | 永久故障 |
| `FAULT_UNUSED_INTERRUPT_HANDLED` | 1<<1 = 2 | e2e 中作为 PERMANENT_FAULTS 替代 |

## 4. 输入因子

| 因子 | 类型 | 等价类 | 说明 |
|------|------|--------|------|
| fault 参数 | uint32_t | 2 (FAULT_UNUSED_INTERRUPT_HANDLED) | 固定值，e2e 中永久故障位 |
| faults 当前值 | uint32_t | 0 (初始), 2 (已触发) | 幂等 vs 首次触发 |
| 操作类型 | enum | trigger, recover | fault_occurred vs fault_recovered |

## 5. 输出因子

| 输出 | 类型 | 说明 |
|------|------|------|
| `faultStatus` | int | 0=NONE, 1=TEMPORARY, 2=PERMANENT |
| `readFaults` | int | faults 位掩码寄存器 |

## 6. 测试用例

### TC1: 永久故障不可恢复
- 前置: faults=0, fault_status=0
- 步骤1: `trigger fault 2` (FAULT_UNUSED_INTERRUPT_HANDLED)
- 验证: faultStatus=2 (PERMANENT), readFaults=2
- 步骤2: `recover fault 2`
- 验证: readFaults=2 (不清除，仍为 2)
- 路径: `fault_occurred` → 永久分支 → 设置 PERMANENT → `fault_recovered` → 拒绝恢复
- 场景: `permanent_fault.feature:17`

### TC2: 触发同一永久故障幂等
- 前置: faults=0, fault_status=0
- 步骤: `trigger fault 2` → `trigger fault 2` (重复)
- 验证: faultStatus=2, readFaults=2 (不会加倍为 4)
- 路径: `faults` 已含该位 → 跳过设置 → `faults` 保持不变
- 场景: `permanent_fault.feature:34`

## 7. 覆盖检查

| 被测行 | 代码 | TC1 | TC2 |
|--------|------|-----|-----|
| faults.h:14 | `if ((faults & fault) == 0U)` — 首次触发 (true) | ✅ | ✅ |
| faults.h:14 | `if ((faults & fault) == 0U)` — 重复触发 (false) | — | ✅ |
| faults.h:15 | `if ((PERMANENT_FAULTS & fault) != 0U)` — true 分支 | ✅ | ✅ |
| faults.h:16 | `fault_status = FAULT_STATUS_PERMANENT` | ✅ | ✅ |
| faults.h:20 | `faults \|= fault` (always 执行) | ✅ | ✅ |
| faults.h:23 | `if ((PERMANENT_FAULTS & fault) == 0U)` — false 分支 | ✅ | — |
| faults.h:24 | `faults &= ~fault` (临时故障恢复, 不执行) | — | — |
| faults.h:25 | `print("Cannot recover")` | ✅ | — |

## 8. 与其他测试的关系

其他故障测试（`relay_malfunction`, `register_divergence`, `watchdog`）覆盖 `faults.h` 的临时故障路径（`fault_status = FAULT_STATUS_TEMPORARY` + `fault_recovered` 清除）。
本测试补充覆盖永久故障路径（`fault_status = FAULT_STATUS_PERMANENT` + `fault_recovered` 拒绝）。

| 路径 | relay_malfuction | register_divergence | watchdog | permanent_fault |
|------|:--:|:--:|:--:|:--:|
| fault_occurred → TEMPORARY | ✅ | ✅ | ✅ | — |
| fault_occurred → PERMANENT | — | — | — | ✅ |
| fault_recovered → 清除 | ✅ | — | — | — |
| fault_recovered → 拒绝 | — | — | — | ✅ |
| 重复触发幂等 | — | — | — | ✅ |

## 覆盖率

> 数据来源: `run_all_coverage.sh` 合并报告 (cuatro + tres + red)

| 源文件 | 行覆盖 | 说明 |
|--------|--------|------|
| `faults.h` | **100%** (33/33) | fault_occurred / fault_recovered 全路径 |
