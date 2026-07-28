# SOM GPIO 读取 — 测试设计文档

> 功能: read SOM GPIO via `comms_control_handler()` in `board/main_comms.h`
> 被测接口: USB control request 0xc6 (DEBUG: read SOM GPIO)

## 1. 被测功能流程图

```
read SOM GPIO (0xc6):
  [controlWrite(0xc6, 0, 0)]
           │
           ▼
  resp[0] = current_board->read_som_gpio()
  resp_len = 1
           │
           ▼
        (done)
```

代码路径为直线，无分支。`param1` 和 `param2` 未使用。

## 2. 输入因子

| 因子 | 类型 | 等价类 | 取值 |
|------|------|--------|------|
| `request` | uint8 | 0xc6 (唯一) | 0xc6 |
| `som_gpio_value` (前置) | bool | true (1), false (0) | 1 |

## 3. 输出因子

| 输出 | 类型 | 说明 |
|------|------|------|
| respBuffer.len | int | resp_len = 1 |
| respBuffer.bytes[0] | byte | GPIO 值 (0 或 1) |

## 4. 测试用例

### TC1 (@cuatro @tres): 预设 SOM GPIO=1 → resp buffer 返回 1
- 前置: `somGpio: 1` (e2e 注入)
- 输入: request=0xc6
- 输出: respBuffer.len=1, bytes=[1y]

### TC2 (@red): 预设 SOM GPIO=1 → resp buffer 返回 0 (unused)
- 前置: `somGpio: 1` + red board (`.read_som_gpio = unused_read_som_gpio`)
- 输入: request=0xc6
- 输出: respBuffer.len=1, bytes=[0y]
- 说明: `unused_read_som_gpio` 始终返回 false，覆盖 e2e 注入值

## 5. 覆盖检查

| 条件 | TC1 | TC2 (@red) |
|------|-----|------------|
| request == 0xc6, 有 SOM GPIO 硬件 | ✅ | — |
| request == 0xc6, 无 SOM GPIO (unused) | — | ✅ |

✅ 所有代码路径 + `unused_read_som_gpio` 已覆盖。

## 覆盖率

> 数据来源: `run_all_coverage.sh` 合并报告 (cuatro + tres + red)
> 综合行覆盖率: **78.9%** (全量), 本功能涉及以下源文件:

| 源文件 | 行覆盖 | 说明 |
|--------|--------|------|
| `main_comms.h` | 95.5% (257/269) | USB 命令处理 |
| `unused_funcs.h` | 100% (23/23) | ✅ Phase D.2 |

