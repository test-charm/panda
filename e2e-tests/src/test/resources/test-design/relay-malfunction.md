# 继电器故障检测 — 测试设计文档

> 功能: `relay_malfunction` 边沿检测 in `board/main.c:134-141`
> 被测路径: 8Hz tick_handler → 边沿检测 → FAULT_RELAY_MALFUNCTION
> 调用: `main.c:134-141` (8Hz tick handler)

## 1. 被测功能流程图

```
tick_handler() [8Hz]
        │
        ▼
  relay_malfunction 值变化?
   ┌───Y───┐
   │       │
   N       ▼
   │   fault_occurred(FAULT_RELAY_MALFUNCTION)
   │   relay_malfunction_fault = true
   │       │
   │       ▼
   │   fault_status |= FAULT_RELAY_MALFUNCTION
   │
   ▼
  relay_malfunction == 0 && relay_malfunction_fault?
   ┌───Y───┐
   │       │
   N       ▼
   │   fault_recovered(FAULT_RELAY_MALFUNCTION)
   │   relay_malfunction_fault = false
   │       │
   │       ▼
   │   fault_status &= ~FAULT_RELAY_MALFUNCTION
   │
   ▼
  (无变化: 不操作)
```

## 2. 输入因子

| 因子 | 类型 | 等价类 | 取值 |
|------|------|--------|------|
| `relayMalfunctionVal` | int | 0 (正常), 1 (故障), 0→1 (上升沿), 1→0 (下降沿) | 0, 1 |
| `relay_malfunction_fault` | boolean | false (初始), true (已触发后) | false, true |

## 3. 输出因子

| 输出 | 类型 | 说明 |
|------|------|------|
| readFaults | int | fault_status 位掩码, bit 0 = FAULT_RELAY_MALFUNCTION |

## 4. 测试用例

### TC1: 设置继电器故障 → 触发 FAULT_RELAY_MALFUNCTION
- 前置: relayMalfunctionVal=1 (上升沿)
- 输入: tick_handler
- 输出: readFaults=1 (bit 0 set)
- 路径: 上升沿 → fault_occurred → fault_status bit 0=1

### TC2: 清除继电器故障 → 故障恢复
- 前置: TC1 (fault asserted), relayMalfunctionVal=0 (下降沿)
- 输入: tick_handler × 2
- 输出: readFaults=0
- 路径: 下降沿 + relay_malfunction_fault=true → fault_recovered → fault_status bit 0=0

### TC3: 无变化不影响故障状态
- 前置: relayMalfunctionVal=0, relay_malfunction_fault=false
- 输入: tick_handler
- 输出: readFaults=0
- 路径: 无边缘变化 → 跳过

## 5. 覆盖检查

| 条件 | TC1 | TC2 | TC3 |
|------|-----|-----|-----|
| relay_malfunction 上升沿 | ✅ | — | — |
| fault_occurred 设置 | ✅ | — | — |
| relay_malfunction 下降沿 + 已触发 | — | ✅ | — |
| fault_recovered 恢复 | — | ✅ | — |
| 无变化跳过 | — | — | ✅ |
| 所有边沿检测组合 | ✅ | ✅ | ✅ |

✅ 所有边沿检测路径、故障断言和恢复已覆盖。

## 覆盖率

> 数据来源: `run_all_coverage.sh` 合并报告 (cuatro + tres + red)
> 综合行覆盖率: **65.1%** (全量), 本功能涉及以下源文件:

| 源文件 | 行覆盖 | 说明 |
|--------|--------|------|
| `main.c` | 46.9% (106/226) | 主循环 tick 路径 + relay_malfunction 检测 |
| `faults.h` | 78.9% (15/19) | fault_occurred / fault_recovered |
