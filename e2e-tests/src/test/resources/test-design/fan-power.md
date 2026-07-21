# 风扇功率控制 — 测试设计文档

> 功能: `fan_set_power()` via `comms_control_handler()` in `board/main_comms.h`
> 被测接口: USB control request 0xb1 (set fan power)
> 实现来源: 真实 `board/drivers/fan.h` 逻辑（e2e 自动生成）

## 1. 被测功能流程图

```
set fan power (0xb1):
  [controlWrite(0xb1, param1)]
           │
           ▼
  fan_set_power(param1)
           │
     ┌─────┴──────────────┐
     │ percentage > 0 ?     │
     └─────┬──────────────┘
        N  │  Y
     ┌─────┴──────────────┐
     │                      │
  fan_state.power     fan_state.power
    = 0              = CLAMP(%, 20, 100)
           │
           ▼
        (done)
```

## 2. 输入因子

| 因子 | 类型 | 等价类 | 取值 |
|------|------|--------|------|
| `request` | uint8 | 0xb1 (唯一) | 0xb1 |
| `param1` (percentage) | uint16 | ==0, 1-19 (clamp→20), 20-100 (pass), >100 (clamp→100) | 0, 5, 50, 200, 255 |

## 3. 输出因子

| 输出 | 类型 | 说明 |
|------|------|------|
| fanPower | int | fan_state.power 值 |

## 4. 测试用例

### TC1: 关闭风扇 (param1=0)
- 输入: param1=0
- 输出: fanPower=0
- 路径: percentage==0 → fan_state.power=0

### TC2: 范围内值透传 (param1=50)
- 输入: param1=50
- 输出: fanPower=50
- 路径: percentage>0 → CLAMP(50, 20, 100)=50

### TC3: 低于下限 clamp 到 20 (param1=5)
- 输入: param1=5
- 输出: fanPower=20
- 路径: percentage>0 → CLAMP(5, 20, 100)=20

### TC4: 高于上限 clamp 到 100 (param1=200)
- 输入: param1=200
- 输出: fanPower=100
- 路径: percentage>0 → CLAMP(200, 20, 100)=100

### TC5: max uint8 clamp 到 100 (param1=255)
- 输入: param1=255
- 输出: fanPower=100

## 5. 覆盖检查

| 条件 | TC1 | TC2 | TC3 | TC4 | TC5 |
|------|-----|-----|-----|-----|-----|
| percentage == 0 | ✅ | — | — | — | — |
| percentage > 0 + in range | — | ✅ | — | — | — |
| percentage > 0 + below min | — | — | ✅ | — | — |
| percentage > 0 + above max | — | — | — | ✅ | ✅ |

✅ 所有等价类 + CLAMP 上下限已覆盖。
