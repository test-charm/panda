# 省电模式 — 测试设计文档

> 功能: `set_power_save_state()` via `comms_control_handler()` in `board/main_comms.h`
> 被测接口: USB control request 0xe7 (set power save state)

## 1. 被测功能流程图

```
set power save state (0xe7):
  [controlWrite(0xe7, param1)]
           │
           ▼
     enable = (param1 != 0)
           │
           ▼
  set_power_save_state(enable)
           │
           ▼
  power_save_enabled = enable
           │
           ▼
        (done)
```

代码路径为直线，无分支。`param1` 仅通过 `!= 0` 判断转换为布尔值。

## 2. 输入因子

| 因子 | 类型 | 等价类 | 取值 |
|------|------|--------|------|
| `request` | uint8 | 0xe7 (唯一) | 0xe7 |
| `param1` | uint16 | ==0 (disable), !=0 (enable) | 0, 1, 255 |

## 3. 输出因子 (通过 JNA 绑定的省电状态观测)

| 输出 | 类型 | 说明 |
|------|------|------|
| powerSaveEnabled | boolean | 省电模式是否已启用 |

## 4. 测试用例

### TC1: 禁用省电模式 (param1=0)
- 前置: 初始状态 (power_save_enabled=false)
- 输入: request=0xe7, param1=0
- 输出: powerSaveEnabled=false
- 等价类: param1 == 0

### TC2: 启用省电模式 (param1=1)
- 前置: 初始状态
- 输入: request=0xe7, param1=1
- 输出: powerSaveEnabled=true
- 等价类: param1 != 0

### TC3: 任意非零值均启用省电模式 (param1=255)
- 前置: 初始状态
- 输入: request=0xe7, param1=255
- 输出: powerSaveEnabled=true
- 等价类: param1 != 0 (边界值，验证 !=0 逻辑)

## 5. 覆盖检查

| 条件 | TC1 | TC2 | TC3 |
|------|-----|-----|-----|
| param1 == 0 | ✅ | — | — |
| param1 != 0 | — | ✅ | ✅ |

✅ 所有等价类已覆盖。
