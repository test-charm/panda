# SPI 状态机 — 测试设计文档

> 功能: `spi_rx_done()` + `spi_tx_done()` + `validate_checksum()` in `board/drivers/spi.h`
> 被测接口: JNA `jna_spi_rx_done()`, `jna_spi_tx_done()`, `jna_spi_set_state()`, `jna_spi_write_rx_buf()` (直接操作 SPI buffer 并调用生产代码)
> 涉及文件: `board/drivers/spi.h` (156 行)
> 覆盖基线: 147/156 (94.2%), 仅 `spi_init()` 8行 + 防御 print 4行未覆盖

## 1. 被测功能流程图

```
SPI 状态机 (spi.h):
  spi_init()                      — 硬件 DMA 初始化 (e2e 不可测)
       │
       ▼
  ┌─ HEADER (0) ◄──────────────────────────────────┐
  │   llspi_mosi_dma 接收 7 字节头部                 │
  │        │                                        │
  │   spi_rx_done()                                 │
  │        │                                        │
  │   memcmp("VERSION")?                            │
  │   ├─ YES → spi_version_packet() → HEADER_NACK(2) │
  │   │                                          │   │
  │   └─ NO, STATE==HEADER?                       │   │
  │       ├─ valid sync+checksum → ACK           │   │
  │       │   spi_buf_tx[0]=HACK                  │   │
  │       │   next_state=HEADER_ACK(1)            │   │
  │       │       │                                │   │
  │       └─ invalid → NACK                        │   │
  │           spi_buf_tx[0]=NACK                   │   │
  │           next_state=HEADER_NACK(2)            │   │
  │                                                │   │
  ├─ HEADER_ACK (1) ──spi_tx_done()──► DATA_RX (3) │   │
  │   llspi_mosi_dma 接收 data+checksum            │   │
  │        │                                        │   │
  │   spi_rx_done()                                 │   │
  │        │                                        │   │
  │   validate_checksum(data+checksum)?             │   │
  │   ├─ NO → NACK → HEADER_NACK(2)                │   │
  │   └─ YES → 根据 endpoint 分发                  │   │
  │       ├─ 0: comms_control_handler → ACK        │   │
  │       ├─ 1/0x81: comms_can_read → ACK          │   │
  │       ├─ 2: comms_endpoint2_write → ACK        │   │
  │       ├─ 3: comms_can_write → ACK (if ready)   │   │
  │       ├─ 0xAB: test echo → ACK                 │   │
  │       ├─ 0xAC: test NACK → NACK                │   │
  │       └─ else: unexpected → NACK               │   │
  │            │                                    │   │
  │   ACK: DACK + data + checksum → DATA_TX(5)     │   │
  │   NACK: NACK → HEADER_NACK(2)                  │   │
  │                                                 │   │
  ├─ DATA_TX (5) ──spi_tx_done()──► HEADER (0) ────┘   │
  │                                                     │
  ├─ HEADER_NACK (2) ──spi_tx_done()──► HEADER (0) ────┘
  │
  └─ Unexpected ──spi_tx_done()──► HEADER (0)

  spi_tx_done(reset=true): 任何状态 → HEADER (0)
  spi_rx_done + unexpected state: print + NACK fallback
```

## 2. 输入因子

| 因子 | 类型 | 等价类 | 值 |
|------|------|--------|-----| 
| `spi_buf_rx[0]` (sync byte) | uint8 | `SPI_SYNC_BYTE` (0x5A) / 其他 | 0x5A, 0x00 |
| `spi_buf_rx[1]` (endpoint) | uint8 | 0,1,2,3,0x81,0xAB,0xAC,0xFF | 各 endpoint |
| `spi_buf_rx[2..3]` (len_mosi) | uint16 | 0, 4, 7 (sizeof ControlPacket_t), 3 (不足) | 各种长度 |
| `spi_buf_rx[4..5]` (len_miso) | uint16 | 0, 4, 8 | 各种长度 |
| Header checksum | uint8 | 正确 / 错误 | 动态计算 vs 0x00 |
| Data checksum | uint8 | 正确 / 错误 | 动态计算 vs 0x00 |
| `spi_state` (前置) | uint8 | 0..5 (各种 SPI 状态) | 0 (HEADER), 1 (HEADER_ACK), 4 (DATA_RX_ACK), 5 (DATA_TX) |
| `spi_can_tx_ready` (前置) | bool | true / false | can_init 后为 true, 手动清除 |
| `spi_buf_rx` 数据内容 | byte[] | VERSION / ControlPacket_t / CAN 数据 / 任意 | 各场景不同 |

