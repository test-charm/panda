# `fdcan_interrupt.feature` — FDCAN 中断驱动处理 (C3 + Phase J)

## 被测功能

`board/drivers/fdcan.h` 中 `process_can()` 和 `can_rx()` 的真实中断处理路径。

C3 完成后，`board/stm32h7/llfdcan.h` + `board/drivers/fdcan.h` 共 491 行真实代码直接编译。
Phase J: J3 (bad checksum error) + J4 (all 6 FDCAN IRQ wrapper handlers) 全覆盖。

## Phase E.4: `can_rx()` RX FIFO 全路径覆盖 ✅

注入假 FDCAN SRAM，模拟硬件中断触发 `can_rx()`，覆盖 7 个核心路径。

### 场景

| # | 场景 | 验证点 |
|---|------|--------|
| 1 | `process_can` drains TX queue | `jna_can_send` → `process_can` → `TXBAR[0]=1`, `IR.TFE=0x800`, `rxQueue[0].returned=true` |
| 2 | 0xff guard | `process_can(255)` 无崩溃 + FDCAN 中断处理器已注册 |
| 3 | **标准 CAN 帧** | `can_rx()` 读取 11-bit 帧 → `rxQueue[0]` |
| 4 | **扩展 CAN 帧** | 29-bit 地址 → `rxQueue[0].extended=true` |
| 5 | **CAN-FD 帧自动检测** | `canfd_frame=1` → `fd=true` + `canfdEnabled0=true` |
| 6 | **BRS 帧自动检测** | `brs_frame=1` → `fd=true` + `brsEnabled0=true` |
| 7 | **FIFO 满覆盖模式** | `F0F=1` → rx_fifo_idx 偏移 +1 + `totalRxLostCnt=1` |
| 8 | **CAN 转发** | `forwarding_bus=1` → `totalFwdCnt=1` |
| 9 | **IRQ 错误处理** | `PED\|PEA` → `update_can_health_pkt()` |
| 10 | **safety_rx_hook 拒绝** | TOYOTA 模式 → `safetyRxInvalid=1` |
| 11 | **J3: Bad checksum error** | `can_push_direct` (无 checksum) + `process_can` → `totalTxChecksumErrorCnt=1` ✅ |
| 12 | **J4: All FDCAN handlers** | `handle interrupt 19/21/20/22/159/160` → 6 个 static wrapper 全覆盖 ✅ |

### JNA 接口

| 函数 | 用途 |
|------|------|
| `jna_process_can(n)` | 手动触发 TX 中断 |
| `jna_can_rx(n)` | 手动触发 RX 中断 |
| `jna_fdcan_write_rx_fifo(...)` | 向假 FDCAN SRAM 注入 CAN 帧 |
| `jna_set_fdcan_rxf0s/ir(n, val)` | 设置 RXF0S/IR 寄存器 |
| `jna_can_push_direct(...)` | 推入队列 (跳过 can_set_checksum, 用于 J3) |
| `jna_handle_interrupt(irqn)` | 触发 IRQ handler (J4) |
| `jna_get_can_health_total_tx_checksum_error_cnt(bus)` | 读取 checksum 错误计数 (J3) |

### `#ifdef E2E_TEST` 守卫

| 文件 | 行 | 用途 |
|------|-----|------|
| `llfdcan.h:32` | `#ifdef` | `fdcan_exit_init()` CCE 自动清除 |
| `llfdcan.h:194` | `#ifdef` | `llcan_init()` 指针安全 RAM 刷新 |
| `llfdcan_declarations.h:16` | `#ifndef` | `FDCAN_START_ADDRESS` |
| `fdcan.h:3` | `#ifndef` | `cans[3]` 数组 |
| `fdcan.h:24` | `#ifdef` | 跳过 10Hz 速率限制 |
| `fdcan.h:63` | `#ifdef` | `process_can()` 指针安全 FIFO |
| `fdcan.h:140` | `#ifdef` | `can_rx()` 指针安全 FIFO |
| `fdcan.h:214` | `#ifdef` | `can_rx()` 手动清除 RXF0S |

## 覆盖率

> 数据来源: `run_all_coverage.sh` 合并报告
> 综合行覆盖率: **92.9%** (全量)

| 源文件 | 行覆盖 | 说明 |
|--------|--------|------|
| `board/drivers/fdcan.h` | **100%** (158/158) | ✅ Phase J: J3 + J4 全覆盖 |
| `board/stm32h7/llfdcan.h` | 85.1% (137/161) | timeout 路径不可覆盖 |

---

## 中断调用率读取 (0xc4)

> 合并自: `interrupt_rate.md` (第十三节 B6)

### 被测功能

`get_interrupt_rate(uint16_t interrupt_index)` — 返回注册中断处理器的调用率（4 字节 LE）

### 测试用例

| # | 场景 | 输入 | 验证点 |
|---|------|------|--------|
| 1 | 越界索引返回空 | request=0xc4, param1=200 | respBuffer.len=0 |
| 2 | 有效索引返回 LE 值 | interruptIndex=7, interruptCallRate=0x12345678 | resp_len=4, bytes=[0x78,0x56,0x34,0x12] |
| 3 | 零调用率返回全零 | interruptIndex=0, 未预设 | resp_len=4, bytes=[0,0,0,0] |
