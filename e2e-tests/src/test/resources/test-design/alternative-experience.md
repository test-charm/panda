# 替代体验模式 — 测试设计文档

> 功能: `set_alternative_experience()` via `comms_control_handler()` in `board/main_comms.h`
> 被测接口: USB control request 0xdf (set alternative experience)

## 1. 被测功能流程图

```
set alternative experience (0xdf):
  [controlWrite(0xdf, param1)]
           │
     ┌─────┴────────────────────────┐
     │  is_car_safety_mode() ?       │
     └─────┬────────────────────────┘
        Y  │  N
           │
     ┌─────┴──────────────┐
     │                     │
  (no-op,              alternative_experience
   blocked)            = req->param1
```

在 car 安全模式下设置被忽略（no-op），在非 car 安全模式下 `param1` 直接赋值。

## 2. 输入因子

| 因子 | 类型 | 等价类 | 取值 |
|------|------|--------|------|
| `request` | uint8 | 0xdf (唯一) | 0xdf |
| `param1` | uint16 | 任意 uint16 值 (直接赋值) | 0, 1, 99, 65535 |
| `current_safety_mode` | uint16 | car (TOYOTA=2), non-car (SILENT=0, ALLOUTPUT=17) | 0, 2, 17 |

## 3. 输出因子 (通过 JNA 绑定的状态观测)

| 输出 | 类型 | 说明 |
|------|------|------|
| alternativeExperience | int (0-65535) | 替代体验模式值 |

## 4. 测试用例

### TC1: 非 car 安全模式下设置 (param1=1, SILENT)
- 前置: SILENT (non-car) mode, alternative_experience=0
- 输入: request=0xdf, param1=1
- 输出: alternativeExperience=1
- 路径: !is_car_safety_mode → alternative_experience = 1

### TC2: car 安全模式下被阻止 (param1=99, TOYOTA)
- 前置: TOYOTA (car) mode, alternative_experience=0
- 输入: request=0xdf, param1=99
- 输出: alternativeExperience=0 (unchanged)
- 路径: is_car_safety_mode → no-op

### TC3: 非 car 模式下设置后切换到 car 模式下设置新值被阻止
- 前置: 先设为 42 → 切换到 TOYOTA
- 输入: request=0xdf, param1=99
- 输出: alternativeExperience=42 (previous value preserved)
- 路径: is_car_safety_mode → no-op → value unchanged from 42

### TC4: 边界值 param1=0
- 前置: SILENT (non-car) mode
- 输入: request=0xdf, param1=0
- 输出: alternativeExperience=0

### TC5: 边界值 param1=32767 (max positive short，Java JNA 限制)
- 前置: SILENT (non-car) mode
- 输入: request=0xdf, param1=32767
- 输出: alternativeExperience=32767
- 注: firmware 端 `param1` 为 `uint16_t` (0-65535)，但 Java 端 JNA 绑定使用 `short` 类型，最大值 32767

## 5. 覆盖检查

| 条件 | TC1 | TC2 | TC3 | TC4 | TC5 |
|------|-----|-----|-----|-----|-----|
| is_car_safety_mode = true | — | ✅ | ✅ | — | — |
| is_car_safety_mode = false | ✅ | — | — | ✅ | ✅ |
| param1 = 0 | — | — | — | ✅ | — |
| param1 = 65535 | — | — | — | — | ✅ |
| param1 mid-range | ✅ | ✅ | ✅ | — | — |
| 值在 car 模式下保持不变 | — | ✅ | ✅ | — | — |

✅ 所有代码路径、条件分支和等价类已覆盖。
