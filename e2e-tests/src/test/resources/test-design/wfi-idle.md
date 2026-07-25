# WFI 空闲路径 — 测试设计文档

> 功能: 主循环空闲路径 (非 tick_handler，主循环 `while(1)` 中)
> 被测路径: `board/main.c:376-385`
> 前置: `power_save_enabled=true`

## 1. 被测功能流程图

```
主循环 while(1)
    │
    ├── TICK_TIMER->SR != 0?
    │     → tick_handler()  [8Hz, 1Hz]
    │
    └── SR == 0 (空闲)
          │
          ├── CUATRO && SOM GPIO 低?
          │     → enter_stop_mode()  [深休眠, CAN/SBU 唤醒]
          │
          └── 其他情况 (tres/red, 或 CUATRO + SOM GPIO 高)
                → __WFI()           [轻休眠]
                → SCB->SCR &= ~SLEEPDEEP  [清除深休眠标志]
```

## 2. 板级差异

| 板卡 | SOM GPIO | 休眠类型 | 场景 |
|------|----------|---------|------|
| cuatro | 低 | `enter_stop_mode()` 深休眠 | `deep_sleep.feature` 已覆盖 |
| cuatro | 高 | `__WFI()` 轻休眠 | TC3 |
| tres | — | `__WFI()` 轻休眠 | TC1 |
| red | — | `__WFI()` 轻休眠 | TC2 |

## 3. 输入因子

| 因子 | 类型 | 等价类 | 说明 |
|------|------|--------|------|
| 板卡 | enum | cuatro, tres, red | 通过 `@cuatro/@tres/@red` 标签选择 |
| power_save_enabled | bool | true (前置) | 通过 `SetPowerSaveState` 设置 |
| somGpio | int | 0, 1 | 仅 cuatro 板有效 |

## 4. 输出因子

| 输出 | 类型 | 说明 |
|------|------|------|
| `stopModeRegs.wfiEntered` | bool | `__WFI()` 是否被调用 |
| `stopModeRegs.scbScr` | long | SCB SCR 寄存器（SLEEPDEEP 清除后为 0） |
| `powerSaveEnabled` | bool | 省电模式状态 |

## 5. 测试用例

### TC1: tres 板进入 WFI 轻休眠
- 前置: power_save_enabled=true
- 板卡: @tres
- 执行: `process wfi idle`
- 预期: wfiEntered=true, scbScr=0, powerSaveEnabled=true
- 场景: `wfi_idle.feature:17`

### TC2: red 板进入 WFI 轻休眠
- 前置: power_save_enabled=true
- 板卡: @red
- 执行: `process wfi idle`
- 预期: wfiEntered=true, scbScr=0, powerSaveEnabled=true
- 场景: `wfi_idle.feature:31`

### TC3: cuatro 板 SOM GPIO 高时进入 WFI 轻休眠
- 前置: power_save_enabled=true, somGpio=1
- 板卡: @cuatro
- 执行: `process wfi idle`
- 预期: wfiEntered=true, scbScr=0, powerSaveEnabled=true
- 场景: `wfi_idle.feature:45`

## 6. 覆盖检查

| 条件 | TC1 | TC2 | TC3 |
|------|-----|-----|-----|
| `power_save_enabled` → 进入空闲路径 | ✅ | ✅ | ✅ |
| `!TICK_TIMER->SR` (空闲) | ✅ | ✅ | ✅ |
| CUATRO + SOM GPIO 低 → `enter_stop_mode` | — | — | — |
| 非 CUATRO → `__WFI()` | ✅ | ✅ | — |
| CUATRO + SOM GPIO 高 → `__WFI()` | — | — | ✅ |
| `SCB->SCR &= ~SLEEPDEEP` | ✅ | ✅ | ✅ |

> ⚠️ CUATRO + SOM GPIO 低 → `enter_stop_mode()` 路径由 `deep_sleep.feature` 覆盖，不在本 feature 范围。

✅ WFI 轻休眠路径覆盖所有板卡组合。

## 覆盖率

> 数据来源: `run_all_coverage.sh` 合并报告

| 被测行 | 源文件 | 说明 |
|--------|--------|------|
| `main.c:377-378` | CUATRO + SOM GPIO 低 → enter_stop_mode | `deep_sleep.feature` 覆盖 |
| `main.c:383` | `__WFI()` 调用 | TC1-3 覆盖 |
| `main.c:384` | `SCB->SCR &= ~SLEEPDEEP` | TC1-3 覆盖 |
