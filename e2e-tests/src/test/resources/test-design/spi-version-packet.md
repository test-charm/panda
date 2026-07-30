# SPI Version Packet — 测试设计文档

> 功能: `spi_version_packet()` in `board/drivers/spi.h` + `crc_checksum()` in `board/crc.h`
> 被测接口: JNA `jna_spi_version_packet()` (直接调用生产代码)
> 涉及文件: `board/crc.h` (20 行), `board/drivers/spi.h:44-86` (spi_version_packet)
> Phase H: e2e 包装器已删除，真实 `board/drivers/spi.h` 直接使用。
> 合并覆盖: `hw-type.md` + `mcu-uid.md` + `serial.md` (第十三节 B1+B3+B5)
>   — `bytes[21]` = hw_type (已覆盖), `bytes[9..20]` = UID (已覆盖)
>   — serial/provision (0xd0) 三个 scenario 已恢复至 feature 文件末尾，覆盖 `provision.h`

## 1. 被测功能流程图

```
spi_version_packet(out_buf):
  [memcpy(out, "VERSION", 7)]
            │
            ▼
  data_pos = 9
  data_len = 0
            │
            ▼
  memcpy(out[9..20], UID_BASE, 12)
  data_len += 12
            │
            ▼
  out[21] = hw_type (0x0A ← CUATRO)
  data_len += 1
            │
            ▼
  out[22] = USB_PID & 0xFF (0xCC)
  data_len += 1
            │
            ▼
  out[23] = 0x02 (SPI protocol version)
  data_len += 1
            │
            ▼
  out[7..8] = data_len (= 15, LE)
            │
            ▼
  out[24] = crc_checksum(out, 24, 0xD5)
            │    ┌─────────────────────┐
            │    │ CRC-8 (poly=0xD5):   │
            │    │  crc = 0xFF         │
            │    │  for i=23..0:       │
            │    │    crc ^= dat[i]    │
            │    │    for j=0..7:      │
            │    │      if bit7:       │
            │    │        crc<<1^poly  │
            │    │      else:         │
            │    │        crc<<=1      │
            │    └─────────────────────┘
            ▼
  return resp_len (= 25)
```

## 2. 输入因子

| 因子 | 类型 | 等价类 | 取值 |
|------|------|--------|------|
| `fake_uid[]` (前置) | byte[12] | 全零 (默认) | 00 00 00 00 00 00 00 00 00 00 00 00 |
| `fake_uid[]` (前置) | byte[12] | 非零 (验证 CRC 变化) | 00 11 22 33 44 55 66 77 88 99 AA BB |
| `hw_type` | uint8 | CUATRO (10) | 0x0A (detect_board_type 自动设置) |
| `USB_PID` | uint16 | 0xDDCC (非 BOOTSTUB) | config.h 编译时确定 |

## 3. 输出因子

| 输出 | 类型 | 说明 |
|------|------|------|
| spiVersionResult.len | int | 总长度 = 25 (7 + 2 + 12 + 1 + 1 + 1 + 1) |
| spiVersionResult.crc8 | byte | CRC-8 of bytes[0..23] with poly=0xD5 |
| spiVersionResult.bytes[0..6] | byte[] | "VERSION" (0x56,0x45,0x52,0x53,0x49,0x4F,0x4E) |
| spiVersionResult.bytes[7..8] | byte[] | data_len = 15 (LE: 0x0F,0x00) |
| spiVersionResult.bytes[9..20] | byte[] | UID_BASE → fake_uid[] (12 bytes) |
| spiVersionResult.bytes[21] | byte | hw_type = 0x0A (CUATRO) |
| spiVersionResult.bytes[22] | byte | USB_PID low byte = 0xCC |
| spiVersionResult.bytes[23] | byte | SPI protocol version = 0x02 |

## 4. 测试用例

### TC1: 默认零 UID → 返回完整 VERSION 包 + CRC-8 = 0x57
- 前置: `detect_board_type()` 设 hw_type=0x0A, fake_uid=[0x00×12]
- 输入: 调用 `spi_version_packet(buf)`
- 输出: len=25, crc8=0x57, VERSION, data_len=15, UID=全零, hw_type=0x0A, USB_PID=0xCC, proto=0x02

### TC2: 预设非零 UID → UID 字节正确写入, CRC-8 与 TC1 不同
- 前置: `setMcuUid()` 设 fake_uid=[0x00,0x11,...,0xBB], hw_type=0x0A
- 输入: 调用 `spi_version_packet(buf)`
- 输出: len=25, UID=预设值, CRC-8 != 0x57（不同输入→不同输出）