## 3. 输出因子

`spiStateResult` 统一对象:

| 属性 | 类型 | 说明 |
|------|------|------|
| `state` | int | 最终 SPI 状态 (0=HEADER, 1=HEADER_ACK, 2=HEADER_NACK, 3=DATA_RX, 4=DATA_RX_ACK, 5=DATA_TX) |
| `errorCount` | int | 累积 checksum 错误次数 |
| `rx.ack` | boolean | 是否返回 ACK (DACK/HACK: true, NACK: false) |
| `rx.txLen` | int | tx_buf 响应长度 (NACK/HACK=1, DACK=4+data_len) |
| `rx.txBytes` | byte[] | tx_buf 完整内容 |

## 4. 测试用例

### 4.1 spi_rx_done: Header 处理 (A 组)

| ID | 场景 | 前置 | 输入 | 预期输出 |
|----|------|------|------|---------|
| A1 | 有效 sync+checksum → ACK | state=0 | header=`[5A AB 00 00 04 00 5E]` | state=1, ack=true, errorCount=0 |
| A2 | 无效 sync → NACK | state=0 | header=`[00 01 00 00 00 00 00]` | state=2, ack=false, errorCount=1 |
| A3 | 有效 sync + 无效 checksum → NACK | state=0 | header=`[5A 01 00 00 00 00 00]` | state=2, ack=false, errorCount=1 |

### 4.2 spi_rx_done: DATA_RX 处理 (B 组)

**两阶段**: Header 握手 → spi_rx_done → spi_tx_done → 写 data → spi_rx_done

| ID | 场景 | Header 参数 | Data 参数 | 预期 |
|----|------|-----------|----------|------|
| B1 | Checksum 无效 → NACK | ep=0xAB, mosi=0, miso=4 | `[00]` (错) | state=2, ack=false, errorCount=1 |
| B2 | Endpoint 0xAB (test echo) → DACK | ep=0xAB, mosi=0, miso=4 | `[AB]` (对) | state=5, ack=true, txLen=8 |
| B3 | Endpoint 0xAC (test NACK) → NACK | ep=0xAC, mosi=0, miso=0 | `[AB]` (对) | state=2, ack=false |
| B4 | Endpoint 2 (ep2 write) → DACK | ep=2, mosi=4, miso=0 | `[41 42 43 44 AF]` | state=5, ack=true |
| B5 | Endpoint 1 (CAN read) → DACK | ep=1, mosi=0, miso=8 | `[AB]` (对) | state=5, ack=true |
| B6 | Endpoint 0x81 (CAN read) → DACK | ep=0x81, mosi=0, miso=8 | `[AB]` (对) | state=5, ack=true |
| B7 | Endpoint 3 + can_tx_ready → DACK | ep=3, mosi=4, miso=0 | `[01 02 03 04 AF]` | state=5, ack=true |
| B8 | Endpoint 3 + !can_tx_ready → NACK | ep=3, mosi=4, miso=0 | `[01 02 03 04 AF]` | state=2, ack=false |
| B9 | VERSION 匹配 | 写 `"VERSION"` | — | state=2, ack=true (HACK) |
| B10 | Endpoint 0 control (有效) | ep=0, mosi=7, miso=0 | `[C1 00 00 00 00 00 00 6A]` | state=5, ack=true, txLen=5 |
| B11 | Endpoint 0 数据不足 | ep=0, mosi=3, miso=0 | `[AA BB CC 76]` | state=2, ack=false |
| B12 | Unexpected endpoint 0xFF | ep=0xFF, mosi=0, miso=0 | `[AB]` (对) | state=2, ack=false |
| B13 | RX unexpected state + no response | state=1, 非VERSION | `[00 00 00 00 00 00 00]` | state=2, ack=false, txLen=1 |

