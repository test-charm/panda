# UART Ring Buffer Overwrite — 测试设计文档

> **✅ 新建 feature**: Phase J 新增，覆盖 `board/drivers/uart.h` 中 `put_char` (TX) 和 `injectc` (RX) 的 overwrite 模式。
> 被测接口: JNA 直接调用 `put_char()` + `injectc()`

## 1. 被测功能流程图

```
J5: put_char / injectc with overwrite=true, fifo_size=4, 5 bytes:

  写入 byte 1→3: w_ptr++ (正常写入)
  写入 byte 4:   next_w 绕回 = 0 == r_ptr(0) → overwrite → r_ptr=1
  写入 byte 5:   next_w=1 == r_ptr(1) → overwrite → r_ptr=2

  结果: r_ptr = 2 (丢弃了 2 个最旧字节)
```

## 2. 输入因子

| 因子 | 类型 | 等价类 | 取值 |
|------|------|--------|------|
| `fifo_size` | int | 4 | 4 |
| `overwrite` | bool | true | true |
| `写入字节数` | int | > fifo_size | 5 |
| `函数` | — | put_char (TX), injectc (RX) | 两者 |

## 3. 输出因子

| 输出 | 类型 | 说明 |
|------|------|------|
| `uartTxRPtr` | int | TX ring buffer r_ptr (2 = 2 次 overwrite) |
| `uartRxRPtr` | int | RX ring buffer r_ptr (2 = 2 次 overwrite) |
| `readFaults` | int | 故障位掩码 (0 = no fault) |

## 4. 测试用例

### TC1 (J5): put_char overwrite 前进 TX r_ptr
- 前置: `uart_overwrite_init(4)` (overwrite=true)
- 输入: `put_char` × 5 (hex: 4142434445 = "ABCDE")
- 输出: uartTxRPtr=2, readFaults=0
- 路径: uart.h:93-94 (r_ptr_tx 前移)

### TC2 (J5): injectc overwrite 前进 RX r_ptr
- 前置: `uart_overwrite_init(4)` (overwrite=true)
- 输入: `injectc` × 5 (hex: 58595A5B5C = "XYZ[\\")
- 输出: uartRxRPtr=2, readFaults=0
- 路径: uart.h:71-72 (r_ptr_rx 前移)

## 5. 覆盖检查

| 代码路径 | TC1 | TC2 |
|---------|:--:|:--:|
| put_char overwrite (r_ptr_tx) | ✅ | — |
| injectc overwrite (r_ptr_rx) | — | ✅ |
| overwrite=true + buffer full | ✅ | ✅ |

✅ 所有 TX/RX overwrite 路径已覆盖。

## 覆盖率

> 数据来源: `run_all_coverage.sh` 合并报告
> 综合行覆盖率: **92.9%** (全量)

| 源文件 | 行覆盖 | 说明 |
|--------|--------|------|
| `board/drivers/uart.h` | **100%** (77/77) | ✅ J5: put_char + injectc overwrite 全覆盖 |
