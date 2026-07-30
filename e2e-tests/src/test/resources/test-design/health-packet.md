# Health Packet + 版本读取 — 测试设计文档

> 功能: get_health (0xd2) + get_version (0xd6) + get_packet_versions (0xdd)
> 被测接口: USB control request 0xd2 / 0xd6 / 0xdd
> 合并自: `health-packet.md` + `get-version.md` + `packet-versions.md` (第十三节 B2+B4 合并)

**函数签名**: `static int get_health_pkt(void *dat)` (board/main_comms.h:7-48)

## 代码流程

```
[调用者] → comms_control_handler(0xd2) → get_health_pkt(resp)
                                             │
                    ┌────────────────────────┘
                    ▼
            health_t {
              uptime_pkt         ← uptime_cnt
              voltage_pkt        ← board->read_voltage_mV() [cuatro: real *11 via ADC stub; red/tres: stub=12000]
              current_pkt        ← board->read_current_mA() [cuatro: real *2 via ADC stub; red/tres: unused=0]
              ignition_line_pkt  ← harness_check_ignition() [stub: false]
              ignition_can_pkt   ← ignition_can (extern)
              controls_allowed_pkt ← controls_allowed (opendbc)
              safety_tx_blocked_pkt ← safety_tx_blocked
              safety_rx_invalid_pkt ← safety_rx_invalid
              tx_buffer_overflow_pkt ← tx_buffer_overflow
              rx_buffer_overflow_pkt ← rx_buffer_overflow
              car_harness_status_pkt ← harness.status
              safety_mode_pkt    ← current_safety_mode (opendbc)
              safety_param_pkt   ← current_safety_param (opendbc)
              alternative_experience_pkt ← alternative_experience (opendbc)
              power_save_enabled_pkt ← power_save_enabled
              heartbeat_lost_pkt ← heartbeat_lost
              safety_rx_checks_invalid_pkt ← safety_rx_checks_invalid (opendbc)
              fault_status_pkt   ← fault_status
              faults_pkt         ← faults
              interrupt_load_pkt ← interrupt_load
              fan_power          ← fan_state.power
              spi_error_count_pkt ← spi_error_count
              sbu1_voltage_mV    ← harness.sbu1_voltage_mV
              sbu2_voltage_mV    ← harness.sbu2_voltage_mV
              som_reset_triggered ← bootkick_reset_triggered
              sound_output_level_pkt ← sound_output_level
            }
            return sizeof(health_t)
```

函数无分支逻辑——直接照搬所有全局状态变量到结构体中。因此测试的重点是验证：**不同状态下 health packet 中各字段的值是否正确反映当前全局状态**。

## 输入因子分析

`get_health_pkt()` 无入口参数。其"输入"是固件中的全局状态变量，这些变量由其他 USB 命令修改。

| 因子 | 类型 | 等价类 | 测试取值 |
|------|------|--------|----------|
| 安全模式 (current_safety_mode) | 枚举 | SILENT(0), TOYOTA(2), ALLOUTPUT(17) | 0, 2, 17 |
| CAN TX 阻断计数 (safety_tx_blocked) | 整数 | 0, ≥1 | 0, 1 |
| 心跳丢失 (heartbeat_lost) | 布尔 | false, true | false, true |
| 心跳已启用 (heartbeat_engaged) | 布尔 | false, true | false, true |
| 电压 (voltageMV) | 整数 | 默认 12001 (1091×11, ADC stub), 可设定; red/tres: stub 12000 | 12001, 11000 |
| 电流 (currentMA) | 整数 | 默认 0, 可设定; red/tres 强制 0 (unused) | 0, 500 |

## 输出因子（被测字段）

| 字段 | 类型 | 来源 |
|------|------|------|
| safety_mode_pkt | uint8 | current_safety_mode |
| safety_param_pkt | uint16 | current_safety_param |
| safety_tx_blocked_pkt | uint32 | safety_tx_blocked |
| safety_rx_invalid_pkt | uint32 | safety_rx_invalid |
| heartbeat_lost_pkt | uint8 | heartbeat_lost |
| heartbeat_engaged (从safety.h) | bool | heartbeat_engaged |
| uptime_pkt | uint32 | uptime_cnt |
| voltage_pkt | uint32 | `current_board->read_voltage_mV()` |
| | | cuatro: `cuatro_read_voltage_mV()` → `adc_get_mV(ch8) * 11` (ADC stub 可设定) |
| | | red/tres: stub 返回 e2e_voltage_mV (默认 12000) |
| current_pkt | uint32 | `current_board->read_current_mA()` |
| | | cuatro: `cuatro_read_current_mA()` → `adc_get_mV(ch3) * 2` (ADC stub 可设定) |
| | | red/tres: `unused_read_current` 始终返回 0 |

