# SPI/USB Endpoint 2 批量写入 — 测试设计文档

> **⚠️ 已合并**: 此文档对应的 `endpoint2_write.feature` 已于 2026-07-29 合并至 `spi_state_machine.feature`（第十三节 C6）。测试用例 E1-E6 见 `spi-state-machine.md`。

> 功能: `comms_endpoint2_write()` in `board/main_comms.h`
> 被测路径: SPI endpoint 2 / USB endpoint 2 批量写入 → UART ring
> 调用位置: `board/drivers/spi.h:159` (SPI), `board/drivers/usb.h:674` (USB)

## 1. 被测功能数据流

```
comms_endpoint2_write(data, len):
    │
    │  ur = get_ring_by_number(data[0])
    │
    ├── len == 0
    │     → 无操作
    │
    ├── ur == NULL (ring 不存在)
    │     → 无操作
    │
    ├── ur != NULL, 但 2 ≤ data[0] < 4 (ring 2/3 被条件过滤)
    │     → 无操作
    │
    └── ur != NULL, data[0] < 2 或 data[0] ≥ 4
          → for i = 1..len-1: put_char(ur, data[i])
```

## 2. 关键常量

| 常量 | 值 | 含义 |
|------|----|------|
| ring 0 (debug) | `uart_ring_debug` | 调试 UART ring，`get_ring_by_number(0)` 返回 |
| ring 4 (som_debug) | `uart_ring_som_debug` | SOM 调试 UART ring，`get_ring_by_number(4)` 返回 |
| ring 1/2/3 | NULL | 不存在，`get_ring_by_number` 返回 NULL |
| 过滤条件 | `data[0] < 2 \|\| data[0] >= 4` | ring 2/3 即使存在也会被过滤 |

## 3. 输入因子

| 因子 | 类型 | 等价类 | 取值 |
|------|------|--------|------|
| `data[0]` (ring 选择器) | uint8 | 0 (debug ring) | 0x00 |
| `data[0]` (ring 选择器) | uint8 | 1 (无效 ring) | 0x01 |
| `data[0]` (ring 选择器) | uint8 | 2 (不存在) | 0x02 |
| `data[0]` (ring 选择器) | uint8 | 3 (不存在) | 0x03 |
| `data[0]` (ring 选择器) | uint8 | 4 (som_debug ring) | 0x04 |
| `data[1..]` (载荷) | byte[] | 空 (仅 ring 选择器) | len=1 |
| `data[1..]` (载荷) | byte[] | 非空 | "HELLO", "SOM" |
| `len` | uint32 | 0 (不触发) | — |
| `len` | uint32 | 1 (仅选择器)  | — |
| `len` | uint32 | >1 (有载荷)   | — |

## 4. 输出因子

| 输出 | 类型 | 说明 |
|------|------|------|
| `endpoint2WriteResult.len` | int | 写入 UART ring 的字节数 |
| `endpoint2WriteResult.bytes` | byte[] | 写入的载荷字节 |

## 5. 测试用例

### TC1: ring 0 写入 "HELLO" — 5 字节写入 debug UART
- 输入: data=[0x00, 'H', 'E', 'L', 'L', 'O'] (len=6)
- 输出: endpoint2WriteResult.len=5, bytes=[H,E,L,L,O]
- 路径: ring=0 → ur!=NULL → data[0]<2 → put_char×5
- 场景: `endpoint2_write.feature:4`

### TC2: ring 0 仅选择器 — 无载荷不写入
- 输入: data=[0x00] (len=1)
- 输出: endpoint2WriteResult.len=0
- 路径: ring=0 → ur!=NULL → data[0]<2 → for i=1..0 (不执行)
- 场景: `endpoint2_write.feature:23`

### TC3: ring 1 无效 — get_ring_by_number 返回 NULL
- 输入: data=[0x01, 'A', 'B', 'C'] (len=4)
- 输出: endpoint2WriteResult.len=0
- 路径: ring=1 → ur==NULL → 无操作
- 场景: `endpoint2_write.feature:37`

### TC4: ring 2 不存在 — get_ring_by_number 返回 NULL
- 输入: data=[0x02, 'X', 'Y', 'Z'] (len=4)
- 输出: endpoint2WriteResult.len=0
- 路径: ring=2 → ur==NULL → 无操作
- 场景: `endpoint2_write.feature:51`

### TC5: ring 3 不存在 — get_ring_by_number 返回 NULL
- 输入: data=[0x03, 'P', 'Q', 'R'] (len=4)
- 输出: endpoint2WriteResult.len=0
- 路径: ring=3 → ur==NULL → 无操作
- 场景: `endpoint2_write.feature:65`

### TC6: ring 4 写入 "SOM" — 3 字节写入 SOM debug UART
- 输入: data=[0x04, 'S', 'O', 'M'] (len=4)
- 输出: endpoint2WriteResult.len=3, bytes=[S,O,M]
- 路径: ring=4 → ur!=NULL → data[0]≥4 → put_char×3
- 场景: `endpoint2_write.feature:79`

## 6. 覆盖检查

| 条件 | TC1 | TC2 | TC3 | TC4 | TC5 | TC6 |
|------|:--:|:--:|:--:|:--:|:--:|:--:|
| `len != 0` 真 | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| `len != 0` 假 (len=1 → for 不执行) | — | ✅ | — | — | — | — |
| `ur != NULL` (ring 0) | ✅ | ✅ | — | — | — | — |
| `ur == NULL` (ring 1) | — | — | ✅ | — | — | — |
| `ur == NULL` (ring 2) | — | — | — | ✅ | — | — |
| `ur == NULL` (ring 3) | — | — | — | — | ✅ | — |
| `data[0] < 2` (ring 0 通过) | ✅ | ✅ | — | — | — | — |
| `data[0] >= 4` (ring 4 通过) | — | — | — | — | — | ✅ |
| put_char 写入数据 | ✅ | — | — | — | — | ✅ |

✅ 所有分支条件和 ring 选择路径已覆盖。

## 覆盖率

> 数据来源: `run_all_coverage.sh` 合并报告 (cuatro + tres + red)

| 被测行 | 源文件 | 说明 |
|--------|--------|------|
| `main_comms.h:51-62` | `comms_endpoint2_write()` 完整函数 | 行 + 分支 100% 覆盖 |
