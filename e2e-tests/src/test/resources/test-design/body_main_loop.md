# Body Main Loop 测试设计

> 最后更新: 2026-08-06 (B22 完成：循环体 4 分支 + 真实 stub 替换 + 定时器寄存器验证)
> Feature 文件: `body_main_loop.feature` (5 场景)
> 覆盖文件: `board/body/main.c`, `board/sys/critical.h`, `board/drivers/timers.h`

## 一、被测代码

### 1.1 `body_main()` 主循环体 (`board/body/main.c:127-144`)

生产固件中为 `while(true)` 无限循环，e2e 构建中替换为 `do { ... } while(false)`（单次执行）：

```c
uint32_t now = microsecond_timer_get();

// DotStar LED 分支 (3 路)
if (plug_charging) {
    motor_set_enable(false);
    dotstar_apply_breathe({255, 40, 0}, now, 2000000U);   // 橙色呼吸
} else if (ignition) {
    dotstar_run_rainbow(now);                                // 彩虹
} else {
    dotstar_apply_breathe({0, 255, 10}, now, 1500000U);     // 绿色呼吸
}

// 电机 + CAN 分支 (2 路)
if (ignition) {
    motor_set_enable(true);
    body_can_periodic(now, ignition, plug_charging);
} else {
    motor_set_enable(false);
}

dotstar_show();
```

### 1.2 替换的 no-op stub

| 函数 | 替换为真实代码 | 来源 |
|------|-------------|------|
| `disable_interrupts()` / `enable_interrupts()` | ✅ | `board/sys/critical.h` (通过 `#include`) |
| `tick_timer_init()` | ✅ | `board/drivers/timers.h` (复制体在 libpanda_body.c) |
| `interrupt_timer_init()` | ✅ | `board/drivers/timers.h` (复制体在 libpanda_body.c) |
| `timer_init()` (static helper) | ✅ | `board/drivers/timers.h` (复制体在 libpanda_body.c) |

## 二、输入因子

| 因子 | 类型 | 来源 | 等价类 |
|------|------|------|--------|
| `plug_charging` | bool | `jna_body_set_plug_charging_val()` | false, true |
| `ignition` | bool | `jna_body_set_ignition_val()` | false, true |
| `now_us` | uint32 | `jna_body_main_loop_once(now_us)` | 0, 375000, 500000 |

## 三、输出因子

| 因子 | 观测方式 |
|------|---------|
| dotstar_effect | `dotstar.pixel0R/G/B` |
| motor_enable | `motorEnabled` |
| tick timer registers | `tickDier`/`tickCr1`/`tickSr` |
| interrupt timer registers | `intTimerDier`/`intTimerCr1`/`intTimerSr` |
| red_led_mode | `redLedMode` |
| microsecond_timer | `microsecondTimer` |

## 四、测试用例

### B22-INIT — body_main() init 序列验证

| 验证项 | 预期值 | 说明 |
|--------|--------|------|
| `redLedMode` | 1 | `led_init()` GPIOA pin 10 → output |
| `microsecondTimer` | 0 | `microsecond_timer_init()` 初始值 |
| `tickDier` | 1 | TIM_DIER_UIE (tick_timer_init 真实代码) |
| `tickCr1` | 1 | TIM_CR1_CEN (tick_timer_init 真实代码) |
| `tickSr` | 0 | 中断标志清除 |
| `intTimerDier` | 1 | TIM_DIER_UIE (interrupt_timer_init 真实代码) |
| `intTimerCr1` | 1 | TIM_CR1_CEN (interrupt_timer_init 真实代码) |
| `intTimerSr` | 0 | 中断标志清除 |
| `plugCharging` | false | GPIO 默认状态 |
| `ignition` | false | 静态变量初始值 |
| `motorEnabled` | false | 循环体默认分支 |
| `dotstar.initialized` | true | dotstar_init() 成功 |

### B22-LOOP-01 — 绿色呼吸 + 电机关闭

