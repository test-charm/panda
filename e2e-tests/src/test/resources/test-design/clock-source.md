# 自定义时钟源 — 测试设计文档

> 功能: `clock_source_set_timer_params()` via `comms_control_handler()` in `board/main_comms.h`
> 被测接口: USB control request 0xe6 (set custom clock source)

## 1. 被测功能流程图

```
set clock source (0xe6):
  [controlWrite(0xe6, param1, param2)]
           │
           ▼
  clock_source_set_timer_params(param1, param2)
           │
     ┌─────┴──────────────────────────┐
     │  register_set(TIM1->CCR1,       │
     │    ((param1 & 0xFF00)>>8)*10)   │
     │  register_set(TIM1->CCR2,       │
     │    (param1 & 0xFF)*10)          │
     │  register_set(TIM8->CCR3,       │
     │    ((param2 & 0xFF00)>>8)*10)   │
     │  register_set(TIM1->ARR,        │
     │    ((param2 & 0xFF)*10)-1)      │
     │  register_set(TIM1->CCR4,       │
     │    (ARR+1)/2)                   │
     └─────────────────────────────────┘
           │
           ▼
        (done)
```

e2e 环境使用假 TIM 寄存器，`register_set` 直接写入 fake_TIM1/fake_TIM8。

## 2. 输入因子

| 因子 | 类型 | 等价类 | 取值 |
|------|------|--------|------|
| `request` | uint8 | 0xe6 (唯一) | 0xe6 |
| `param1` | uint16 | 0, 100, 32767 | 0, 100, 32767 |
| `param2` | uint16 | 0, 50, 32767 | 0, 50, 32767 |

## 3. 输出因子

| 输出 | 类型 | 说明 |
|------|------|------|
| clockSource.ccr1 | int | TIM1->CCR1 |
| clockSource.ccr2 | int | TIM1->CCR2 |
| clockSource.ccr3 | int | TIM8->CCR3 |
| clockSource.arr | int | TIM1->ARR |
| clockSource.ccr4 | int | TIM1->CCR4 |

## 4. 测试用例

### TC1: param1=100, param2=50
- 输出: ccr1=0, ccr2=1000, ccr3=0, arr=499, ccr4=250
- 验证高低字节拆分逻辑

### TC2: param1=0, param2=0
- 输出: ccr1=0, ccr2=0, ccr3=0, arr=65535, ccr4=32768
- 验证 ARR 溢出 mask 到 0xFFFF

### TC3: param1=32767, param2=32767 (max short)
- 输出: ccr1=1270, ccr2=2550, ccr3=1270, arr=2549, ccr4=1275
- 验证 16-bit 边界拆分

## 5. 覆盖检查

| 条件 | TC1 | TC2 | TC3 |
|------|-----|-----|-----|
| 正常值 | ✅ | — | — |
| 零值/溢出 | — | ✅ | — |
| 边界值 | — | — | ✅ |

✅ 所有等价类已覆盖。