### 4.3 spi_tx_done: 状态转换 (C 组)

| ID | 场景 | 前置状态 | 输入 | 预期 state |
|----|------|---------|------|-----------|
| C1 | HEADER_NACK → HEADER | 2 (HEADER_NACK) | spi_tx_done() | 0 |
| C2 | HEADER_ACK → DATA_RX | 1 (HEADER_ACK) | spi_tx_done() | 3 |
| C3 | DATA_TX → HEADER | 5 (DATA_TX) | spi_tx_done() | 0 |
| C4 | Unexpected state → HEADER | 4 (DATA_RX_ACK) | spi_tx_done() | 0 |
| C5 | reset=true → HEADER | 5 (DATA_TX) | spi_tx_done(reset=true) | 0 |

## 5. 覆盖检查

### `spi_rx_done()` in board/drivers/spi.h:106-234

| 行 | 说明 | 覆盖场景 |
|----|------|---------|
| 106-111 | entry: 变量初始化 | A1-3,B1-13 |
| 112-116 | header 解析 | A1-3,B1-13 |
| 118-120 | VERSION 匹配 → spi_version_packet | B9 |
| 121 | `spi_state == HEADER` 分支 | A1-3,B1-13 |
| 122-127 | 有效 header → ACK (HACK) | A1,B1-13 |
| 128-136 | 无效 header → NACK | A2,A3 |
| 137-141 | DATA_RX 分支: checksum 校验 | B1-13 |
| 142-147 | Endpoint 0: comms_control_handler | B10 |
| 148-150 | Endpoint 0: 数据不足 → print | B11 |
| 151-154 | Endpoint 1/0x81: comms_can_read | B5,B6 |
| 155-157 | Endpoint 1/0x81: 错误路径 (print) | ❌ 防御性 |
| 158-160 | Endpoint 2: comms_endpoint2_write | B4 |
| 161-167 | Endpoint 3: CAN write (ready) | B7 |
| 168-170 | Endpoint 3: CAN write (!ready) | B8 |
| 171-173 | Endpoint 3: 错误路径 (print) | ❌ 防御性 |
| 174-177 | Endpoint 0xAB: test echo | B2 |
| 178-180 | Endpoint 0xAC: test NACK | B3 |
| 181-183 | Unexpected endpoint → print | B12 |
| 184-186 | Checksum 无效 → NACK | B1 |
| 197-200 | !response_ack → NACK | B1,B3,B8,B11,B12,B13 |
| 201-215 | response_ack → DACK response | B2,B4,B5,B6,B7,B10 |
| 217-219 | else: unexpected state → print | B13 |
| 221-227 | response_len==0 → NACK fallback | B13 |
| 228 | llspi_miso_dma (stub) | ALL |
| 230 | spi_state = next_rx_state | ALL |
| 231-233 | !checksum_valid → error_count++ | A2,A3,B1,B3,B8,B11,B12,B13 |

### `spi_tx_done()` in board/drivers/spi.h:236-254

| 行 | 说明 | 覆盖场景 |
|----|------|---------|
| 236-240 | HEADER_NACK \|\| reset → HEADER | A1-3,B9,C1,C5 |
| 241-244 | HEADER_ACK → DATA_RX | A1,B1-13,C2 |
| 245-248 | DATA_TX → HEADER | B2,B4,B5,B6,B7,B10,C3 |
| 249-253 | default: unexpected → HEADER + print | C4 |

### 未覆盖路径

| 行 | 原因 | 分类 |
|----|------|------|
| 88-95 | `spi_init()` — 调用 `llspi_init()` (硬件 DMA 配置) | 硬件依赖 |
| 156-157 | Endpoint 1/0x81 CAN read 非零长度 → print 错误 | 防御性 |
| 172-173 | Endpoint 3 CAN write 零长度 → print 错误 | 防御性 |

