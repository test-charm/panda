# `fdcan_interrupt.feature` — FDCAN 中断驱动处理 (C3)

## 被测功能

`board/drivers/fdcan.h` 中 `process_can()` 和 `can_rx()` 的真实中断处理路径。

C3 完成后，`board/stm32h7/llfdcan.h` + `board/drivers/fdcan.h` 共 491 行真实代码直接编译，包括：
- `fdcan_request_init` / `fdcan_exit_init` — FDCAN 初始化/退出（CCE 自动清除）
- `llcan_set_speed` / `llcan_init` — 波特率和初始化配置
- `process_can` — TX 中断：从 `can_queues[]` pop → FDCAN 消息 RAM → TXBAR → echo 到 `can_rx_q`
- `can_rx` — RX 中断：从 FDCAN 消息 RAM 读取 → `can_rx_q`

## 场景

| # | 场景 | 验证点 |
|---|------|--------|
| 1 | `process_can` drains TX queue | `jna_can_send` → `process_can` → `TXBAR[0]=1`, `IR.TFE=0x800`, `rxQueue[0].returned=true` |
| 2 | 0xff guard | `process_can(255)` 无崩溃 + FDCAN 中断处理器已注册 |

## 验证方式

- `fdcanRegs[N].txbar` / `fdcanRegs[N].ir` — 寄存器位模式断言
- `rxQueue[N].returned` — `process_can` echo 确认
- `FDCAN interrupt handlers are registered` — `interrupts[]` 数组验证

## JNA 接口

| 函数 | 用途 |
|------|------|
| `jna_process_can(n)` | 手动触发 TX 中断 |
| `jna_can_rx(n)` | 手动触发 RX 中断 |
| `jna_get_fdcan_txfqs(n)` | 读取 TX FIFO 队列状态 |
| `jna_get_fdcan_txbar(n)` | 读取 TX Buffer Add Request |
| `jna_get_interrupt_handler(n)` | 验证中断处理器已注册 |
| `jna_get_interrupt_call_rate_max(n)` | 验证最大调用率 |

## `#ifdef E2E_TEST` 守卫

| 文件 | 行 | 用途 |
|------|-----|------|
| `llfdcan.h:32` | `#ifdef` | `fdcan_exit_init()` CCE 自动清除 |
| `llfdcan.h:194` | `#ifdef` | `llcan_init()` 指针安全 RAM 刷新 |
| `llfdcan_declarations.h:16` | `#ifndef` | `FDCAN_START_ADDRESS` 不覆盖 e2e 假地址 |
| `fdcan.h:3` | `#ifndef` | `cans[3]` 数组 |
| `fdcan.h:24` | `#ifdef` | 跳过 10Hz 速率限制 |
| `fdcan.h:63` | `#ifdef` | `process_can()` 指针安全 FIFO 访问 |
| `fdcan.h:140` | `#ifdef` | `can_rx()` 指针安全 FIFO 访问 |
