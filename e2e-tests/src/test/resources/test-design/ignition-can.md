# ignition_can 自动复位 — 测试设计文档

> 功能: `ignition_can_cnt` / `ignition_can` in `board/main.c:250-258`
> 被测路径: 1Hz tick → `ignition_can_cnt` 递增 → `ignition_can` 自动清零
> 数据定义: `opendbc/safety/ignition.h` (`ignition_can_hook()` 设置 `ignition_can=true`, `cnt=0`)

## 1. 被测功能数据流

```
CAN 消息到达 (fdcan.h)
     │
     ▼ ignition_can_hook(&msg)  [opendbc/safety/ignition.h]
ignition_can = true
ignition_can_cnt = 0
     │
     ▼ 无更多 CAN 点火消息
1Hz tick (每 8 次 jna_call_tick_handler)
     │
     ├── cnt=0: 0>2? ✗ → cnt=1
     ├── cnt=1: 1>2? ✗ → cnt=2
     ├── cnt=2: 2>2? ✗ → cnt=3
     └── cnt=3: 3>2? ✓ → ignition_can = false
```

## 2. 关键变量

| 变量 | 类型 | 作用域 | 读路径 | 写路径 |
|------|------|--------|--------|--------|
| `ignition_can` | `bool` | opendbc extern | `main_comms.h:16` → health packet `ignition_can_pkt`; `main.c:175` → bootkick `started` | `ignition.h` (`ignition_can_hook`: → true); `main.c:252` (→ false) |
| `ignition_can_cnt` | `uint32_t` | opendbc extern | `main.c:251` (比较) | `ignition.h` (→ 0); `main.c:258` (++ 每 1Hz) |

## 3. 输入因子

| 因子 | 类型 | 等价类 | 说明 |
|------|------|--------|------|
| `ignition_can` 初始值 | bool | false (默认), true (CAN 点火后) | 通过 `jna_set_ignition_can()` 注入 |
| tick 次数 | int | < 4 次 1Hz, ≥ 4 次 1Hz | 通过 `jna_call_tick_handler` N 次触发 |

## 4. 输出因子

| 输出 | 类型 | 说明 |
|------|------|------|
| `ignitionCan` | int (0/1) | 通过 `jna_get_ignition_can()` 读取 `ignition_can` 全局变量 |

## 5. 测试用例

### TC1: CAN 流量停止 4 秒后 ignition_can 自动复位
- 前置: `jna_set_ignition_can(true)` → `ignition_can=true`, `cnt=0`
- 执行: `jna_call_tick_handler` × 32 (4 次 1Hz tick)
- 预期: `ignition_can = false`
- 路径: cnt=0→1→2→3 → 3>2 → ignition_can=false
- 场景: `ignition_can.feature:19`

### TC2: CAN 流量停止 3 秒内 ignition_can 保持为 true
- 前置: `jna_set_ignition_can(true)` → `ignition_can=true`, `cnt=0`
- 执行: `jna_call_tick_handler` × 24 (3 次 1Hz tick)
- 预期: `ignition_can = true`
- 路径: cnt=0→1→2 → 2>2? ✗ → 不进入复位分支
- 场景: `ignition_can.feature:28`

## 6. 覆盖检查

| 条件 | TC1 | TC2 |
|------|-----|-----|
| `ignition_can_cnt > 2` — false (0, 1, 2) | ✅ | ✅ |
| `ignition_can_cnt > 2` — true (3) | ✅ | — |
| `ignition_can = false` 执行 | ✅ | — |
| `ignition_can_cnt += 1U` | ✅ | ✅ |
| `jna_set_ignition_can` (ignition_can=true, cnt=0) | ✅ | ✅ |
| `jna_get_ignition_can` | ✅ | ✅ |

✅ 所有分支和边界条件已覆盖。

## 覆盖率

> 数据来源: `run_all_coverage.sh` 合并报告 (cuatro + tres + red)

| 被测行 | 源文件 | 说明 |
|--------|--------|------|
| `main.c:251` | `if (ignition_can_cnt > 2U)` | 两个分支均覆盖 |
| `main.c:252` | `ignition_can = false` | TC1 覆盖 |
| `main.c:258` | `ignition_can_cnt += 1U` | 每个 1Hz tick 执行 |