| 输入 (now_us=375000) | 值 | 输出 | 预期值 |
|----------------------|-----|------|--------|
| plug_charging | false | motorEnabled | false |
| ignition | false | dotstar.pixel0R/G/B | 0/127/4 |

### B22-LOOP-02 — 橙色呼吸 + 电机关闭

| 输入 (now_us=500000) | 值 | 输出 | 预期值 |
|----------------------|-----|------|--------|
| plug_charging | true | motorEnabled | false |
| ignition | false | dotstar.pixel0R/G/B | 127/19/0 |

### B22-LOOP-03 — 彩虹 + 电机使能

| 输入 (now_us=0) | 值 | 输出 | 预期值 |
|-----------------|-----|------|--------|
| plug_charging | false | motorEnabled | true |
| ignition | true | dotstar.pixel0R/G/B | 255/0/0 |
| | | dotstar.pixel3R/G/B | 45/210/0 |

### B22-LOOP-04 — 橙色呼吸 + 电机使能 (充电优先)

| 输入 (now_us=500000) | 值 | 输出 | 预期值 |
|----------------------|-----|------|--------|
| plug_charging | true | motorEnabled | true |
| ignition | true | dotstar.pixel0R/G/B | 127/19/0 |

## 五、完备性验证

- [x] 2² = 4 个 bool 组合全部覆盖
- [x] if-else if-else 3 个 DotStar 分支各 ≥1 用例
- [x] if-else 2 个电机分支各 ≥1 用例
- [x] 6 个真实 stub 替换已验证 (critical.h ×2 + timers.h ×4)
- [x] 定时器 DIER/CR1/SR 寄存器验证
- [x] led_init() GPIO 模式验证

## 一、被测代码

`board/body/main.c:127-144` — while 循环体（e2e 中为 do-while(false) 单次执行）

```c
uint32_t now = microsecond_timer_get();

// DotStar LED 分支 (3 路)
if (plug_charging) {
    motor_set_enable(false);                                          // charging path
    dotstar_apply_breathe((dotstar_rgb_t){255U, 40U, 0U}, now, 2000000U);  // 橙色呼吸
} else if (ignition) {
    dotstar_run_rainbow(now);                                         // 彩虹
} else {
    dotstar_apply_breathe((dotstar_rgb_t){0U, 255U, 10U}, now, 1500000U);  // 绿色呼吸
}

// 电机 + CAN 分支 (2 路)
if (ignition) {
    motor_set_enable(true);                                           // 电机使能
    body_can_periodic(now, ignition, plug_charging);                  // CAN 周期发送
} else {
    motor_set_enable(false);                                          // 电机关闭
}

dotstar_show();                                                       // 刷新 LED
```

## 二、输入因子

| 因子 | 类型 | 来源 | 等价类 | 边界值 |
|------|------|------|--------|--------|
| `plug_charging` | bool | `get_gpio_input(CHARGING_DETECT_PORT, CHARGING_DETECT_PIN)` | false, true | — |
| `ignition` | bool | `exti15_10_handler()` 翻转 | false, true | — |

> `ignition` 是 static volatile 变量，由 `exti15_10_handler()` 中断处理函数翻转。在 e2e 中需直接设置。

## 三、输出因子

| 因子 | 说明 | 观测方式 |
|------|------|---------|
| dotstar_effect | LED 效果：breathe_orange / rainbow / breathe_green | 读取 `dotstar_state.pixels[]` RGB 值 |
| motor_enable | `motor_set_enable()` 调用结果 | 读取 `LEFT_TIM->BDTR & TIM_BDTR_MOE` |
| can_periodic_sent | `body_can_periodic()` 是否发送 CAN 帧 | 检查 `can_tx_q` 队列非空 |

## 四、流程图

