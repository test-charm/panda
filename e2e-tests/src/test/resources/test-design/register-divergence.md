# 寄存器发散检测 — 测试设计文档

> 功能: `check_registers()` in `board/drivers/registers.h`
> 被测路径: 1Hz tick → `check_registers()` → `FAULT_REGISTER_DIVERGENT`
> 调用: `main.c:248` (tick_handler 1Hz 路径)

## 1. 被测功能数据流

```
register_set(addr, val, mask)
    │  将 (val & mask) 存入 register_map[hash].value
    │  将 mask 存入 register_map[hash].check_mask
    ▼
1Hz tick → check_registers()
    │  遍历 register_map[]
    │  对每个非空条目:
    │    actual = *(addr) & check_mask
    │    expected = value & check_mask
    │    actual ≠ expected?
    │      └── logged_fault? → fault_occurred(FAULT_REGISTER_DIVERGENT)
    ▼
faults 寄存器     ← FAULT_REGISTER_DIVERGENT (bit 18 = 0x40000 = 262144)
```

## 2. 关键常量

| 常量 | 值 | 含义 |
|------|----|------|
| `REGISTER_MAP_SIZE` | 0x3FF (1023) | 哈希表槽位数 |
| `HASHING_PRIME` | 23 | 哈希乘数 |
| `FAULT_REGISTER_DIVERGENT` | 1<<18 = 262144 | 寄存器发散故障位 |

## 3. e2e 注入机制

e2e 中 `register_set` 存根绕过 shadow map，无法通过正常路径触发发散。测试通过 `jna_set_register_divergent()` 直接向 `register_map[0]` 注入发散状态：
- **注入 ON**: `register_map[0].address = &e2e_GPIOA.MODER`, `.value ≠ actual`
- **注入 OFF**: 清除 `register_map[0]`（恢复正常）

`init_registers()` 在 `jna_panda_init()` 末尾调用，清除初始化期间写入的 register_map 条目（消除噪音）。

## 4. 输入因子

| 因子 | 类型 | 等价类 | 说明 |
|------|------|--------|------|
| registerDivergent | int | 0 (正常), 1 (注入发散) | 通过 `jna_set_register_divergent()` 设置 |
| tick 次数 | int | ≥ 8 (至少 1 次 1Hz) | 触发 `check_registers()` |

## 5. 输出因子

| 输出 | 类型 | 说明 |
|------|------|------|
| `readFaults` | int | 故障寄存器，bit 18 = `FAULT_REGISTER_DIVERGENT` (262144) |

## 6. 测试用例

### TC1: 寄存器未发散时不触发故障
- 前置: registerDivergent=0
- 执行: tick handler × 8 (1 次 1Hz)
- 预期: readFaults=0
- 路径: register_map 正常 → check_registers 无发散
- 场景: `register_divergence.feature:12`

### TC2: 寄存器发散触发 FAULT_REGISTER_DIVERGENT
- 前置: registerDivergent=1
- 执行: tick handler × 8 (1 次 1Hz)
- 预期: readFaults=262144
- 路径: register_map[0] 注入发散 → fault_occurred(bit 18)
- 场景: `register_divergence.feature:27`

### TC3: 寄存器发散故障在修复后保持（logged_fault 防抖）
- 前置: registerDivergent=1 → 触发故障 → registerDivergent=0 → 再 tick
- 执行: tick handler × 8 → 重置 setup → tick handler × 8
- 预期: readFaults=262144（仍为 1）
- 路径: `logged_fault=true` → 即使值恢复也不清除故障位
- 场景: `register_divergence.feature:42`

## 7. 覆盖检查

| 条件 | TC1 | TC2 | TC3 |
|------|-----|-----|-----|
| register_map[i].address == 0 (空槽跳过) | ✅ | — | — |
| register_map[i].address != 0 (进入检查) | — | ✅ | ✅ |
| *(addr) & mask == value & mask (匹配) | ✅ | — | — |
| *(addr) & mask != value & mask (发散) | — | ✅ | ✅ |
| !logged_fault → 打印 + 标记 | — | ✅ | ✅ |
| logged_fault → 仅调用 fault_occurred | — | — | ✅ |
| fault_occurred(FAULT_REGISTER_DIVERGENT) | — | ✅ | ✅ |

✅ 所有分支条件和 logged_fault 防抖逻辑已覆盖。

## 覆盖率

> 数据来源: `run_all_coverage.sh` 合并报告

| 被测行 | 源文件 | 说明 |
|--------|--------|------|
| `registers.h:56-69` | `check_registers()` 完整函数 | 行 + 分支 100% 覆盖 |
