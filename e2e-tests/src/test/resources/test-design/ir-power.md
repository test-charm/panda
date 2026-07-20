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
  (tracking: last_ir_power = param1, ir_power_call_count++)
           │
           ▼
        (done)
```

代码路径为直线，无分支。

## 2. 输入因子

| 因子 | 类型 | 等价类 | 取值 |
|------|------|--------|------|
| `request` | uint8 | 0xb0 (唯一) | 0xb0 |
| `param1` | uint16 | 0 (关闭), 非0 (功率值) | 0, 50, 255 |

## 3. 输出因子

| 输出 | 类型 | 说明 |
|------|------|------|
| irPower | AdaptiveList\<Integer\> | 所有 set_ir_power 调用历史，未调用时为空列表 |

## 4. 测试用例

### TC1: 设置 IR 功率为 0
- 前置: 初始状态
- 输入: param1=0
- 输出: irPower={value=0, callCount=1}

### TC2: 设置 IR 功率为非零值
- 前置: 初始状态
- 输入: param1=50
- 输出: irPower={value=50, callCount=1}

### TC3: 设置 IR 功率为最大值
- 前置: 初始状态
- 输入: param1=255
- 输出: irPower={value=255, callCount=1}

## 5. 覆盖检查

| 条件 | TC1 | TC2 | TC3 |
|------|-----|-----|-----|
| param1 == 0 | ✅ | — | — |
| param1 > 0 | — | ✅ | ✅ |

✅ 所有等价类已覆盖。