```
[loop body start]
      │
      ▼
{plug_charging?}
   ├── true ──→ motor_set_enable(false) ──→ dotstar_apply_breathe(orange) ──┐
   │                                                                        │
   └── false ──→ {ignition?}                                                │
                    ├── true ──→ dotstar_run_rainbow() ─────────────────────┤
                    │                                                        │
                    └── false ──→ dotstar_apply_breathe(green) ─────────────┤
                                                                             │
                                                                             ▼
                                                          {ignition?}
                                                             ├── true ──→ motor_set_enable(true)
                                                             │             body_can_periodic()
                                                             │
                                                             └── false ──→ motor_set_enable(false)
                                                                             │
                                                                             ▼
                                                                      dotstar_show()
                                                                             │
                                                                             ▼
                                                                       [loop body end]
```

## 五、测试用例

### TC-LOOP-01: 默认状态 — 绿色呼吸 + 电机关闭 ✅ 已覆盖

| 输入 | 值 |
|------|-----|
| plug_charging | false |
| ignition | false |

| 输出 | 预期值 |
|------|--------|
| dotstar_effect | breathe_green (r=0, g=255, b=10) |
| motor_enable | false |
| can_periodic_sent | no |

覆盖路径: `body_main()` 初始化后首次循环（默认状态）→ 已通过 `jna_panda_init()` 覆盖

### TC-LOOP-02: 充电中 — 橙色呼吸 + 电机关闭

| 输入 | 值 |
|------|-----|
| plug_charging | true |
| ignition | false |

| 输出 | 预期值 |
|------|--------|
| dotstar_effect | breathe_orange (r=255, g=40, b=0) |
| motor_enable | false |
| can_periodic_sent | no |

覆盖路径: `if(plug_charging)` → orange breathe + motor off → `if(!ignition)` → motor off

### TC-LOOP-03: 点火中 — 彩虹 + 电机使能 + CAN 周期发送

| 输入 | 值 |
|------|-----|
| plug_charging | false |
| ignition | true |

| 输出 | 预期值 |
|------|--------|
| dotstar_effect | rainbow |
| motor_enable | true |
| can_periodic_sent | yes |

覆盖路径: `if(!plug_charging) → else if(ignition)` → rainbow + `if(ignition)` → motor on + can_periodic

### TC-LOOP-04: 充电 + 点火 — 橙色呼吸 + 电机使能 + CAN 周期发送

| 输入 | 值 |
|------|-----|
| plug_charging | true |
| ignition | true |

| 输出 | 预期值 |
|------|--------|
| dotstar_effect | breathe_orange (r=255, g=40, b=0) |
| motor_enable | true |
| can_periodic_sent | yes |

覆盖路径: `if(plug_charging)` → orange breathe + `if(ignition)` → motor on + can_periodic

## 六、完备性验证

- [x] 所有条件分支覆盖: 2 个 bool 因子 × 4 组合 = 4 用例
- [x] 每个 if-else if-else 的 3 个分支各至少 1 个用例
- [x] 嵌套 if(ignition) 的 2 个分支各至少 1 个用例
- [x] 每个因子取值在至少 1 个用例中使用

## 七、实现方案

由于 `body_main()` 在 `jna_panda_init()` / `setUp()` 中执行，初始化后 `plug_charging` 和 `ignition` 均为 false。为测试其他分支，需:

1. **libpanda_body.c**: 新增 JNA wrapper
   - `jna_body_set_ignition_val(int val)` — 直接设置 `ignition` 静态变量
   - `jna_body_set_plug_charging_val(int val)` — 直接设置 `plug_charging` 静态变量
   - `jna_body_main_loop_once()` — 执行一次循环体（复制循环体代码）
   - `jna_body_get_motor_enable_state()` — 读取 `LEFT_TIM->BDTR & TIM_BDTR_MOE`

2. **BodyPandaClient.java**: 新增 JNA 接口 + 访问器

3. **BodyCommandsStepDefs.java**: 新增 step definitions

4. **body_main_loop.feature**: 4 个场景 (01 已覆盖，新增 02-04)
