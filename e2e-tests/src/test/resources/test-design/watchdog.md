# 心跳循环看门狗 — 测试设计文档

> 功能: `simple_watchdog_kick()` in `board/drivers/simple_watchdog.h`
> 被测路径: 8Hz tick → `simple_watchdog_kick()` → `FAULT_HEARTBEAT_LOOP_WATCHDOG`
> 调用: `main.c:131` (tick_handler 8Hz 路径，每次调用都执行)

## 1. 被测功能数据流

```
8Hz tick_handler → simple_watchdog_kick()
    │
    │  ts = microsecond_timer_get()
    │  et = get_ts_elapsed(ts, wd_state.last_ts)
    │
    ├── et ≤ threshold (375ms)
    │     → 仅更新 last_ts = ts
    │
    └── et > threshold
          → fault_occurred(FAULT_HEARTBEAT_LOOP_WATCHDOG)
          → 更新 last_ts = ts
```

## 2. 关键常量

| 常量 | 值 | 含义 |
|------|----|------|
| `threshold` | `3*1000000/8 = 375000` μs | 看门狗超时门限 |
| `FAULT_HEARTBEAT_LOOP_WATCHDOG` | 1<<26 = 67108864 | 看门狗故障位 |

初始化: `simple_watchdog_init(FAULT_HEARTBEAT_LOOP_WATCHDOG, 375000)` at `main.c:318`

## 3. 输入因子

| 因子 | 类型 | 等价类 | 说明 |
|------|------|--------|------|
| timerValue | int (μs) | < 375000, ≥ 375000 | 两次 tick 之间的微秒间隔，通过 `jna_set_microsecond_timer` 预设 |

## 4. 输出因子

| 输出 | 类型 | 说明 |
|------|------|------|
| `readFaults` | int | 故障寄存器，bit 26 = `FAULT_HEARTBEAT_LOOP_WATCHDOG` (67108864) |

## 5. 测试用例

### TC1: 正常 tick 速率不触发看门狗
- 执行: tick handler → timerValue=200000 → tick handler
- 预期: readFaults=0 (et=200000 < 375000)
- 路径: et ≤ threshold → 不触发故障
- 场景: `watchdog.feature:12`

### TC2: 缓慢 tick 速率触发看门狗故障
- 执行: tick handler → timerValue=400000 → tick handler
- 预期: readFaults=67108864 (et=400000 > 375000)
- 路径: et > threshold → fault_occurred(bit 26)
- 场景: `watchdog.feature:28`

### TC3: 看门狗故障触发后即使速率恢复也保持
- 执行: tick handler → timerValue=400000 → tick handler → timerValue=500000 → tick handler
- 预期: readFaults=67108864 (故障位 latch 不恢复)
- 路径: `fault_occurred` 是置位操作，不自动清除
- 场景: `watchdog.feature:44`

## 6. 覆盖检查

| 条件 | TC1 | TC2 | TC3 |
|------|-----|-----|-----|
| `et ≤ threshold` (正常路径) | ✅ | — | — |
| `et > threshold` (超时路径) | — | ✅ | ✅ |
| `fault_occurred` 调用 | — | ✅ | ✅ |
| 故障置位后保持 | — | — | ✅ |
| `wd_state.last_ts` 更新 | ✅ | ✅ | ✅ |

✅ 所有分支条件和故障 latch 行为已覆盖。

## 覆盖率

> 数据来源: `run_all_coverage.sh` 合并报告

| 被测行 | 源文件 | 说明 |
|--------|--------|------|
| `simple_watchdog.h:5-15` | `simple_watchdog_kick()` 完整函数 | 行 + 分支 100% 覆盖 |
| `simple_watchdog.h:17-21` | `simple_watchdog_init()` | `main.c:318` 初始化调用覆盖 |
