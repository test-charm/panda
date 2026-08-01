# Body DotStar LED 驱动 — 测试设计文档

> 功能: `dotstar_init()` + `dotstar_fill()` + `dotstar_set_pixel()` + `dotstar_set_global_brightness()` + `dotstar_run_rainbow()` + `dotstar_apply_breathe()` in `board/body/dotstar.h`
> 被测接口: `jna_panda_init()` → `body_can_init()` → `dotstar_init()` (启动路径); JNA 直接调用 `dotstar_fill` / `dotstar_show` / `dotstar_set_pixel` / `dotstar_set_global_brightness` / `dotstar_run_rainbow` / `dotstar_apply_breathe`
> 固件目标: body (`board/body/main.c`)
> 已完成: B10 + B11 + B12 (2026-08-01)

## 1. 被测功能流程图

```
jna_panda_init() (body 固件启动模拟, line 115-117)
      │
      ▼
body_can_init()                            — 启动顺序中的前置步骤
      │
      ▼
dotstar_init()
      │
      ├─ GPIO CLK 引脚: PULL_NONE + PUSH_PULL + MODE_OUTPUT + OSPEED5
      ├─ GPIO DATA 引脚: PULL_NONE + PUSH_PULL + MODE_OUTPUT + OSPEED5
      ├─ dotstar_state.initialized = true
      ├─ dotstar_state.global_brightness = DOTSTAR_GLOBAL_BRIGHTNESS_MAX (31)
      ├─ 清零所有 10 个像素 (r=g=b=0)
      └─ dotstar_show()                         ← 发送全黑帧到 LED 链

dotstar_fill(r, g, b)
      │
      └─ [initialized?] → 遍历 pixel[0..9] = {r, g, b}

dotstar_set_pixel(index, r, g, b)
      │
      └─ [initialized && index < 10?] → pixel[index] = {r, g, b}

dotstar_set_global_brightness(brightness)
      │
      └─ brightness = CLAMP(brightness, 0, 31)

dotstar_run_rainbow(now_us)
      │
      ├─ brightness_phase = (now_us / 40000) % 62
      ├─ brightness = (phase ≤ 31) ? phase+1 : 62-phase  (三角波, 1..31)
      ├─ base_hue = (now_us / 10000) % 765
      │
      └─ for i = 0..9:
            hue = (base_hue + i*70) % 765
            dotstar_hue_to_rgb(hue) → 像素 i
          dotstar_set_global_brightness(brightness)

dotstar_apply_breathe(color, now_us, cycle_us)
      │
      ├─ [cycle_us == 0?] → brightness=MAX, fill(color)  ← 全亮度路径
      │
      └─ [cycle_us > 0]:
            phase = now_us % cycle_us
            half_cycle = cycle_us / 2
            amplitude = (phase ≤ half_cycle) ? phase : (cycle_us - phase)
            scale = (amplitude * 255) / half_cycle
            r' = (color.r * scale) / 255, g', b' 同理
            dotstar_set_global_brightness(MAX)
            dotstar_fill(r', g', b')
```

> **关键验证点**: `dotstar_state.initialized` 在 `jna_panda_init()` 后自动为 true。虽然 `body_can_init()` 先于 `dotstar_init()` 执行，但 LED 状态验证仍只依赖 `dotstar_state.pixels[i]` 和 `dotstar_state.global_brightness`。
> `dotstar_show()` 仅在 `initialized=true` 时执行 SPI 帧发送（e2e 中通过假 GPIO 验证寄存器写入）。

## 2. 输入因子

| 因子 | 类型 | 等价类 | 取值 |
|------|------|--------|------|
| `r, g, b` (fill) | uint8 | 任意颜色 | (100, 150, 200), (0, 0, 0) |
| `index` (set_pixel) | uint16 | 有效 (0-9), 边界 | 3 |
| `r, g, b` (set_pixel) | uint8 | 与背景不同的颜色 | (255, 128, 64) |
| `brightness` (set_global) | uint8 | 正常值, 超上限 | 50 (clamp to 31) |
| `now_us` (rainbow) | uint32 | 任意时间戳 | 500000 |
| `color` (breathe) | dotstar_rgb_t | 任意颜色 | (100, 150, 200), (50, 100, 150) |
| `now_us` (breathe) | uint32 | 任意时间戳 | 250000, 0 |
| `cycle_us` (breathe) | uint32 | 零 (全亮度), 非零 (三角波) | 0, 1000000 |

## 3. 输出因子

| 输出 | 类型 | 说明 |
|------|------|------|
| `dotstar.initialized` | bool | 初始化标志 (jna_panda_init 后 true) |
| `dotstar.brightness` | int | 全局亮度 0-31 |
| `dotstar.pixel0R/G/B` | int | 像素 0 的 RGB |
| `dotstar.pixel3R/G/B` | int | 像素 3 的 RGB |
| `dotstar.pixel9R/G/B` | int | 像素 9 的 RGB |

> 所有输出通过 `BodyPandaClient.DotstarState` 内嵌对象暴露，DAL 验证语法为 `dotstar.pixel0R: 100`。

## 4. 测试用例

### TC1 (B10): dotstar_init 启动初始化 + dotstar_fill 全像素着色
- 前置: `jna_panda_init()` 自动调用 `dotstar_init()`（所有场景共享）
- 步骤: 无额外输入
- 输出: `dotstar.initialized=true`, `dotstar.brightness=31`
- 覆盖: `dotstar_init()` GPIO 初始化 + 状态清零路径

### TC2 (B10): dotstar_fill 全部像素着色
- 前置: TC1 验证通过
- 步骤: `dotstar_fill(100, 150, 200)` → `dotstar_show()`
- 输出: `dotstar.pixel0R=100, G=150, B=200`, `dotstar.pixel9R=100, G=150, B=200`
- 覆盖: `dotstar_fill()` 10 像素循环 + `dotstar_show()` SPI 帧发送路径