> **说明**: cuatro 板已切换到真实 `cuatro_read_voltage_mV()` / `cuatro_read_current_mA()`，通过 ADC stub (lladc.h) 的 ch8/ch3 通道注入测试值，覆盖 ×11/×2 硬件乘法因子。电压默认 12001mV (1091×11)，可设定值需为 11 的倍数以确保精确。电流在 cuatro 上通过 currentMA 注入，需为偶数确保精确；在 red/tres 上 `unused_read_current` 始终返回 0。uptime 验证 ≥0 即可（固件初始化后为 0）。其余 20+ 字段值固定为 0/false，不做逐一验证。

## 测试用例

### 用例 1: SILENT 模式下的默认健康数据包

**最短路径**：初始化后直接调用 get_health → 返回默认值。

| 前置操作 | safety_mode_pkt | safety_tx_blocked_pkt | heartbeat_lost_pkt | voltage_pkt | uptime_pkt |
|----------|:---------------:|:---------------------:|:------------------:|:-----------:|:----------:|
| (无)     | 0 (SILENT)      | 0                     | 0                  | 12001       | ≥0         |

### 用例 2: 切换安全模式后健康数据包反映新模式

**路径**：set_safety_mode(TOYOTA) → get_health → 返回 TOYOTA 模式。

| 前置操作 | safety_mode_pkt | safety_param_pkt | heartbeat_lost_pkt |
|----------|:---------------:|:----------------:|:------------------:|
| SetSafetyMode(2) | 2 (TOYOTA) | 0 | 0 |

### 用例 4: 健康数据包电压反映可设 e2e 值
- 前置: ControlSetup { voltageMV: 11000 }
- 输出: voltage: 11000
- 说明: `jna_set_voltage_mV(11000)` → `e2e_adc_ch8_mV=1000` → `cuatro_read_voltage_mV()` 返回 `1000*11=11000`

### 用例 5: 健康数据包电流反映可设 e2e 值
- 前置: ControlSetup { currentMA: 500 }
- 输出: current: 500
- 说明: `jna_set_current_mA(500)` → `e2e_adc_ch3_mV=250` → `cuatro_read_current_mA()` 返回 `250*2=500`

### 用例 6 (@red): 预设电流非零，unused_read_current 仍返回 0
- 前置: ControlSetup { currentMA: 500 } + red board (`.read_current_mA = unused_read_current`)
- 输出: current: 0
- 说明: `unused_read_current` 始终返回 0U，覆盖 e2e 注入值

### 用例 7 (@tres): 预设电流非零，unused_read_current 仍返回 0
- 前置: ControlSetup { currentMA: 500 } + tres board (`.read_current_mA = unused_read_current`)
- 输出: current: 0

## 覆盖率

> 数据来源: `run_all_coverage.sh` 合并报告 (cuatro + tres + red)
> 综合行覆盖率: **78.9%** (全量), 本功能涉及以下源文件:

| 源文件 | 行覆盖 | 说明 |
|--------|--------|------|
| `main_comms.h` | 97.0% (261/269) | USB 命令处理 |
| `unused_funcs.h` | 91.3% (21/23) | ✅ Phase D.2 |
| `main.c` | 64.2% (145/226) | 主循环 |
| `boards/cuatro.h` | 98.5% (65/66) | ✅ `cuatro_read_voltage_mV`/`cuatro_read_current_mA` 通过 ADC stub 覆盖 |

---

## 固件版本读取 (0xd6)

> 合并自: `get-version.md` (第十三节 B2)

### 被测功能流程图

```
get version (0xd6):
  [controlWrite(0xd6, 0, 0)]
           │
           ▼
  memcpy(resp, gitversion, sizeof(gitversion))
  resp_len = sizeof(gitversion) - 1
           │
           ▼
        (done)
```

### 输入因子

