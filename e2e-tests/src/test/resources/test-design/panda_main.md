# Panda Main 测试设计

> 最后更新: 2026-08-06 (B22-PANDA: main() init + 循环体 5 分支全覆盖)
> Feature 文件: `panda_main.feature` (5 场景)
> 覆盖文件: `board/main.c`, `board/sys/critical.h`

## 一、被测代码

### 1.1 `main()` 函数 (`board/main.c:270-397`)

生产固件中 `while(true)` 无限循环，e2e 构建中替换为 `do { ... } while(false)`。

初始化序列 (lines 270-340): 中断表 → 时钟 → 板检测 → LED → ADC → 板 init → FPU → 定时器 → 安全模式 → CAN → 看门狗 → SPI → USB → 中断使能

循环体 (lines 343-389): 5 条分支路径

```
do {
  #ifdef ALLOW_DEBUG
  if (stop_mode_requested) → enter_stop_mode()          // 分支 1: STOP
  #endif

  if (!power_save_enabled) {
    LED fade loop                                        // 分支 2: FADE
  } else {
    if (SOM offline && CUATRO) {
      assert_fatal(SILENT) → enter_stop_mode()           // 分支 3: DEEPSLEEP
      assert_fatal(false)                                // #ifndef E2E_TEST 排除
    }
    __WFI() + SLEEPDEEP clear                            // 分支 4: WFI
  }
} while (false);                                         // 分支 5: default (setUp)
```

### 1.2 生产代码修改 (`#ifdef E2E_TEST`)

| 行 | 守卫 | 用途 |
|----|------|------|
| 343 | `#ifdef` | `while(true)` → `do {` |
| 384 | `#ifndef` | 排除 `assert_fatal(false)` — 真实硬件不可达 |
| 390 | `#ifdef` | `}` → `} while(false)` |

## 二、输入因子

| 因子 | JNA 入口 | 等价类 |
|------|---------|--------|
| `power_save_enabled` | `jna_set_power_save_enabled()` | false, true |
| `stop_mode_requested` | `jna_set_stop_mode_requested()` | false, true |
| `read_som_gpio()` | `jna_set_som_gpio()` | true (online), false (offline) |

## 三、输出因子

| 因子 | 观测方式 |
|------|---------|
| `faultStatus` | DAL property |
| `fpuEnabled` | SCB CPACR → `getFpuEnabled()` |
| `harnessStatus` | DAL property |
| `wfiEntered` | `stopModeRegs.wfiEntered` |
| `nvicResetCount` | `enter_stop_mode()` → stub 计数 |

## 四、测试用例

### B22-PANDA-INIT — init 序列验证

| 验证项 | 预期值 | 说明 |
|--------|--------|------|
| `faultStatus` | 0 | 初始化无故障 |
| `fpuEnabled` | 15728640 (0x00F00000) | `enable_fpu()` 使能 CP10+CP11 |
| `harnessStatus` | 0 (HARNESS_STATUS_NC) | `harness_init()` 成功 |

### B22-PANDA-FADE — LED fade loop

| 输入 | 覆盖行 |
|------|--------|
| `power_save_enabled` = false | 358-370 |

### B22-PANDA-WFI — __WFI 路径

| 输入 | 覆盖行 | 验证 |
|------|--------|------|
| `power_save_enabled` = true, SOM online | 387-388 | `wfiEntered: true` |

### B22-PANDA-STOP — stop_mode 分支

| 输入 | 覆盖行 | 验证 |
|------|--------|------|
| `stop_mode_requested` = true | 350 | `nvicResetCount: 1` |

### B22-PANDA-DEEPSLEEP — deep sleep 路径

| 输入 | 覆盖行 | 验证 |
|------|--------|------|
| `power_save_enabled` = true, SOM offline | 382-383 | `nvicResetCount: 1` |

## 五、完备性验证

- [x] 循环体 5 条分支全部 ≥1 用例
- [x] `#ifdef ALLOW_DEBUG` 内 `stop_mode_requested` 条件覆盖
- [x] `#ifdef DEBUG_FAULTS` 外 fade 路径覆盖 (e2e 未定义)
- [x] `power_save_enabled` 双分支各 ≥1 用例
- [x] `read_som_gpio()` 双分支各 ≥1 用例
- [x] `assert_fatal(safety==SILENT)` 通过
- [x] `assert_fatal(false)` 通过 `#ifndef E2E_TEST` 排除

## 六、实现架构

```
libpanda.c (文件末尾):
  jna_get_reg_SCB_CPACR()         — SCB CPACR 读取
  jna_set_power_save_enabled()    — power_save_enabled 直接设置
  jna_set_stop_mode_requested()   — stop_mode_requested 直接设置
  jna_panda_main()                — 调用 panda_main()

board/main.c:
  #ifdef E2E_TEST  do {           ← 替换 while(true)
  #ifndef E2E_TEST                ← 排除 assert_fatal(false)
  #ifdef E2E_TEST  } while(false) ← 循环体单次执行
```
