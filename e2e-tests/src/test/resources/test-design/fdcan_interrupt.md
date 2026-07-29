# `fdcan_interrupt.feature` — FDCAN 中断驱动处理 (C3)

## 被测功能

`board/drivers/fdcan.h` 中 `process_can()` 和 `can_rx()` 的真实中断处理路径。

C3 完成后，`board/stm32h7/llfdcan.h` + `board/drivers/fdcan.h` 共 491 行真实代码直接编译，包括：
- `fdcan_request_init` / `fdcan_exit_init` — FDCAN 初始化/退出（CCE 自动清除）
- `llcan_set_speed` / `llcan_init` — 波特率和初始化配置
- `process_can` — TX 中断：从 `can_queues[]` pop → FDCAN 消息 RAM → TXBAR → echo 到 `can_rx_q`
- `can_rx` — RX 中断：从 FDCAN 消息 RAM 读取 → `can_rx_q`

## Phase E.4: `can_rx()` RX FIFO 全路径覆盖 ✅

注入假 FDCAN SRAM，模拟硬件中断触发 `can_rx()`，覆盖 7 个核心路径。

### 场景

| # | 场景 | 验证点 |
|---|------|--------|
| 1 | `process_can` drains TX queue | `jna_can_send` → `process_can` → `TXBAR[0]=1`, `IR.TFE=0x800`, `rxQueue[0].returned=true` |
| 2 | 0xff guard | `process_can(255)` 无崩溃 + FDCAN 中断处理器已注册 |
| 3 | **标准 CAN 帧** | `can_rx()` 读取 11-bit 帧 → `rxQueue[0]` (`returned=false`, `rejected=false`, `bus=0`) + `totalRxCnt=1` |
| 4 | **扩展 CAN 帧** | 29-bit 地址 `0x12345678` → `rxQueue[0].extended=true` + `totalRxCnt=1` |
| 5 | **CAN-FD 帧自动检测** | `canfd_frame=1` → `rxQueue[0].fd=true` + `busConfigCanfdEnabled0=true` + `brsEnabled0=false` |
| 6 | **BRS 帧自动检测** | `brs_frame=1` → `rxQueue[0].fd=true` + `busConfigCanfdEnabled0=true` + `brsEnabled0=true` |
| 7 | **FIFO 满覆盖模式** | `F0F=1` → rx_fifo_idx 偏移 +1 (`RXF0A=1`) + `totalRxLostCnt=1` |
| 8 | **CAN 转发** | `forwarding_bus=1` → `totalFwdCnt=1` + `can_send` → `process_can(1)` |
| 9 | **IRQ 错误处理** | `PED\|PEA` → `update_can_health_pkt()` |
| 10 | **safety_rx_hook 拒绝** | TOYOTA 模式 + 0x260 帧(panda XOR ≠ Toyota sum) → `safetyRxInvalid=1` |

### 验证方式

- `rxQueue[N]` — `can_rx_q` 中的 `CANPacket_t` 字段（address, bus, data, returned, rejected, extended, fd）
- `canHealth0.totalRxCnt/totalRxLostCnt/totalFwdCnt` — `can_health[]` 计数器
- `canfdEnabled0/brsEnabled0` — `bus_config[].canfd_enabled/brs_enabled` 自动检测标志
- `fdcanRxf0aBus0` — `RXF0A` 寄存器确认 FIFO 满时索引偏移
- `directSafetyRxInvalid` — 安全模型 RX 校验失败计数
- `fdcanRegs[N].txbar` / `fdcanRegs[N].ir` — 寄存器位模式断言（原有）
- `FDCAN interrupt handlers are registered` — `interrupts[]` 数组验证（原有）

### JNA 接口

| 函数 | 用途 |
|------|------|
| `jna_process_can(n)` | 手动触发 TX 中断（原有） |
| `jna_can_rx(n)` | 手动触发 RX 中断（原有） |
| `jna_fdcan_write_rx_fifo(n, idx, ext, addr, fd, brs, dlc, data)` | 向假 FDCAN SRAM 注入 CAN 帧 |
| `jna_set_fdcan_rxf0s(n, val)` | 设置 `RXF0S` 寄存器（F0FL/F0F/F0GI） |
| `jna_set_fdcan_ir(n, val)` | 设置 `IR` 寄存器（RF0N / PED/PEA/EP/BO/RF0L） |
| `jna_get_fdcan_rxf0s(n)` / `jna_get_fdcan_rxf0a(n)` | 读取 RX FIFO 状态/确认寄存器 |
| `jna_get_can_health_total_rx_cnt(bus)` / `_fwd_cnt(bus)` | 读取 `can_health[].total_rx_cnt/total_fwd_cnt` |
| `jna_get_direct_safety_rx_invalid()` / `jna_get_direct_rx_buffer_overflow()` | 读取 `safety_rx_invalid` / `rx_buffer_overflow` |
| `jna_set_bus_forwarding_bus(bus, fwd)` / `jna_reset_bus_config()` | 设置/重置 `bus_config[]` |
| `jna_get_bus_config_canfd_enabled(bus)` / `_brs_enabled(bus)` | 读取 `bus_config[].canfd_enabled/brs_enabled` |
| `jna_get_fdcan_*(n)` 系列 | FDCAN 寄存器检查（原有 12 个） |

### `#ifdef E2E_TEST` 守卫

| 文件 | 行 | 用途 |
|------|-----|------|
| `llfdcan.h:32` | `#ifdef` | `fdcan_exit_init()` CCE 自动清除（C3） |
| `llfdcan.h:194` | `#ifdef` | `llcan_init()` 指针安全 RAM 刷新（C3） |
| `llfdcan_declarations.h:16` | `#ifndef` | `FDCAN_START_ADDRESS` 不覆盖 e2e 假地址（C3） |
| `fdcan.h:3` | `#ifndef` | `cans[3]` 数组（C3） |
| `fdcan.h:24` | `#ifdef` | 跳过 10Hz 速率限制（C3） |
| `fdcan.h:63` | `#ifdef` | `process_can()` 指针安全 FIFO 访问（C3） |
| `fdcan.h:140` | `#ifdef` | `can_rx()` 指针安全 FIFO 访问（C3） |
| `fdcan.h:214` | `#ifdef` | **`can_rx()` 手动清除 RXF0S 防止死循环**（E.4 新增） |

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
