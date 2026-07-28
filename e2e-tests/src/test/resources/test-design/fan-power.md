# 风扇功率控制 — 测试设计文档

> 功能: `fan_set_power()` + `fan_tick()` → `current_board->set_fan_enabled()` in `board/main_comms.h`
> 被测接口: USB control request 0xb1 (set fan power) + tick_handler 触发 fan_tick
> 实现来源: 真实 `board/drivers/fan.h` + 真实 `board/boards/*.h` (`set_fan_enabled`)
> Phase D.2: 三块板子均使用生产 `set_fan_enabled`，`board_set_fan_enabled_stub` 已删除

## 1. 被测功能流程图

```
[controlWrite(0xb1, param1)]          [tick_handler() @8Hz]
         │                                     │
         ▼                                     ▼
   fan_set_power(param1)                  fan_tick()
         │                                     │
    ┌────┴───────────┐                   if has_fan:
    │ percentage > 0? │               ┌───┤ fan_state.cooldown
    └────┬───────────┘               │   │ (递减/重置)
     N   │   Y                       │   │
    ┌────┴──────┐                    │   │
  power=0   power=CLAMP(%,20,100)     │   └→ current_board->
         │                            │      set_fan_enabled(
         └────────────┬───────────────┘      power>0 || cooldown>0)
                      ▼
               fan_state.power 更新
                      │
                      ▼
    ╔══════════════════════════════════════╗
    ║  set_fan_enabled 板级差异              ║
    ╠══════════════════════════════════════╣
    ║ cuatro → cuatro_set_fan_enabled     ║
    ║   set_gpio_output(GPIOD,3,!en)      ║
    ║   active-low: 开→PD3=0, 关→PD3=1    ║
    ╠══════════════════════════════════════╣
    ║ tres   → tres_set_fan_enabled       ║
    ║   tres_fan_enabled=en;              ║
    ║   tres_update_fan_ir_power()        ║
    ║   set_gpio_output(GPIOD,3,IR||fan)  ║
    ╠══════════════════════════════════════╣
    ║ red    → unused_set_fan_enabled     ║
    ║   UNUSED(en) — no-op               ║
    ╚══════════════════════════════════════╝
```

> `fan_set_power` 只设 `fan_state.power`。`set_fan_enabled` 由 `fan_tick()` 触发（需 `call tick handler` 后才生效）

## 2. 输入因子

| 因子 | 类型 | 等价类 | 取值 |
|------|------|--------|------|
| `request` | uint8 | 0xb1 (唯一) | 0xb1 |
| `param1` (percentage) | uint16 | ==0, 1-19 (clamp→20), 20-100 (pass), >100 (clamp→100) | 0, 5, 50, 200, 255 |
| board | enum | cuatro (GPIO active-low), tres (GPIO 组合输出), red (no-op) | cuatro, tres, red |

## 3. 输出因子

| 输出 | 类型 | 说明 |
|------|------|------|
| fanPower | int | `fan_state.power` 值 |
| stopModeRegs.gpioDOdr | long | GPIOD ODR 寄存器（fan on PD3, CAN on PD7/PD8） |
| |||
| cuatro 开风扇 → PD3=0 (0L, active-low) |
| cuatro 关+cooldown 结束 → PD3=1 (8L) + PD8(CAN3)=256 → 264L |
| tres 开风扇 → PD3=1 (8L) |
| red 开风扇 → PD3=0 (unused_set_fan_enabled 不操作 GPIO) |

## 4. 测试用例

### TC1: 关闭风扇 (param1=0)
- 输入: param1=0
- 输出: fanPower: 0

### TC2: 范围内值透传 (param1=50)
- 输入: param1=50
- 输出: fanPower: 50

### TC3: 低于下限 clamp 到 20 (param1=5)
- 输入: param1=5
- 输出: fanPower: 20

### TC4: 高于上限 clamp 到 100 (param1=200)
- 输入: param1=200
- 输出: fanPower: 100

### TC5: max uint8 clamp 到 100 (param1=255)
- 输入: param1=255
- 输出: fanPower: 100

### TC6 (@red): set_fan_enabled 通过 board 函数指针走 unused_set_fan_enabled
- 前置: red board (`.set_fan_enabled = unused_set_fan_enabled`, `has_fan = false`)
- 说明: RED 的 `has_fan = false` 导致 `fan_tick()` 完全跳过 `set_fan_enabled()`。通过 JNA 调用 `current_board->set_fan_enabled(true)` 验证 board 连线 + unused 函数
- 输入: SetFanPower(50) → fan_state.power=50, 然后 `current_board->set_fan_enabled(true)`
- 输出: fanPower: 50 (不变), gpioDOdr: 0L (PD3 不变，no-op)
- 证明: unused_set_fan_enabled 被调用且确实是 no-op

### TC7 (@cuatro): cuatro_set_fan_enabled — PD3 low (active-low)
- 前置: cuatro board (`.set_fan_enabled = cuatro_set_fan_enabled`)
- 输入: param1=50
- 输出: fanPower: 50 + stopModeRegs.gpioDOdr: 0L

### TC8 (@cuatro): 关风扇后 cooldown 结束 PD3 high
- 前置: cuatro board
- 输入: param1=0, call tick handler 24 times
- 输出: fanPower: 0 + stopModeRegs.gpioDOdr: 264L (PD3=8 + PD8=256)

### TC9 (@tres): tres_set_fan_enabled — PD3 high
- 前置: tres board (`.set_fan_enabled = tres_set_fan_enabled`)
- 输入: param1=50, call tick handler 1 times
- 输出: fanPower: 50 + stopModeRegs.gpioDOdr: 8L

## 5. 覆盖检查

| 条件 | TC1 | TC2 | TC3 | TC4 | TC5 | TC6 | TC7 | TC8 | TC9 |
|------|-----|-----|-----|-----|-----|-----|-----|-----|-----|
| percentage == 0 | ✅ | — | — | — | — | — | — | ✅ | — |
| percentage 20-100 | — | ✅ | — | — | — | ✅ | ✅ | — | ✅ |
| percentage <20 clamp | — | — | ✅ | — | — | — | — | — | — |
| percentage >100 clamp | — | — | — | ✅ | ✅ | — | — | — | — |
| unused_set_fan_enabled | — | — | — | — | — | ✅ | — | — | — |
| cuatro active-low (PD3=0) | — | — | — | — | — | — | ✅ | — | — |
| cuatro cooldown off (PD3=1) | — | — | — | — | — | — | — | ✅ | — |
| tres combined output (PD3=1) | — | — | — | — | — | — | — | — | ✅ |

✅ 所有等价类 + CLAMP 上下限 + 三块板子 set_fan_enabled 全路径已覆盖。

## 覆盖率

> 数据来源: `run_all_coverage.sh` 合并报告 (cuatro + tres + red)
> 综合行覆盖率: **78.9%** (全量), 本功能涉及以下源文件:

| 源文件 | 行覆盖 | 说明 |
|--------|--------|------|
| `main_comms.h` | 95.5% (257/269) | USB 命令处理 |
| `fan.h` | 100% (27/27) | 风扇 PWM + 冷却 |
| `cuatro.h` | 83.3% (55/66) | `cuatro_set_fan_enabled` |
| `tres.h` | 88.0% (81/92) | `tres_set_fan_enabled` |
| `red.h` | 90.0% (63/70) | → `unused_set_fan_enabled` |
| `unused_funcs.h` | 100% (23/23) | ✅ Phase D.2 |

