# CAN FD 自动切换 — 测试设计文档

> 功能: `bus_config.canfd_auto` via `comms_control_handler()` in `board/main_comms.h`
> 被测接口: USB control request 0xe8 (set CAN FD auto switching)

## 1. 被测功能流程图

```
set CAN FD auto (0xe8):
  [controlWrite(0xe8, param1, param2)]
           │
           ▼
  bus_config[param1].canfd_auto = (param2 > 0)
           │
           ▼
        (done)
```

代码路径为直线，无分支。不调用 `can_init()`，无 FDCAN 副作用。

## 2. 输入因子

| 因子 | 类型 | 等价类 | 取值 |
|------|------|--------|------|
| `request` | uint8 | 0xe8 (唯一) | 0xe8 |
| `param1` (bus) | uint16 | 0, 1, 2 (任意 bus) | 0, 1 |
| `param2` | uint16 | ==0 (disable), !=0 (enable) | 0, 1, 255 |

## 3. 输出因子

| 输出 | 类型 | 说明 |
|------|------|------|
| canfdAutoN | boolean | bus N 的 CAN FD 自动切换标志 |

## 4. 测试用例

### TC1: 禁用 CAN FD 自动切换
- 输入: param1=0, param2=0
- 输出: canfdAuto0=false

### TC2: 启用 bus 0 自动切换
- 输入: param1=0, param2=1
- 输出: canfdAuto0=true, canfdAuto1=false

### TC3: 任意非零 param2 启用
- 输入: param1=1, param2=255
- 输出: canfdAuto1=true

## 5. 覆盖检查

| 条件 | TC1 | TC2 | TC3 |
|------|-----|-----|-----|
| param2 == 0 | ✅ | — | — |
| param2 != 0 | — | ✅ | ✅ |

✅ 所有等价类已覆盖。