| 因子 | 类型 | 等价类 | 取值 |
|------|------|--------|------|
| `request` | uint8 | 0xd6 (唯一) | 0xd6 |
| `gitversion` (前置) | char[64] | 任意 8-char 字符串 | "abcdef01" |

### 输出因子

| 输出 | 类型 | 说明 |
|------|------|------|
| respBuffer.len | int | resp_len = 63 |
| respBuffer.bytes[0..7] | List\<Byte\> | 前 8 字节为 gitversion 字符 |

### 测试用例

**TC-V1**: 预设版本 → resp buffer 验证
- 前置: gitversion="abcdef01"
- 输入: request=0xd6
- 输出: resp_len=63, bytes[0..7]=97,98,99,100,101,102,48,49

### 覆盖检查

| 条件 | TC-V1 |
|------|:--:|
| request == 0xd6 | ✅ |

✅ 代码路径已覆盖。

---

## 数据包版本读取 (0xdd)

> 合并自: `packet-versions.md` (第十三节 B4)

### 被测功能流程图

```
get packet versions (0xdd):
  [controlWrite(0xdd, 0, 0)]
           │
           ▼
  versions[0] = HEALTH_PACKET_VERSION
  versions[1] = CAN_PACKET_VERSION_HASH
  memcpy(resp, versions, 8)
  resp_len = 8
           │
           ▼
        (done)
```

### 输入因子

| 因子 | 类型 | 等价类 | 取值 |
|------|------|--------|------|
| `request` | uint8 | 0xdd (唯一) | 0xdd |

### 输出因子

| 输出 | 类型 | 说明 |
|------|------|------|
| healthVersion | int | HEALTH_PACKET_VERSION (e2e: 0) |
| canVersionHash | int | CAN_PACKET_VERSION_HASH (e2e: 0) |
| canInitTimeoutMs | int | `CAN_INIT_TIMEOUT_MS` 编译时常量 (500) |

### 测试用例

**TC-P1**: 读取数据包版本号和配置常量
- 输入: request=0xdd
- 输出: healthVersion=0, canVersionHash=0, canInitTimeoutMs=500

### 覆盖检查

| 条件 | TC-P1 |
|------|:--:|
| request == 0xdd | ✅ |
| CAN_INIT_TIMEOUT_MS == 500 | ✅ |

✅ 代码路径已覆盖。

---

## 固件签名读取 (0xd3 + 0xd4)

> 合并自: `signature.md` (第十三节 B7)

### 被测功能流程图

```
get signature chunk (0xd3 / 0xd4):
  [controlWrite(0xd3/d4, chunk_idx, 0)]
           │
           ▼
  chunk = signature_chunks[chunk_idx]  (预先通过 jna_set_signature_chunk 注入)
  memcpy(resp, chunk, 64)
  resp_len = 64
           │
           ▼
        (done)
```

### 输入因子

| 因子 | 类型 | 等价类 | 取值 |
|------|------|--------|------|
| `request` | uint8 | 0xd3 (chunk 0), 0xd4 (chunk 1) | 0xd3, 0xd4 |
| `signatureChunkN` (前置) | byte[64] | 64 字节签名数据 | "AA...DD", "01...04" |

### 输出因子

| 输出 | 类型 | 说明 |
|------|------|------|
| respBuffer.len | int | resp_len = 64 |
| respBuffer.bytes[0..63] | List\<Byte\> | 64 字节签名分块 |

### 测试用例

**TC-S1**: 获取第一个 64 字节 (0xd3)
- 前置: codeLen=256, signatureChunk0 前 32 字节=0xAA, 后 32 字节=0xDD
- 输出: resp_len=64, bytes[0]=0xAA, bytes[31]=0xAA, bytes[32]=0xDD, bytes[63]=0xDD

**TC-S2**: 获取第二个 64 字节 (0xd4)
- 前置: codeLen=256, signatureChunk1 前 32 字节=0x01, 后 32 字节=0x04
- 输出: resp_len=64, bytes[0]=0x01, bytes[31]=0x01, bytes[32]=0x04, bytes[63]=0x04

### 覆盖检查

| 条件 | TC-S1 | TC-S2 |
|------|:--:|:--:|
| request == 0xd3 + chunk 0 | ✅ | — |
| request == 0xd4 + chunk 1 | — | ✅ |

✅ 全部签名分块路径已覆盖。
