# GPIO 输出类型与线束初始化 — 测试设计文档

> **✅ 新建 feature**: Phase J 新增，覆盖 `board/drivers/gpio.h` 和 `board/drivers/harness.h` 中未覆盖的代码路径。
> 被测接口: JNA 直接调用 `set_gpio_output_type()` + `harness_init()` + `detect_with_pull()`

## 1. 被测功能流程图

```
J1: set_gpio_output_type(GPIO, pin, PUSH_PULL):
  [set_gpio_output_type(GPIOB, 3, PUSH_PULL)]
            │
     ┌──────┴────────────────────────────┐
     │ output_type == OPEN_DRAIN          │
     └──────┬────────────────────────────┘
        Y   │   N (PUSH_PULL)
   set bits │   clear bits ← 新覆盖
            │
            ▼
  [register_set / register_clear] → OTYPER 位变化

J2: harness_init():
  [harness_init()]
            │
            ├── set_gpio_output_type(GPIOA, 9, OPEN_DRAIN) → OTYPER bit9=1
            ├── set_gpio_output_type(GPIOA, 3, OPEN_DRAIN) → OTYPER bit3=1
            ├── set_gpio_output(GPIOA, 9, 1)               → ODR bit9=1
            ├── set_gpio_output(GPIOA, 3, 1)               → ODR bit3=1
            │   #ifndef E2E_TEST: harness_detect_orientation() (跳过)
            └── set_intercept_relay(false, false)          → relay_driven=0

J10: detect_with_pull(GPIO, pin, PULL_UP):
  [detect_with_pull(GPIOF, 7, PULL_UP)]
            │
            ├── set_gpio_mode(GPIO, pin, MODE_INPUT)
            ├── set_gpio_pullup(GPIO, pin, PULL_UP)       → PUPDR 位设置 (新路径)
            ├── delay (PULL_EFFECTIVE_DELAY)
            ├── get_gpio_input(GPIO, pin)                  → 返回 IDR 位值
            └── set_gpio_pullup(GPIO, pin, PULL_NONE)      → PUPDR 位恢复
```

## 2. 输入因子

| 因子 | 类型 | 等价类 | 取值 |
|------|------|--------|------|
| `port` | int | GPIOA..G | 1 (GPIOB), 5 (GPIOF) |
| `pin` | int | 0-15 | 3, 7 |
| `output_type` | int | OPEN_DRAIN=0, PUSH_PULL=1 | 1 (PUSH_PULL) |
| `pull_mode` | int | NONE=0, UP=1, DOWN=2 | 1 (PULL_UP) |

## 3. 输出因子

| 输出 | 类型 | 说明 |
|------|------|------|
| `gpiobOtyper` | int | GPIOB OTYPER 寄存器 (0 = bit 3 cleared by PUSH_PULL) |
| `gpioaOtyper` | int | GPIOA OTYPER 寄存器 (520 = bits 3,9 set by harness_init) |
| `gpioaOdr` | int | GPIOA ODR 寄存器 (520 = bits 3,9 set by harness_init) |
| `readFaults` | int | 故障位掩码 (0 = no fault) |

## 4. 测试用例

### TC1 (J1): PUSH_PULL 清除 OTYPER 位
- 前置: 默认 GPIOB OTYPER=0
- 输入: `set_gpio_output_type(GPIOB, 3, PUSH_PULL)`
- 输出: gpiobOtyper=0, readFaults=0
- 路径: `register_clear_bits` 分支

### TC2 (J2): harness_init 配置 relay GPIO
- 前置: cuatro 板, GPIOA 所有寄存器初始状态
- 输入: `harness_init()`
- 输出: gpioaOtyper=520 (bits 3,9), gpioaOdr=520 (bits 3,9), readFaults=0
- 路径: 4 次 set_gpio 调用 + set_intercept_relay

### TC3 (J10): detect_with_pull PULL_UP
- 前置: GPIOF pin7 IDR=0 (无外部信号)
- 输入: `detect_with_pull(GPIOF, 7, PULL_UP)`
- 输出: gpiobPupdr=0 (PUPDR 恢复), readFaults=0
- 路径: set_gpio_pullup PULL_UP 分支 + get_gpio_input

## 5. 覆盖检查

| 代码路径 | TC1 | TC2 | TC3 |
|---------|:--:|:--:|:--:|
| set_gpio_output_type PUSH_PULL (else) | ✅ | — | — |
| harness_init relay GPIO 配置 | — | ✅ | — |
| set_intercept_relay | — | ✅ | — |
| detect_with_pull PULL_UP 路径 | — | — | ✅ |
| get_gpio_input | — | — | ✅ |

✅ 所有新增代码路径已覆盖。

## 覆盖率

> 数据来源: `run_all_coverage.sh` 合并报告
> 综合行覆盖率: **92.9%** (全量)

| 源文件 | 行覆盖 | 说明 |
|--------|--------|------|
| `board/drivers/gpio.h` | **100%** (72/72) | ✅ J1 + J10: PUSH_PULL + detect_with_pull 全覆盖 |
| `board/drivers/harness.h` | **100%** (70/70) | ✅ J2: harness_init 全覆盖 |
