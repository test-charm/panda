# `board/can_comms.h` 行级测试覆盖矩阵

> 生成时间: 2026-07-25  
> 数据来源: `e2e-tests/build/coverage/coverage.lcov` (cuatro+tres+red 合并)  
> 综合行覆盖率: **82.1%** (32/39), 函数覆盖率: **100%** (4/4)

## 场景对照表

| 缩写 | 场景 | Feature 文件 |
|------|------|-------------|
| S1 | Classic CAN 8-byte 反序列化 | `can_comms.feature:13` |
| S2 | CAN FD 64-byte 反序列化 | `can_comms.feature:27` |
| S3 | 跨块分片传输 (partial + completion) | `can_comms.feature:41` |
| S4 | 多帧批量序列化 (2 帧) | `can_comms.feature:69` |
| S5 | comms_can_read 序列化 (rejected 标志) | `can_comms.feature:91` |
| R1 | comms_can_reset 清空缓冲区 | `can_comms_reset.feature:4` |
| R2 | Reset 不影响 safety mode | `can_comms_reset.feature:25` |
| R3 | Reset 保留 ALLOUTPUT relay | `can_comms_reset.feature:50` |

## `comms_can_read()` — lines 45-76

| 行 | 代码 | 执行次数 | 覆盖场景 | 说明 |
|----|------|---------|---------|------|
| 45 | `int comms_can_read(...)` | 1 | **S5** | 函数入口 |
| 46 | `uint32_t pos = 0U;` | 1 | **S5** | |
| 49 | `if (can_read_buffer.ptr > 0U)` | 1 (false) | **S5** | read buffer 为空, 跳过 overflow 分支 |
| 50 | `uint32_t overflow_len = MIN(...)` | 0 | ❌ | 未覆盖: read buffer overflow 路径 |
| 51 | `(void)memcpy(&data[pos], ...)` | 0 | ❌ | |
| 52 | `pos += overflow_len;` | 0 | ❌ | |
| 53 | `(void)memcpy(can_read_buffer.data, ...)` | 0 | ❌ | |
| 54 | `can_read_buffer.ptr -= overflow_len;` | 0 | ❌ | |
| 57 | `if (can_read_buffer.ptr == 0U)` | 1 (true) | **S5** | 进入正常填充路径 |
| 59 | `CANPacket_t can_packet;` | 1 | **S5** | |
| 60 | `while ((pos < max_len) && can_pop(...))` | 1 (true) + 1 (false) | **S5** | 循环一次后退出 (队列只有 1 帧) |
| 61 | `uint32_t pckt_len = ... + dlc_to_len[...]` | 1 | **S5** | 计算 wire format 长度 |
| 62 | `if ((pos + pckt_len) <= max_len)` | 1 (true) | **S5** | 14 ≤ 64, 直接序列化 |
| 63 | `(void)memcpy(&data[pos], ...)` | 1 | **S5** | |
| 64 | `pos += pckt_len;` | 1 | **S5** | |
| 65 | `} else {` | 0 | ❌ | 未覆盖: read 跨块 overflow (max_len < 帧长) |
| 66 | `(void)memcpy(&data[pos], ...)` | 0 | ❌ | |
| 67 | `can_read_buffer.ptr += ...` | 0 | ❌ | |
| 69 | `(void)memcpy(can_read_buffer.data, ...)` | 0 | ❌ | |
| 70 | `pos = max_len;` | 0 | ❌ | |
| 72 | `}` (end while) | 1 | **S5** | |
| 73 | `}` (end if) | 1 | **S5** | |
| 75 | `return pos;` | 1 | **S5** | 返回 14 字节 |
| 76 | `}` | 1 | **S5** | |

## `comms_can_write()` — lines 81-127