### TC3 (B10b): dotstar_set_pixel 单独设置像素
- 步骤: `dotstar_fill(0,0,0)` → `dotstar_set_pixel(3, 255, 128, 64)`
- 输出: `dotstar.pixel3R=255, G=128, B=64`; `dotstar.pixel0R=0, G=0, B=0`
- 覆盖: `dotstar_set_pixel()` 单像素修改 + 不影响其他像素

### TC4 (B10c): dotstar_set_global_brightness 钳位
- 步骤: `dotstar_set_global_brightness(50)`
- 输出: `dotstar.brightness=31`
- 覆盖: `dotstar_set_global_brightness()` 上限钳位逻辑 (`brightness > 31 ? 31 : brightness`)

### TC5 (B11): dotstar_run_rainbow 彩虹动画
- 步骤: `dotstar_run_rainbow(500000)` → `dotstar_show()`
- 预期: `now_us=500000` → `brightness_phase=12` → `brightness=13`; `base_hue=50` → 像素0 `hue=50` → `r=205, g=50, b=0`
- 输出: `dotstar.pixel0R=205, G=50, B=0`, `dotstar.brightness=13`
- 覆盖: `dotstar_run_rainbow()` 三角波亮度 + `dotstar_hue_to_rgb()` 色相段 0 (hue<255)

### TC6 (B12): dotstar_apply_breathe 三角波呼吸效果
- 步骤: `dotstar_apply_breathe({100,150,200}, 250000, 1000000)`
- 预期: `phase=250000≤500000` → `amplitude=250000` → `scale=127` → `r=(100*127)/255=49, g=74, b=99`
- 输出: `dotstar.pixel0R=49, G=74, B=99`
- 覆盖: `dotstar_apply_breathe()` 三角波相位计算 + 颜色缩放

### TC7 (B12b): dotstar_apply_breathe cycle_us=0 全亮度路径
- 步骤: `dotstar_apply_breathe({50,100,150}, 0, 0)`
- 输出: `dotstar.brightness=31`, `dotstar.pixel0R=50, G=100, B=150`
- 覆盖: `dotstar_apply_breathe()` `cycle_us==0` 分支 → `set_global_brightness(MAX) + fill(color)`

## 5. 覆盖检查

| 条件 | TC1 | TC2 | TC3 | TC4 | TC5 | TC6 | TC7 |
|------|-----|-----|-----|-----|-----|-----|-----|
| dotstar_init() GPIO + 状态清零 | ✅ | — | — | — | — | — | — |
| dotstar_fill() 10 像素循环 | — | ✅ | ✅ | — | — | — | — |
| dotstar_show() SPI 帧发送 | — | ✅ | — | — | ✅ | — | — |
| dotstar_set_pixel() 单像素 + 边界检查 | — | — | ✅ | — | — | — | — |
| dotstar_set_global_brightness() 钳位 | — | — | — | ✅ | — | — | — |
| dotstar_run_rainbow() 彩虹动画 | — | — | — | — | ✅ | — | — |
| dotstar_hue_to_rgb() 色相段 0 | — | — | — | — | ✅ | — | — |
| dotstar_apply_breathe() 三角波 | — | — | — | — | — | ✅ | — |
| dotstar_apply_breathe() cycle=0 分支 | — | — | — | — | — | — | ✅ |
| 未初始化保护 (initialized=false) | ⚠️ | ⚠️ | ⚠️ | — | — | — | — |

> ⚠️ `initialized=false` 分支：`dotstar_init()` 在 `jna_panda_init()` 中自动调用，每个场景启动即完成初始化。未初始化保护路径（`fill`/`set_pixel`/`show`/`apply_breathe` 的 `return`）在 e2e 环境中被 `initialized=true` 覆盖，这些 `return` 语句属于防御性代码，生产固件 `body_main()` 在 `dotstar_init()` 之后再无路径可将 `initialized` 设回 false。

## 6. 与生产固件的关系

在生产固件 `board/body/main.c` 第 116 行之后，LED 动画由 `body_main()` 的 while 循环分支驱动：
```c
void body_main(void) {
  // ... 硬件初始化 ...
  body_can_init();        // ← line 115
  dotstar_init();         // ← line 116
  bldc_init();            // ← line 117
  while (true) {
    if (plug_charging) {
      dotstar_apply_breathe(...);   // 橙色呼吸
    } else if (ignition) {
      dotstar_run_rainbow(now);     // 彩虹动画
    } else {
      dotstar_apply_breathe(...);   // 绿色呼吸
    }
    dotstar_show();
  }
}
```

e2e 环境：`jna_panda_init()` 模拟固件启动，按 `body_can_init()` → `dotstar_init()` → `bldc_init()` 顺序执行（与生产固件顺序一致）。`dotstar_run_rainbow()` 和 `dotstar_apply_breathe()` 通过独立 JNA 入口直接调用，等价模拟主循环中的 LED 动画更新；`body_main.feature` 当前只覆盖中断路径，还未直接驱动这些 while-loop 分支。

## 覆盖率

> 数据来源: `run_all_coverage.sh` 合并报告 (cuatro + tres + red + body)
> body 固件覆盖率通过 `libpanda_body.dylib` 独立采集

| 源文件 | 说明 |
|--------|------|
| `board/body/dotstar.h` | 90.97% (141/155) | ✅ B10+B11+B12: dotstar_init() + dotstar_fill() + dotstar_set_pixel() + dotstar_set_global_brightness() + dotstar_run_rainbow() + dotstar_apply_breathe() 高覆盖 |
