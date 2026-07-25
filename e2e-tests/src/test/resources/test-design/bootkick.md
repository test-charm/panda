# Bootkick SOM 复位状态机 — 测试设计文档

> 功能: `bootkick_tick()` in `board/drivers/bootkick.h`
> 被测路径: 1Hz tick → `bootkick_tick()` → GPIO 控制
> 调用: `main.c:176` (tick_handler 1Hz 路径)

## 1. 被测功能流程图

```
bootkick_tick()  [1Hz]
        │
   ┌────┴──────────── No ignition, recent heartbeat
   │  → BOOT_STANDBY (state=0)
   │  → bootkick GPIO high
   │
   ├──── Ignition rising edge | harness inserted
   │  → BOOT_BOOTKICK (state=1)
   │  → waiting_countdown = 20
   │  → bootkick GPIO low
   │     │
   │     ├── Serial activity (somUartWptr changed)
   │     │   → abort: waiting_countdown = 0, stay BOOT_BOOTKICK
   │     │
   │     └── 20 ticks elapsed without serial activity
   │         → BOOT_RESET (state=2)
   │         → reset_countdown = 5
   │         → bootkick_reset_triggered = true
   │         → bootkick GPIO high (BOOT_STANDBY level)
   │            │
   │            └── 5 more ticks
   │                → back to BOOT_BOOTKICK (state=1)
   │                → waiting_countdown = 20
   │
   └──── bootkick_reset_triggered == true
        → skip, stay in current state
```

## 2. 状态枚举

| 状态 | 值 | GPIO 行为 (cuatro) | GPIO 行为 (tres) |
|------|---|-------------------|------------------|
| BOOT_STANDBY | 0 | PA0=1, PC11=1 | PA0=1, PC12=1 |
| BOOT_BOOTKICK | 1 | PA0=0, PC11=0 | PA0=0, PC12=1 |
| BOOT_RESET | 2 | PA0=1, PC11=1 | PA0=1, PC12=0 |

## 3. 输入因子

| 因子 | 类型 | 等价类 | 说明 |
|------|------|--------|------|
| ignitionLine | boolean | 0→1 (rising edge), 0→0 (stayed low) | 点火线状态 |
| harnessStatus | int | 0, ≥1 | 线束插入检测 |
| somUartWptr | int | 变化 vs 不变 | 串口活动检测 |
| heartbeat_counter | int | 0 (recent), ≥1 | 近期心跳 |
| bootkick_reset_triggered | boolean | false, true | 重置已触发 |

## 4. 输出因子

| 输出 | 类型 | 说明 |
|------|------|------|
| bootkick.state | int | 当前 FSM 状态 (0/1/2) |
| bootkick.waitingCountdown | int | 20→0 等待倒计时 |
| bootkick.resetCountdown | int | 5→0 复位倒计时 |
| bootkick.resetTriggered | bool | 是否已触发 SOM 复位 |
| stopModeRegs.gpioAOdr (PA0) | long | bootkick GPIO PA0 |
| stopModeRegs.gpioCOdr (PC11/PC12) | long | bootkick GPIO PC11(quatro)/PC12(tres) |

## 5. 测试用例

### TC1: 点火上升沿触发 BOOT_BOOTKICK
- 输入: ignitionLine=0→1, heartbeat_counter=0
- 输出: state=1, waitingCountdown=20, resetTriggered=0
- 路径: 上升沿检测 → BOOT_BOOTKICK

### TC2: 近期心跳转 BOOT_STANDBY
- 输入: ignitionLine=0, heartbeat_counter=0
- 输出: state=0, resetTriggered=0
- 路径: 非上升沿 + 近期心跳 → STANDBY

### TC3: STANDBY→BOOTKICK 边缘启动 20 tick 等待倒计时
- 前置: TC2 (STANDBY), 再设置 ignitionLine=1
- 输出: state=1, waitingCountdown=19
- 路径: STANDBY→BOOTKICK 边缘检测

### TC4: 完整倒计时 22 ticks 后触发 BOOT_RESET
- 前置: TC2 + 21 more ticks
- 输出: state=2, resetTriggered=1, resetCountdown=3
- 路径: waitingCountdown→0 → BOOT_RESET

### TC5: BOOT_RESET 5 ticks 后回到 BOOT_BOOTKICK
- 前置: 25 ticks from initial
- 输出: state=1, resetTriggered=1, resetCountdown=0

### TC6: 串口活动中止等待倒计时
- 输入: ignitionLine=1, somUartWptr 变化
- 输出: state=1, waitingCountdown=0
- 路径: 串口活动 → 中止

### TC7: reset_triggered 阻止第二次复位周期
- 前置: 触发过 BOOT_RESET, toggle ignition 创建 STANDBY→BOOTKICK 边缘
- 输出: state=1, resetTriggered=1, waitingCountdown=0
- 路径: resetTriggered==true → 跳过

### TC8: 线束插入触发 BOOT_BOOTKICK
- 输入: harnessStatus=1, ignitionLine=0
- 输出: state=1
- 路径: harness_inserted 边缘检测

### TC9-TC14: 板特定 GPIO 断言 (cuatro/tres 各 3 场景)
- 验证: stopModeRegs.gpioAOdr/gpioCOdr
- 覆盖: BOOT_BOOTKICK/STANDBY/RESET 三种状态下的 GPIO 电平

## 6. 覆盖检查

| 条件 | TC1 | TC2 | TC3 | TC4 | TC5 | TC6 | TC7 | TC8 |
|------|-----|-----|-----|-----|-----|-----|-----|-----|
| Ignition rising edge | ✅ | — | ✅ | — | — | — | — | — |
| Recent heartbeat → STANDBY | — | ✅ | — | — | — | — | — | — |
| STANDBY→BOOTKICK edge | — | — | ✅ | — | — | — | — | — |
| 20-tick countdown | — | — | ✅ | ✅ | — | — | — | — |
| BOOT_RESET trigger | — | — | — | ✅ | — | — | — | — |
| 5-tick reset expire | — | — | — | — | ✅ | — | — | — |
| Serial activity abort | — | — | — | — | — | ✅ | — | — |
| reset_triggered guard | — | — | — | — | — | — | ✅ | — |
| Harness insertion | — | — | — | — | — | — | — | ✅ |
| GPIO 断言 (6 per board) | TC9-TC14 |

✅ 所有 FSM 状态转换、中止路径、护栏条件和 GPIO 输出已覆盖。

## 覆盖率

> 数据来源: `run_all_coverage.sh` 合并报告 (cuatro + tres + red)
> 综合行覆盖率: **65.1%** (全量), 本功能涉及以下源文件:

| 源文件 | 行覆盖 | 说明 |
|--------|--------|------|
| `main.c` | 46.9% (106/226) | 主循环 tick 路径 |
| `gpio.h` | 69.1% (47/68) | GPIO 控制 |

> ⚠️ 本功能代码位于 `board/drivers/bootkick.h`，e2e 通过 `bootkick_e2e.gen.c` 桩调用，桩文件不纳入覆盖率统计。