| 行 | 代码 | 执行次数 | 覆盖场景 | 说明 |
|----|------|---------|---------|------|
| 81 | `void comms_can_write(...)` | 6 | **S1,S2,S3×2,S4×2** | |
| 82 | `uint32_t pos = 0U;` | 6 | **S1,S2,S3×2,S4×2** | |
| 85 | `if (can_write_buffer.ptr != 0U)` | 5 (false) + 1 (true) | S1,S2,S4 走 false; **S3-2nd** 走 true | |
| 86 | `if (can_write_buffer.tail_size <= ...)` | 1 (true) | **S3-2nd** | 4 ≤ 4, 足够完成 |
| 88 | `CANPacket_t to_push = {0};` | 1 | **S3-2nd** | |
| 89 | `(void)memcpy(&can_write_buffer.data[...])` | 1 | **S3-2nd** | 拼接剩余 4 字节 |
| 90 | `can_write_buffer.ptr += ...` | 1 | **S3-2nd** | ptr 10→14 |
| 91 | `pos += can_write_buffer.tail_size;` | 1 | **S3-2nd** | pos 0→4 |
| 94 | `(void)memcpy((uint8_t*)&to_push, ...)` | 1 | **S3-2nd** | 完整帧 → CANPacket_t |
| 95 | `can_send(&to_push, to_push.bus, false);` | 1 | **S3-2nd** | 发送 |
| 98 | `can_write_buffer.ptr = 0U;` | 1 | **S3-2nd** | 清空 |
| 99 | `can_write_buffer.tail_size = 0U;` | 1 | **S3-2nd** | 清空 |
| 100 | `} else {` (tail > remaining) | 0 | ❌ | 未覆盖: 跨块补充但仍不完整 |
| 102 | `uint32_t data_size = len - pos;` | 0 | ❌ | |
| 103 | `(void)memcpy(...)` | 0 | ❌ | |
| 104 | `can_write_buffer.tail_size -= ...` | 0 | ❌ | |
| 105 | `can_write_buffer.ptr += ...` | 0 | ❌ | |
| 106 | `pos += data_size;` | 0 | ❌ | |
| 108 | `}` (end if) | 1 | **S3-2nd** | |
| 111 | `while (pos < len)` | 5 (true) + 6 (false) | S1,S2,S4, **S3-1st**; S3-2nd 走 false | |
| 112 | `uint32_t pckt_len = ...` | 5 | S1,S2,S4, **S3-1st** | |
| 113 | `if ((pos + pckt_len) <= len)` | 4 (true) + 1 (false) | S1,S2,S4 走 true; **S3-1st** 走 false | |
| 114 | `CANPacket_t to_push = {0};` | 4 | S1,S2,S4 | 完整帧处理 |
| 115 | `(void)memcpy((uint8_t*)&to_push, ...)` | 4 | S1,S2,S4 | |
| 116 | `can_send(&to_push, ...)` | 4 | S1,S2,S4 | |
| 117 | `pos += pckt_len;` | 4 | S1,S2,S4 | |
| 118 | `} else {` (partial frame) | 1 | **S3-1st** | 帧不完整, 写入 overflow buffer |
| 119 | `(void)memcpy(can_write_buffer.data, ...)` | 1 | **S3-1st** | 写入 10 字节 |
| 120 | `can_write_buffer.ptr = len - pos;` | 1 | **S3-1st** | ptr = 10 |
| 121 | `can_write_buffer.tail_size = pckt_len - ptr;` | 1 | **S3-1st** | tail_size = 14 - 10 = 4 |
| 122 | `pos += can_write_buffer.ptr;` | 1 | **S3-1st** | pos 0→10 |
| 124 | `}` (end while) | 5 | S1,S2,S4, **S3-1st** | |
| 126 | `refresh_can_tx_slots_available();` | 6 | S1,S2,S3×2,S4×2 | 每次 write 后刷新 |
| 127 | `}` | 6 | S1,S2,S3×2,S4×2 | |

## `comms_can_reset()` — lines 129-134

| 行 | 代码 | 执行次数 | 覆盖场景 | 说明 |
|----|------|---------|---------|------|
| 129 | `void comms_can_reset(void)` | 3 | **R1,R2,R3** | |
| 130 | `can_write_buffer.ptr = 0U;` | 3 | **R1,R2,R3** | |
| 131 | `can_write_buffer.tail_size = 0U;` | 3 | **R1,R2,R3** | |
| 132 | `can_read_buffer.ptr = 0U;` | 3 | **R1,R2,R3** | |
| 133 | `can_read_buffer.tail_size = 0U;` | 3 | **R1,R2,R3** | |
| 134 | `}` | 3 | **R1,R2,R3** | |

## `refresh_can_tx_slots_available()` — lines 137-144

| 行 | 代码 | 执行次数 | 覆盖场景 | 说明 |
|----|------|---------|---------|------|
| 137 | `void refresh_can_tx_slots_available()` | 636 | S1,S2,S3,S4 + heartbeat/tick handler | 每次 can_send 后调用 |
| 138 | `if (can_tx_check_min_slots_free(USB))` | 636 (true) | S1,S2,S3,S4 | 队列始终有空位 |
| 139 | `can_tx_comms_resume_usb();` | 636 | S1,S2,S3,S4 | |
| 141 | `if (can_tx_check_min_slots_free(SPI))` | 636 (true) | S1,S2,S3,S4 | 队列始终有空位 |
| 142 | `can_tx_comms_resume_spi();` | 636 | S1,S2,S3,S4 | |
| 144 | `}` | 636 | S1,S2,S3,S4 | |
