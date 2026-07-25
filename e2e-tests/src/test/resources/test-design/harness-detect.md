# 线束翻转检测 — 测试设计文档

> 功能: `harness_detect_orientation()` in `board/drivers/harness.h:52-88`
> 被测路径: `jna_detect_harness_orientation()` → `harness_detect_orientation()` (生产代码逐字)
> 调用: `harness_tick()` → `harness.status = harness_detect_orientation()` (8Hz, main.c:130)

## 1. 被测功能数据流

```
jna_set_sbu1_voltage_mV() ──→ harness.sbu1_voltage_mV
jna_set_sbu2_voltage_mV() ──→ harness.sbu2_voltage_mV
jna_set_relay_driven()    ──→ harness.relay_driven

harness_detect_orientation()                                  ← 生产代码(逐字)
    │  ret = harness.status (relay 驱动时保留)
    │  if (!relay_driven):
    │    sbu_adc_lock = true
    │    set_gpio_mode(SBU1, MODE_ANALOG)                     ← GPIO 桩
    │    set_gpio_mode(SBU2, MODE_ANALOG)
    │    sbu1 = adc_get_mV(&adc_signal_SBU1)                  ← lladc.h 桩拦截
    │    sbu2 = adc_get_mV(&adc_signal_SBU2)
    │    threshold = avdd_mV / 2                              ← 1800/2 = 900 (cuatro)
    │    if (sbu1 < threshold || sbu2 < threshold):           ← 有 harness 连接
    │      if (sbu1 < sbu2) → FLIPPED (2)                     ← 翻转方向
    │      else → NORMAL (1)                                   ← 正向
    │    else → NC (0)                                         ← 无连接
    │    set_gpio_mode(SBU1, MODE_INPUT)                      ← 恢复 GPIO
    │    set_gpio_mode(SBU2, MODE_INPUT)
    │    sbu_adc_lock = false
    ▼
harness.status    ← NORMAL(1) / FLIPPED(2) / NC(0)
```

## 2. 关键常量

| 常量 | 值 | 含义 |
|------|----|------|
| `HARNESS_STATUS_NC` | 0 | 无线束连接 |
| `HARNESS_STATUS_NORMAL` | 1 | 正向 (SBU1 ≥ SBU2, 至少一侧低于阈值) |
| `HARNESS_STATUS_FLIPPED` | 2 | 翻转 (SBU1 < SBU2, 至少一侧低于阈值) |
| `avdd_mV` (cuatro/tres) | 1800 | 模拟参考电压 → 阈值 = 900mV |
| `avdd_mV` (red) | 3300 | 模拟参考电压 → 阈值 = 1650mV |

## 3. e2e 注入机制

生产代码 `harness_detect_orientation()` 在构建时由 `generate_harness_stubs.py` 从 `board/drivers/harness.h:52-88` 逐字提取到 `harness_detect_e2e.gen.c`。

`adc_get_mV()` 调用被 e2e `board/stm32h7/lladc.h` 桩拦截：按 ADC 通道号 (ch=4 → SBU1, ch=17 → SBU2) 返回预置的 `harness.sbu*_voltage_mV` 值，绕过真实 ADC 寄存器。

JNA 入口 `jna_detect_harness_orientation()` 调用生产代码并更新 `harness.status`。

## 4. 输入因子

| 因子 | 类型 | 等价类 | 说明 |
|------|------|--------|------|
| sbu1VoltageMV | int | <900 (低), ≥900 (高), 0 (边界) | SBU1 模拟电压 |
| sbu2VoltageMV | int | <900 (低), ≥900 (高), 0 (边界) | SBU2 模拟电压 |
| relayDriven | int | 0 (释放), 1 (驱动) | 继电器驱动状态 |
| harnessStatus | int | 0, 1, 2 | relay 驱动时的初始状态 |

## 5. 输出因子

| 输出 | 类型 | 说明 |
|------|------|------|
| `harnessStatus` | int | 线束状态: 0=NC, 1=NORMAL, 2=FLIPPED |

## 6. 测试用例

### TC1: 正向 — 两侧低于阈值, SBU1 > SBU2
- 前置: SBU1=700, SBU2=200
- 执行: detect harness orientation
- 预期: harnessStatus=1 (NORMAL)
- 路径: sbu1 ≥ sbu2, threshold 比较 → NORMAL
- 场景: `harness_detect.feature:13`

### TC2: 翻转 — 两侧低于阈值, SBU1 < SBU2
- 前置: SBU1=200, SBU2=700
- 执行: detect harness orientation
- 预期: harnessStatus=2 (FLIPPED)
- 路径: sbu1 < sbu2, threshold 比较 → FLIPPED
- 场景: `harness_detect.feature:27`

