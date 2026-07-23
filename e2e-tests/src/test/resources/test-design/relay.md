# 拦截继电器控制 — 测试设计文档

> 功能: `set_intercept_relay()` via `comms_control_handler()` in `board/main_comms.h`
> 被测接口: USB control request 0xc5 (drive relay)

## 1. 被测功能流程图

```
drive relay (0xc5):
  [controlWrite(0xc5, param1)]
           │
           ▼
    relay_a = (param1 & 0x1) != 0
    relay_b = (param1 & 0x2) != 0
    relay_call_count++
           │
           ▼
        (done)
```

代码路径是直线，无分支。唯一的变化来自 `param1` 的低 2 位的取值组合。

## 2. 输入因子

| 因子 | 类型 | 等价类 | 取值 |
|------|------|--------|------|
| `request` | uint8 | 0xc5 (唯一) | 0xc5 |
| `param1` bit0 (relay A) | bool | 0 (off), 1 (on) | 0, 1 |
| `param1` bit1 (relay B) | bool | 0 (off), 1 (on) | 0, 1 |
| `param1` 高位 bits | uint16 | 被 bitmask 忽略，无影响 | 0, 非0 (等价) |

## 3. 输出因子 (通过 JNA 绑定的 relay 状态观测)

| 输出 | 类型 | 说明 |
|------|------|------|
| stopModeRegs.gpioAOdr | long | GPIOA ODR bit 3 (intercept) + bit 9 (ignition), active-low |
|||
| a=false,b=false → ODR=520 (bit3+bit9 HIGH, both off) |
| a=true,b=false → ODR=512 (bit3 LOW, bit9 HIGH, intercept on) |
| a=false,b=true → ODR=8 (bit3 HIGH, bit9 LOW, ignition on) |
| a=true,b=true → ODR=0 (both LOW, both on) |

## 4. 测试用例

### TC1: 两个继电器均关闭 (param1=0)
- 前置: 初始状态 (relay 未调用)
- 输入: request=0xc5, param1=0
- 输出: relay_a=false, relay_b=false
- 等价类: bit0=0, bit1=0

### TC2: 仅继电器 A 打开 (param1=1)
- 前置: 初始状态
- 输入: request=0xc5, param1=1
- 输出: relay_a=true, relay_b=false
- 等价类: bit0=1, bit1=0

### TC3: 仅继电器 B 打开 (param1=2)
- 前置: 初始状态
- 输入: request=0xc5, param1=2
- 输出: relay_a=false, relay_b=true
- 等价类: bit0=0, bit1=1

### TC4: 两个继电器均打开 (param1=3)
- 前置: 初始状态
- 输入: request=0xc5, param1=3
- 输出: relay_a=true, relay_b=true
- 等价类: bit0=1, bit1=1

### TC5: 高位 bits 被 bitmask 忽略 (param1=0xFF)
- 前置: 初始状态
- 输入: request=0xc5, param1=0xFF (高位 bits 非零但有 bit0=1, bit1=1)
- 输出: relay_a=true, relay_b=true (与 TC4 等价)
- 等价类: 高位 ≠0 但低2位 == 0b11

### TC6: 高位 bits 被 bitmask 忽略 (param1=4)
- 前置: 初始状态
- 输入: request=0xc5, param1=4 (bit2=1, bit0=0, bit1=0)
- 输出: relay_a=false, relay_b=false (与 TC1 等价)
- 等价类: 高位 ≠0 但低2位 == 0b00

## 5. 覆盖检查

| 条件 | TC1 | TC2 | TC3 | TC4 | TC5 | TC6 |
|------|-----|-----|-----|-----|-----|-----|
| bit0 = 0 | ✅ | — | ✅ | — | — | ✅ |
| bit0 = 1 | — | ✅ | — | ✅ | ✅ | — |
| bit1 = 0 | ✅ | ✅ | — | — | — | ✅ |
| bit1 = 1 | — | — | ✅ | ✅ | ✅ | — |
| 高位 = 0 | ✅ | ✅ | ✅ | ✅ | — | — |
| 高位 ≠ 0 | — | — | — | — | ✅ | ✅ |

✅ 所有等价类和 bitmask 行为已覆盖。