## 5. 覆盖检查

### `crc_checksum()` in board/crc.h (20 行)

| 行 | 说明 | TC1 | TC2 |
|----|------|:--:|:--:|
| 3-4 | 函数签名, crc=0xFF | ✅ | ✅ |
| 7-8 | 逆序 XOR 循环 (24 字节) | ✅ | ✅ |
| 9 | 位循环 (8 位/字节) | ✅ | ✅ |
| 10-11 | if bit7: crc<<1^poly | ✅ | ✅ |
| 13-14 | else: crc<<=1 | ✅ | ✅ |
| 18 | return crc | ✅ | ✅ |

> 24 字节 × 8 位 = 192 次位迭代，`if/else` 双分支在任意输入下均覆盖。

### `spi_version_packet()` in board/drivers/spi.h:44-86

| 行 | 说明 | TC1 | TC2 |
|----|------|:--:|:--:|
| 54 | memcpy "VERSION" | ✅ bytes[0..6] | ✅ 隐式 |
| 57-58 | data_len=0, data_pos=9 | ✅ len=25 | ✅ len=25 |
| 61 | memcpy from UID_BASE | ✅ 全零路径 | ✅ 非零路径 |
| 62,66,70,74 | data_len 累加 | ✅ len=25 | ✅ len=25 |
| 65 | hw_type 写入 | ✅ bytes[21]=0x0A | ✅ 隐式 |
| 69 | USB_PID 写入 | ✅ bytes[22]=0xCC | ✅ 隐式 |
| 73 | 协议版本 0x02 | ✅ bytes[23]=0x02 | ✅ 隐式 |
| 77-78 | data_len 序列化 | ✅ bytes[7..8] | ✅ 隐式 |
| 81 | resp_len=24 | ✅ crc8 等于覆盖 | ✅ crc8 等于覆盖 |
| 82 | crc_checksum 调用 | ✅ 0x57 | ✅ ≠0x57 |
| 83 | resp_len=25 | ✅ len=25 | ✅ len=25 |
| 85 | return 25 | ✅ len=25 | ✅ len=25 |

### 覆盖矩阵

| 条件 | TC1 | TC2 |
|------|:--:|:--:|
| 函数入口 | ✅ | ✅ |
| UID 全部为零 | ✅ | — |
| UID 部分非零 | — | ✅ |
| CRC-8 双分支 (if/else) | ✅ | ✅ |
| hw_type=0x0A, USB_PID=0xCC | ✅ | ✅ |
| 所有 spi_version_packet 行 | ✅ | ✅ |
| 所有 crc_checksum 行 | ✅ | ✅ |

✅ **100% 行覆盖** — `crc_checksum` (20 行) + `spi_version_packet` (43 行) 全部进入覆盖率。

## 6. 去桩化说明

本测试依赖 **C1** 任务：删除 e2e 空桩 `e2e-tests/src/test/c/board/crc.h`，真实 `board/crc.h`（纯 C 位运算，零硬件依赖）在 e2e 编译中自动生效。

SPI 驱动去桩策略：
- e2e 桩 `board/drivers/spi.h` 提供 `llspi_init`/`llspi_mosi_dma`/`llspi_miso_dma` 空桩
- 通过相对路径 `#include "../../../../../../board/drivers/spi.h"` 引入真实 SPI 代码
- `spi_version_packet()` 不调用 DMA 函数，仅在 `spi_rx_done()` 的 VERSION 分支中被触发

## 覆盖率

> 数据来源: `run_all_coverage.sh` 合并报告 (cuatro + tres + red)
> 综合行覆盖率: **91.1%** (1989/2183, 35 files)

| 源文件 | 行覆盖 | 说明 |
|--------|--------|------|
| `board/crc.h` | 100% (20/20) | ✅ C1 去桩化 — 纯 CRC-8 算法，通过 spi_version_packet 调用覆盖 |
| `board/drivers/spi.h` | **94.2%** (147/156) | ✅ Phase F.5 — spi_version_packet + spi_rx_done + spi_tx_done 全状态机覆盖
| `board/provision.h` | **100%** (7/7) | ✅ 第十三节 B5 — 通过 serial/provision 场景覆盖 (get_provision_chunk + memcmp + unprovisioned 分支) |