## 6. 去桩化说明

SPI 驱动通过 e2e 包装文件 `e2e-tests/src/test/c/board/drivers/spi.h` 引入:
- 提供 `llspi_init`/`llspi_mosi_dma`/`llspi_miso_dma` 空桩（DMA 硬件操作）
- 通过相对路径 `#include "../../../../../../board/drivers/spi.h"` 引入真实 SPI 状态机代码
- 所有业务逻辑（checksum 校验、endpoint 分发、状态转换）运行在生产代码中

## 7. 端点 2 写入 — 环分发 (第十三节 C6 合并)

> 合并自: `endpoint2_write.feature` (6 scenarios)
> 被测函数: `comms_endpoint2_write()` in `board/main_comms.h`

### 7.1 SPI 路径覆盖 (B4 场景)

SPI DATA_RX endpoint 2 → `comms_endpoint2_write()` 调用已在 B4 场景中覆盖，验证状态机转换到 DACK（state=5, ack=true）。

### 7.2 直接 JNA 调用 — 环分发

通过 `jna_comms_endpoint2_write()` 直接调用，覆盖 `get_ring_by_number()` 的环选择逻辑。

| ID | 场景 | 输入 | 预期 |
|----|------|------|------|
| E1 | Ring 0 UART debug | `[00 48 45 4C 4C 4F]` | len=5, bytes="HELLO" |
| E2 | Ring 0 空数据 | `[00]` | len=0 |
| E3 | Ring 1 无效 | `[01 41 42 43]` | len=0 |
| E4 | Ring 2 被过滤 | `[02 58 59 5A]` | len=0 |
| E5 | Ring 3 被过滤 | `[03 50 51 52]` | len=0 |
| E6 | Ring 4 SOM debug | `[04 53 4F 4D]` | len=3, bytes="SOM" |

## 8. 覆盖率

> 数据来源: `run_all_coverage.sh` 合并报告 (cuatro + tres + red)
> 综合行覆盖率: **91.1%** (1989/2183)

| 源文件 | 行覆盖 | 说明 |
|--------|--------|------|
| `board/drivers/spi.h` | **94.2%** (147/156) | ✅ Phase F.5 — spi_rx_done + spi_tx_done 全状态机覆盖 |
| `e2e-tests/.../board/drivers/spi.h` | 66.7% (2/3) | e2e 包装桩 |

## 9. UART 读取 — 控制传输 0xe0 (第十三节 B8 合并)

> 合并自: `uart_read.feature` (3 scenarios)
> 被测函数: `comms_control_handler()` case 0xe0 in `board/main_comms.h`

### 9.1 数据流

```
comms_control_handler(0xe0, param1=ring_num, length):
       │
       ▼
  ur = get_ring_by_number(ring_num)
       │
  ┌────┴────┐
  ▼         ▼
NULL      valid ring
  │         │
  ▼         ▼
break    get_char loop → resp[resp_len++]
         until resp_len == length || ring empty
```

### 9.2 测试用例

| ID | 场景 | 输入 | 预期 |
|----|------|------|------|
| U1 | 无效 ring (param1=99) → NULL | `UsbControlRequest: { request: -32y, param1: 99, param2: 0 }` | `respBuffer.len: 0` |
| U2 | 有效 ring 空数据 → 零长度 | `UartRead: { param1: 0 }` | `respBuffer.len: 0` |
| U3 | 有效 ring 有 "HELLO" → 读取 5 字节 | `Given exists data: ControlSetup: { uartData: "HELLO" }` → `UartRead: { param1: 0, length: 5 }` | `respBuffer.len: 5`, bytes=[H,E,L,L,O] |

### 9.3 覆盖检查

| 条件 | U1 | U2 | U3 |
|------|:--:|:--:|:--:|
| `get_ring_by_number == NULL` | ✅ | — | — |
| ring exists, empty | — | ✅ | — |
| ring exists, has data | — | — | ✅ |
| `resp_len < req_length` | — | ✅ | ✅ |
| `get_char` 成功 | — | — | ✅ |

✅ 所有分支已覆盖。
