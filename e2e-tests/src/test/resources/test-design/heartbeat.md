# 心跳机制 — 测试设计文档

> 功能: `comms_control_handler()` heartbeat case in `board/main_comms.h`
> 被测接口: USB control request 0xf3 (heartbeat), 0xf8 (disable heartbeat)

## 1. 被测功能流程图

```
heartbeat (0xf3):
  [controlWrite(0xf3, param1)]
         │
         ▼
    heartbeat_counter = 0
    heartbeat_lost = false
    heartbeat_disabled = false
         │
    ┌────┴────────────┐
    │  param1 == 1 ?   │
    └────┬────────────┘
      Y  │  N
         │
    ┌────┴────┐
    │         │
 engaged=T   engaged=F

heartbeat disable (0xf8):
  [controlWrite(0xf8, param1)]
         │
    ┌────┴──────────────────────────┐
    │  is_car_safety_mode(current)?  │
    └────┬──────────────────────────┘
      Y  │  N
         │
    ┌────┴─────────────────┐
    │                      │
  (no-op,              heartbeat_disabled
  cannot disable)      = true
```

## 2. 输入因子

| 因子 | 类型 | 等价类 | 取值 |
|------|------|--------|------|
| `request` | uint8 | 0xf3 (heartbeat), 0xf8 (disable) | 0xf3, 0xf8 |
| `param1` (for 0xf3) | uint16 | ==1 (engaged), !=1 (not engaged) | 0, 1, 2 |
| `current_safety_mode` (for 0xf8) | uint16 | car-safety (TOYOTA=2), non-car-safety (SILENT=0, ALLOUTPUT=17) | 0, 2, 17 |

## 3. 输出因子 (通过 JNA 绑定的心跳状态观测)

| 输出 | 类型 | 说明 |
|------|------|------|
| heartbeatCounter | uint32 | 心跳计数器 |
| heartbeatLost | bool | 心跳丢失标志 |
| heartbeatDisabled | bool | 心跳禁用标志 |
| heartbeatEngaged | bool | 心跳已建立标志 |

## 4. 测试用例

### TC1: 心跳未建立 (param1=0)
- 前置: 初始状态 (SILENT safety mode)
- 输入: request=0xf3, param1=0
- 输出: counter=0, lost=false, disabled=false, engaged=false
- 路径: heartbeat case → param1 != 1 → engaged=false

### TC2: 心跳建立 (param1=1)
- 前置: 初始状态
- 输入: request=0xf3, param1=1
- 输出: counter=0, lost=false, disabled=false, engaged=true
- 路径: heartbeat case → param1 == 1 → engaged=true

### TC3: 非 car 安全模式下禁用心跳
- 前置: 初始状态 (SILENT, non-car safety)
- 输入: request=0xf8
- 输出: disabled=true, 其他状态不变
- 路径: disable case → !is_car_safety_mode → disabled=true

### TC4: 心跳清除 disabled 标志
- 前置: 先禁用心跳 (0xf8 in SILENT) → disabled=true
- 输入: request=0xf3, param1=1
- 输出: counter=0, lost=false, disabled=false, engaged=true
- 路径: heartbeat case 始终设 disabled=false，param1==1 设 engaged=true
- 注: 第二个 control write 使用 `control write "Heartbeat":`（spec-based）而非 `control write:`（expression-based），因为 expression-based 步骤的 `createAll` + `query()` 在单场景多步调用时会返回前一步骤的对象

### TC5: car 安全模式下无法禁用心跳
- 前置: 切换到 TOYOTA (car safety) 模式
- 输入: request=0xf8
- 输出: disabled=false (被阻止)
- 路径: disable case → is_car_safety_mode → no-op

### TC6: 心跳 param1≠1 与 param1=0 等价
- 前置: 初始状态
- 输入: request=0xf3, param1=2
- 输出: counter=0, lost=false, disabled=false, engaged=false
- 路径: heartbeat case → param1 != 1 → engaged=false

## 5. 覆盖检查

| 条件 | TC1 | TC2 | TC3 | TC4 | TC5 | TC6 |
|------|-----|-----|-----|-----|-----|-----|
| param1==1 branch (true) | — | ✅ | — | — | — | — |
| param1!=1 branch (false) | ✅ | — | — | ✅ | — | ✅ |
| is_car_safety_mode (true) | — | — | — | — | ✅ | — |
| is_car_safety_mode (false) | — | — | ✅ | ✅ | — | — |
| disabled 清除 (0xf3 后 disabled=false) | — | — | — | ✅ | — | — |
| param1 等价类 !=1 | ✅ | — | — | — | — | ✅ |
| param1 等价类 ==1 | — | ✅ | — | — | — | — |
| safety_mode 等价类 car | — | — | — | — | ✅ | — |
| safety_mode 等价类 non-car | — | — | ✅ | ✅ | — | — |

✅ 所有条件分支、等价类和状态变化已覆盖。
