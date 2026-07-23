# 警笛控制 — 测试设计文档

> 功能: `siren_enabled` via `comms_control_handler()` in `board/main_comms.h`
> 被测接口: USB control request 0xf6 (set siren enabled)

## 1. 被测功能流程图

```
set siren enabled (0xf6):
  [controlWrite(0xf6, param1)]
           │
           ▼
  siren_enabled = (param1 != 0)
           │
           ▼
        (done)
```

代码路径为直线，无分支。`param1` 仅通过 `!= 0` 判断转换为布尔值。

## 2. 输入因子

| 因子 | 类型 | 等价类 | 取值 |
|------|------|--------|------|
| `request` | uint8 | 0xf6 (唯一) | 0xf6 |
| `param1` | uint16 | ==0 (disable), !=0 (enable) | 0, 1, 255 |

## 3. 输出因子 (通过假硬件寄存器 GPIOB ODR 观测)

| 输出 | 类型 | 说明 |
|------|------|------|
| stopModeRegs.gpioBOdr | long | GPIOB ODR bit 14 (PB14, 警笛引脚) |
|||
| disabled (param1==0) → ODR bit14=0 (0L) |
| enabled (param1!=0) → ODR bit14=1 (16384L) |

> 注: 警笛启用后通过 `jna_tick_siren()` 将 `siren_enabled` 标志应用到 GPIO 输出。

## 4. 测试用例

### TC1: 禁用警笛 (param1=0)
- 前置: 初始状态 (siren_enabled=false)
- 输入: request=0xf6, param1=0
- 输出: stopModeRegs.gpioBOdr=0L (PB14 low)
- 等价类: param1 == 0

### TC2: 启用警笛 (param1=1)
- 前置: 初始状态
- 输入: request=0xf6, param1=1
- 输出: stopModeRegs.gpioBOdr=16384L (PB14 high)
- 等价类: param1 != 0

### TC3: 任意非零值均启用警笛 (param1=255)
- 前置: 初始状态
- 输入: request=0xf6, param1=255
- 输出: stopModeRegs.gpioBOdr=16384L (PB14 high)
- 等价类: param1 != 0 (验证 !=0 逻辑)

## 5. 覆盖检查

| 条件 | TC1 | TC2 | TC3 |
|------|-----|-----|-----|
| param1 == 0 | ✅ | — | — |
| param1 != 0 | — | ✅ | ✅ |

✅ 所有等价类已覆盖。
