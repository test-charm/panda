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

> 注: 警笛启用后通过 `tick_handler()` (8Hz) 将 `siren_enabled` 标志应用到 GPIO 输出。e2e 使用 `When call tick handler 8 times` 触发 siren tick。

## 4. 测试用例

### TC1: 禁用警笛 (param1=0)
- 前置: 初始状态 (siren_enabled=false)
- 输入: request=0xf6, param1=0
- 操作: tick siren
- 输出: stopModeRegs.gpioBOdr=0L (PB14 low)

### TC2: 启用警笛 (param1=1)
- 前置: 初始状态
- 输入: request=0xf6, param1=1
- 操作: tick siren
- 输出: stopModeRegs.gpioBOdr=16384L (PB14 high)

### TC3: 任意非零值均启用警笛 (param1=255)
- 前置: 初始状态
- 输入: request=0xf6, param1=255
- 操作: tick siren
- 输出: stopModeRegs.gpioBOdr=16384L (PB14 high)

### TC4 (@red): unused_set_siren 在 tick handler 中无副作用
- 前置: red board (`.set_siren = unused_set_siren`)
- 操作: call tick handler 8 times
- 输出: safetyState.sirenWasActive: 0
- 说明: `unused_set_siren` 不设置 `siren_was_active` 标志，与其他 board 在 heartbeat_loss 时 sirenWasActive=1 形成对比

## 5. 覆盖检查

| 条件 | TC1 | TC2 | TC3 | TC4 (@red) |
|------|-----|-----|-----|------------|
| param1 == 0 | ✅ | — | — | — |
| param1 != 0 | — | ✅ | ✅ | — |
| unused_set_siren (tick 路径) | — | — | — | ✅ |

✅ 所有等价类 + `unused_set_siren` tick handler 路径已覆盖。

## 覆盖率

> 数据来源: `run_all_coverage.sh` 合并报告 (cuatro + tres + red)
> 综合行覆盖率: **78.9%** (全量), 本功能涉及以下源文件:

| 源文件 | 行覆盖 | 说明 |
|--------|--------|------|
| `main_comms.h` | 95.5% (257/269) | USB 命令处理 |
| `main.c` | 64.2% (145/226) | 主循环 + 初始化 |
| `unused_funcs.h` | 100% (23/23) | ✅ Phase D.2 |