### TC3: 未连接 — 两侧高于阈值
- 前置: SBU1=1500, SBU2=1500
- 执行: detect harness orientation
- 预期: harnessStatus=0 (NC)
- 路径: 两侧 ≥ threshold → NC
- 场景: `harness_detect.feature:41`

### TC4: 单侧低电压 (SBU1 低) — 翻转
- 前置: SBU1=200, SBU2=1500
- 执行: detect harness orientation
- 预期: harnessStatus=2 (FLIPPED)
- 路径: sbu1 < threshold (短路过 sbu2), sbu1 < sbu2 → FLIPPED
- 场景: `harness_detect.feature:55`

### TC5: 单侧低电压 (SBU2 低) — 正向
- 前置: SBU1=1500, SBU2=200
- 执行: detect harness orientation
- 预期: harnessStatus=1 (NORMAL)
- 路径: sbu2 < threshold, sbu1 ≥ sbu2 → NORMAL
- 场景: `harness_detect.feature:69`

### TC6: 等电压低于阈值 — 默认正向
- 前置: SBU1=500, SBU2=500
- 执行: detect harness orientation
- 预期: harnessStatus=1 (NORMAL)
- 路径: 两侧 < threshold, sbu1 ≥ sbu2 (相等) → NORMAL
- 场景: `harness_detect.feature:83`

### TC7: relay 驱动 — 跳过检测, 保留状态
- 前置: harnessStatus=0, SBU1=200, SBU2=700, relayDriven=1
- 执行: detect harness orientation
- 预期: harnessStatus=0 (保留 NC)
- 路径: relay_driven=true → 提前返回 ret=harness.status
- 场景: `harness_detect.feature:97`

### TC8: relay 释放 — 恢复检测
- 前置: relayDriven=1 → 调用 → relayDriven=0 → 调用
- 执行: 两次 detect harness orientation
- 预期: 第一次 NC(保留) → 第二次 FLIPPED(2)
- 路径: relay 释放 → 重新进入检测分支 → 检测到翻转
- 场景: `harness_detect.feature:113`

## 7. 覆盖检查

| 条件 | TC1 | TC2 | TC3 | TC4 | TC5 | TC6 | TC7 | TC8 |
|------|-----|-----|-----|-----|-----|-----|-----|-----|
| `!relay_driven` (进入检测) | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | — | ✅ |
| `relay_driven` (跳过检测) | — | — | — | — | — | — | ✅ | — |
| `sbu1 < thr \|\| sbu2 < thr` (True) | ✅ | ✅ | — | ✅ | ✅ | ✅ | — | ✅ |
| `sbu1 < thr \|\| sbu2 < thr` (False) | — | — | ✅ | — | — | — | — | — |
| `sbu1 < thr` 短路 (不检查 sbu2) | — | — | — | ✅ | — | — | — | — |
| `sbu1 < sbu2` (True → FLIPPED) | — | ✅ | — | ✅ | — | — | — | ✅ |
| `sbu1 < sbu2` (False → NORMAL) | ✅ | — | — | — | ✅ | ✅ | — | — |
| `ret = NC` | — | — | ✅ | — | — | — | — | — |
| `ret = NORMAL` | ✅ | — | — | — | ✅ | ✅ | — | — |
| `ret = FLIPPED` | — | ✅ | — | ✅ | — | — | — | ✅ |
| relay 状态切换 | — | — | — | — | — | — | — | ✅ |

✅ 全部 6 个决策分支、3 个返回值、短路求值、relay 旁路均已覆盖。

## 8. 架构

```
board/drivers/harness.h:52-88  (生产代码)
        │  generate_harness_stubs.py (构建时自动提取)
        ▼
harness_detect_e2e.gen.c        (逐字复制 + JNA 包装)
        │  #include into libpanda.c
        ▼
libpanda_cuatro.dylib
        │  JNA
        ▼
PandaClient.java                (detectHarnessOrientation)
        │
        ▼
harness_detect.feature           (8 个 BDD 场景)
```

ADC 拦截:
```
adc_get_mV(&adc_signal_SBU1)
        │
        ▼  e2e board/stm32h7/lladc.h (桩)
   if ch==4  → harness.sbu1_voltage_mV
   if ch==17 → harness.sbu2_voltage_mV
   else      → 0
```

## 覆盖率

> 数据来源: `run_all_coverage.sh` 合并报告

| 被测行 | 源文件 | 说明 |
|--------|--------|------|
| `harness.h:52-88` | 生产 `board/drivers/harness.h` | `harness_detect_orientation()` 完整函数，决策分支 100% 覆盖 |
