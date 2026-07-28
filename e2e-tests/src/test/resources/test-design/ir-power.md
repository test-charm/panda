# IR 功率设置 — 测试设计文档

> 功能: `current_board->set_ir_power()` via `comms_control_handler()` in `board/main_comms.h`
> 被测接口: USB control request 0xb0 (set IR power)

## 1. 被测功能流程图

```
set IR power (0xb0):
  [controlWrite(0xb0, param1)]
           │
           ▼
  current_board->set_ir_power(param1)
           │
     ┌─────┴──────────────────┐
     │ board 类型                │
     ├──────────────────────────┤
     │ cuatro/tres               │  red
     │ ↓                         │  ↓
     │ set_ir_power(生产函数)      │  unused_set_ir_power
     │   → pwm_set(TIM3,4,pct)   │    → UNUSED(pct) (no-op)
     │   → TIM1.CCR1 = pct       │    → irPwm stays 0
     └──────────────────────────┘
```

> **输出因子**: `irPwm` — `fake_TIM1.CCR1` 寄存器值（JNA 直接读取）

## 2. 输入因子

| 因子 | 类型 | 等价类 | 取值 |
|------|------|--------|------|
| `request` | uint8 | 0xb0 (唯一) | 0xb0 |
| `param1` | uint16 | 0 (关闭), 非0 (功率值) | 0, 50, 255 |

## 3. 输出因子

| 输出 | 类型 | 说明 |
|------|------|------|
| irPwm | int | fake_TIM1.CCR1 寄存器值（board_set_ir_power_stub 写入） |
| |||
| cu/tres 设非零 → CCR1 = param1 |
| cu/tres 设零 → CCR1 = 0 |
| red 设任意值 → CCR1 = 0（unused_set_ir_power 不操作寄存器） |

## 4. 测试用例

### TC1: 设置 IR 功率为 0
- 输入: param1=0
- 输出: irPwm: 0

### TC2: 设置 IR 功率为非零值
- 输入: param1=50
- 输出: irPwm: 50

### TC3: 设置 IR 功率为最大值
- 输入: param1=255
- 输出: irPwm: 255

### TC4 (@red): unused_set_ir_power 无 PWM 副作用
- 前置: red board (`.set_ir_power = unused_set_ir_power`)
- 输入: param1=50
- 输出: irPwm: 0
- 说明: `unused_set_ir_power` 不操作 TIM1.CCR1，与 TC2 (irPwm:50) 形成对比验证

## 5. 覆盖检查

| 条件 | TC1 | TC2 | TC3 | TC4 (@red) |
|------|-----|-----|-----|------------|
| param1 == 0 (PWM off) | ✅ | — | — | — |
| param1 > 0, 有 IR 硬件 | — | ✅ | ✅ | — |
| param1 > 0, 无 IR 硬件 (unused) | — | — | — | ✅ |

✅ 所有等价类 + `unused_set_ir_power` 空桩路径已覆盖。

## 覆盖率

> 数据来源: `run_all_coverage.sh` 合并报告 (cuatro + tres + red)
> 综合行覆盖率: **78.9%** (全量), 本功能涉及以下源文件:

| 源文件 | 行覆盖 | 说明 |
|--------|--------|------|
| `main_comms.h` | 95.5% (257/269) | USB 命令处理 |
| `unused_funcs.h` | 100% (23/23) | ✅ Phase D.2 |

