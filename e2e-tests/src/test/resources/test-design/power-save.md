# 省电模式 — 测试设计文档

> 功能: `set_power_save_state()` via `comms_control_handler()` in `board/main_comms.h`
> 被测接口: USB control request 0xe7 (set power save state)
> 实现来源: 真实 `board/sys/power_saving.h` 逻辑（e2e 本地副本）

## 1. 被测功能流程图

```
set power save state (0xe7):
  [controlWrite(0xe7, param1)]
           │
           ▼
     enable = (param1 != 0)
           │
     ┌─────┴─────────────────────┐
     │  enable != power_save_    │
     │  enabled ? (幂等守卫)      │
     └─────┬─────────────────────┘
        N  │  Y
     (no-op)│
            ├── enable == true ?
       ┌────┴────┐
       ▼         ▼
   启用省电     禁用省电
   llcan_irq_   llcan_irq_
   disable(2)   enable(2)
   disable(1)   enable(1)
   enable_can_  enable_can_
   trans(false) trans(true)
   set_ir_      ─
   power(0)
       │         │
       └────┬────┘
            ▼
   power_save_enabled = enable
```

注: `harness.status` 默认为 0 (非 FLIPPED)，所以操作 bus 2 + bus 1。

## 2. 输入因子

| 因子 | 类型 | 等价类 | 取值 |
|------|------|--------|------|
| `request` | uint8 | 0xe7 (唯一) | 0xe7 |
| `param1` | uint16 | ==0 (disable), !=0 (enable) | 0, 1, 255 |
| `power_save_enabled` (前置状态) | bool | false, true | false, true |

## 3. 输出因子

| 输出 | 类型 | 说明 |
|------|------|------|
| powerSaveEnabled | boolean | 省电模式是否已启用 |
| irqDisableCount | int | llcan_irq_disable 调用次数 |
| irqEnableCount | int | llcan_irq_enable 调用次数 |
| irqDisabledBus1 | boolean | bus 1 是否被禁用 |
| irqDisabledBus2 | boolean | bus 2 是否被禁用 |
| lastIrqEnabledBus | int | 最后被启用的 bus 编号 |
| canTransceiversEnabled | boolean | enable_can_transceivers 参数 |
| canTransceiversCallCount | int | enable_can_transceivers 调用次数 |
| irPowerValue | int | set_ir_power 参数值 |
| irPowerCallCount | int | set_ir_power 调用次数 |

## 4. 测试用例

### TC1: 禁用省电模式 (param1=0, 初始 false)
- 前置: power_save_enabled=false
- 输入: param1=0
- 输出: powerSaveEnabled=false, irqDisableCount=0, irqEnableCount=0 (幂等守卫: no-op)

### TC2: 启用省电模式 (param1=1)
- 前置: power_save_enabled=false
- 输入: param1=1
- 输出: powerSaveEnabled=true, irqDisableCount=2, irqDisabledBus1=true, irqDisabledBus2=true, canTransceiversEnabled=false, canTransceiversCallCount=1, irPowerValue=0, irPowerCallCount=1

### TC3: 任意非零启用 (param1=255)
- 前置: 初始状态
- 输入: param1=255
- 输出: powerSaveEnabled=true, irqDisableCount=2

### TC4: 幂等 — 重复启用
- 前置: power_save_enabled=true
- 输入: param1=1
- 输出: powerSaveEnabled=true, irqDisableCount=0 (幂等守卫: no-op)

### TC5: 幂等 — 重复禁用
- 前置: power_save_enabled=false
- 输入: param1=0
- 输出: powerSaveEnabled=false, irqDisableCount=0 (幂等守卫: no-op)

### TC6: 启用 → 禁用
- 前置: power_save_enabled=true
- 输入: param1=0
- 输出: powerSaveEnabled=false, irqEnableCount=2, lastIrqEnabledBus=1, canTransceiversEnabled=true, canTransceiversCallCount=1

## 5. 覆盖检查

| 条件 | TC1 | TC2 | TC3 | TC4 | TC5 | TC6 |
|------|-----|-----|-----|-----|-----|-----|
| param1 == 0 | ✅ | — | — | — | ✅ | ✅ |
| param1 != 0 | — | ✅ | ✅ | ✅ | — | — |
| enable != power_save (Y) | — | ✅ | ✅ | — | — | ✅ |
| enable != power_save (N) | ✅ | — | — | ✅ | ✅ | — |
| enable == true (启用路径) | — | ✅ | ✅ | — | — | — |
| enable == false (禁用路径) | — | — | — | — | — | ✅ |
| llcan_irq_disable 调用 | — | ✅ | ✅ | — | — | — |
| llcan_irq_enable 调用 | — | — | — | — | — | ✅ |
| set_ir_power(0) 调用 | — | ✅ | ✅ | — | — | — |
| enable_can_transceivers | — | ✅ | — | — | — | ✅ |

✅ 所有代码路径、条件分支和硬件调用已覆盖。
