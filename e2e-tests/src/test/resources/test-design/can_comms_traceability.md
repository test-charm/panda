# `board/can_comms.h` 行级测试覆盖矩阵

> 生成时间: 2026-07-28 (Phase D.3 完成)  
> 数据来源: `e2e-tests/build/coverage/merged.lcov` (cuatro+tres+red 合并)  
> 综合行覆盖率: **100%** (76/76), 函数覆盖率: **100%** (4/4)

## 场景对照表

| 缩写 | 场景 | Feature 文件 |
|------|------|-------------|
| S1 | Classic CAN 8-byte — USB ep3 out → rxQueue | `can_comms.feature:13` |
| S2 | CAN FD 64-byte — USB ep3 out → rxQueue | `can_comms.feature:32` |
| S3 | Multi-frame batch — USB ep3 out ×2 | `can_comms.feature:51` |
| S4 | Rejected frame — USB ep1 in 读取 | `can_comms.feature:80` |
| S5 | Read overflow — 单帧分片 (max_len=5 → 读 + max_len=64 → 续读) | `can_comms.feature:101` |
| S6 | Read overflow — 两帧分片 (max_len=17 → 帧1 + 帧2 partial) | `can_comms.feature:128` |
| S7 | Write overflow — 分片完成 (5 + 9 bytes) | `can_comms.feature:155` |
| S8 | Write overflow — 两段补充 (5 + 3 + 6 bytes) | `can_comms.feature:194` |
| S9 | Write overflow — 多帧尾部 (14+14 + 5 / 9 bytes) | `can_comms.feature:245` |

测试步骤统一使用 USB endpoint 语义:
- `When USB ep3 out with hex:` → `usb_sim_ep3_out()` → `comms_can_write()`
- `When USB ep1 in with max len {int}` → `usb_sim_ep1_in()` → `comms_can_read()`

## `comms_can_read()` — lines 45-76

| 行 | 代码 | 执行次数 | 覆盖场景 | 说明 |
|----|------|---------|---------|------|
| 45 | `int comms_can_read(...)` | 4+ | S4,S5×2,S6×2 | |
| 46 | `uint32_t pos = 0U;` | 4+ | S4,S5×2,S6×2 | |
| 49 | `if (can_read_buffer.ptr > 0U)` | 2 (true) + 2 (false) | S4 走 false; **S5-2nd,S6-2nd** 走 true | read buffer overflow 路径 ✅ |
| 50 | `uint32_t overflow_len = MIN(...)` | 2 | **S5-2nd,S6-2nd** | 计算溢出复制量 |
| 51 | `(void)memcpy(&data[pos], ...)` | 2 | **S5-2nd,S6-2nd** | 从 overflow buffer 复制 |
| 52 | `pos += overflow_len;` | 2 | **S5-2nd,S6-2nd** | |
| 53 | `(void)memcpy(can_read_buffer.data, ...)` | 2 | **S5-2nd,S6-2nd** | 移位剩余数据 |
| 54 | `can_read_buffer.ptr -= overflow_len;` | 2 | **S5-2nd,S6-2nd** | |
| 57 | `if (can_read_buffer.ptr == 0U)` | 2 (true) + 2 (false) | S4,S6-2nd 走 true; **S5-2nd** 走 false | |
| 59 | `CANPacket_t can_packet;` | 1 | S4 | |
| 60 | `while ((pos < max_len) && can_pop(...))` | 1 (true) + 1 (false) | S4 | |
| 61 | `uint32_t pckt_len = ...` | 1 | S4 | |
| 62 | `if ((pos + pckt_len) <= max_len)` | 1 (true) + 2 (false) | S4 走 true; **S5-1st,S6-1st** 走 false | overflow 路径 ✅ |
| 63 | `(void)memcpy(&data[pos], ...)` | 1 | S4 | |
| 64 | `pos += pckt_len;` | 1 | S4 | |
| 65 | `} else {` | 2 | **S5-1st,S6-1st** | 帧超 max_len |
| 66 | `(void)memcpy(&data[pos], ...)` | 2 | **S5-1st,S6-1st** | 部分复制 |
| 67 | `can_read_buffer.ptr += ...` | 2 | **S5-1st,S6-1st** | |
| 69 | `(void)memcpy(can_read_buffer.data, ...)` | 2 | **S5-1st,S6-1st** | 剩余存入 buffer |
| 70 | `pos = max_len;` | 2 | **S5-1st,S6-1st** | |
| 72 | `}` (end while) | 1 | S4 | |
| 73 | `}` (end if) | 2 | S6-2nd, S5-2nd | |
| 75 | `return pos;` | 4+ | S4,S5×2,S6×2 | |
| 76 | `}` | 4+ | S4,S5×2,S6×2 | |

## `comms_can_write()` — lines 81-127

| 行 | 代码 | 执行次数 | 覆盖场景 | 说明 |
|----|------|---------|---------|------|
| 81 | `void comms_can_write(...)` | 9+ | S1,S2,S3×2,S7×2,S8×3,S9×2 | |
| 82 | `uint32_t pos = 0U;` | 9+ | 全场景 | |
| 85 | `if (can_write_buffer.ptr != 0U)` | 3 (true) + 6 (false) | **S7-2nd,S8-2nd,S9-2nd** 走 true | |
| 86 | `if (can_write_buffer.tail_size <= ...)` | 2 (true) + 1 (false) | S7-2nd,S9-2nd 走 true; **S8-2nd** 走 false | 不足分支 ✅ |
| 88-99 | 完成组装 → can_send | 2 | **S7-2nd,S9-2nd** | 拼接 + 发送 |
| 100-107 | 追加到 buffer | 1 | **S8-2nd** | data_size=3, ptr=8, tail=6 ✅ |
| 111 | `while (pos < len)` | 7+ | 全场景 | |
| 112 | `uint32_t pckt_len = ...` | 7+ | 全场景 | |
| 113 | `if ((pos + pckt_len) <= len)` | 4 (true) + 3 (false) | S1,S2,S3×2 走 true; **S7-1st,S8-1st,S9-1st** 走 false | overflow 路径 ✅ |
| 114-117 | 完整帧 → can_send | 4 | S1,S2,S3×2 | |
| 118-123 | 部分帧 → write buffer | 3 | **S7-1st,S8-1st,S9-1st** | ptr/tail 记录 ✅ |
| 126 | `refresh_can_tx_slots_available();` | 9+ | 全场景 | |
| 127 | `}` | 9+ | 全场景 | |

## `comms_can_reset()` — lines 129-134

| 行 | 代码 | 执行次数 | 覆盖场景 | 说明 |
|----|------|---------|---------|------|
| 129 | `void comms_can_reset(void)` | 1+ | init + `can_comms_reset.feature` | |
| 130-133 | 清空 4 个缓冲区字段 | 1+ | init + reset | |
| 134 | `}` | 1+ | init + reset | |

## `refresh_can_tx_slots_available()` — lines 137-144

| 行 | 代码 | 执行次数 | 覆盖场景 | 说明 |
|----|------|---------|---------|------|
| 137 | `void refresh_can_tx_slots_available()` | 700+ | 全场景 + heartbeat/tick | |
| 138 | `if (can_tx_check_min_slots_free(USB))` | 700+ (true) | 队列始终有空位 | |
| 139 | `can_tx_comms_resume_usb();` | 700+ | | |
| 141 | `if (can_tx_check_min_slots_free(SPI))` | 700+ (true) | | |
| 142 | `can_tx_comms_resume_spi();` | 700+ | | |
| 144 | `}` | 700+ | | |
