# CAN 健康统计 — 测试设计文档

> 功能: CAN health stats via `comms_control_handler()` in `board/main_comms.h`
> 被测接口: USB control request 0xc2 (get CAN health stats)

## 1. 被测功能流程图

```
get CAN health (0xc2):
  [controlWrite(0xc2, param1, 0)]
           │
     ┌─────┴──────────────────────┐
     │ param1 < PANDA_CAN_CNT(3) ? │
     └─────┬──────────────────────┘
        N  │  Y
     (no-op)│
            ├── update_can_health_pkt(param1, 0)   (e2e: no-op stub)
            ├── can_speed = bus_config[param1].can_speed / 10
            ├── can_data_speed = bus_config[param1].can_data_speed / 10
            ├── canfd_enabled = bus_config[param1].canfd_enabled
            ├── brs_enabled = bus_config[param1].brs_enabled
            ├── canfd_non_iso = bus_config[param1].canfd_non_iso
            ├── resp_len = sizeof(can_health_t)
            ├── memcpy(resp, &can_health[param1], resp_len)
            │
            └── (done)
```

## 2. 输入因子

| 因子 | 类型 | 等价类 | 取值 |
|------|------|--------|------|
| `request` | uint8 | 0xc2 (唯一) | 0xc2 |
| `param1` (bus) | uint16 | <3 (valid), >=3 (invalid) | 0, 3 |
| `bus_config[0].can_speed` (默认) | uint32 | 5000 | 5000 |
| `bus_config[0].can_data_speed` (默认) | uint32 | 20000 | 20000 |
| `canfd_enabled`/`brs_enabled`/`canfd_non_iso` (默认) | bool | false | false |

## 3. 输出因子

| 输出 | 类型 | 说明 |
|------|------|------|
| canHealth[0].canSpeed | int | bus_config[0].can_speed / 10 = 500 |
| canHealth[0].canDataSpeed | int | bus_config[0].can_data_speed / 10 = 2000 |
| canHealth[0].canfdEnabled | boolean | bus_config[0].canfd_enabled = false |
| canHealth[0].brsEnabled | boolean | bus_config[0].brs_enabled = false |
| canHealth[0].canfdNonIso | boolean | bus_config[0].canfd_non_iso = false |
| respBuffer.len | int | sizeof(can_health_t) |

## 4. 测试用例

### TC1: 有效 bus 0 → 返回 bus_config 派生的 CAN 健康统计
- 前置: 默认 bus_config (can_speed=5000, can_data_speed=20000)
- 输入: request=0xc2, param1=0
- 输出: canSpeed=500, canDataSpeed=2000, canfd/flags=false

### TC2: 预设 PSR/ECR → 提取错误计数器
- 前置: fake_fdcan[0].PSR=2 (LEC=CAN_ACK_ERROR), ECR=0x8000 (TEC=128)
- 输入: request=0xc2, param1=0
- 输出: lastError=2, receiveErrorCnt=0, transmitErrorCnt=128

### TC3: 无效 bus (param1=3) → no-op
- 前置: 默认值
- 输入: request=0xc2, param1=3
- 输出: canHealth0 全为零

### TC4: PSR 状态位 BO/EW/EP 提取
- 前置: PSR=224 (BO=1, EW=1, EP=1)
- 输入: 直接调用 update_can_health_pkt(0, 0)
- 输出: busOffCnt=1, errorWarning=1, errorPassive=1, lastError=0, lastDataError=0

### TC5: ir_reg ≠ 0 → total_error_cnt 递增 + can_clear_send 条件触发
- 前置: PSR=2, ECR=0x8000, irReg=128 (BO bit)
- 输入: 直接调用 update_can_health_pkt(0, 128)
- 输出: lastError=2, transmitErrorCnt=128, totalErrorCnt=1

### TC6: ir_reg 含 RF0L → total_rx_lost_cnt 递增
- 前置: irReg=16 (RF0L bit)
- 输入: 直接调用 update_can_health_pkt(0, 16)
- 输出: totalErrorCnt=1, totalRxLostCnt=1

## 5. 覆盖检查

| 代码行 | 内容 | TC |
|--------|------|-----|
| L14-16 | fake_fdcan 读 PSR/ECR | TC2, TC4, TC5 |
| L18-19 | bus_off + bus_off_cnt | TC4 |
| L20 | error_warning | TC4 |
| L21 | error_passive | TC4 |
| L23-26 | last_error + stored (≠0,≠7) | TC2, TC4(==0), TC5 |
| L28-31 | last_data_error + stored | TC4(==0) |
| L33 | receive_error_cnt | TC2 |
| L34 | transmit_error_cnt | TC2, TC5 |
| L36-37 | irq call rates | ✅ 读取中断数组 (值为0) |
| L39 | ir_reg != 0 guard | TC2(false), TC5(true), TC6(true) |
| L41 | FDCANx->IR |= ... | ✅ TC5/TC6 写入假寄存器 |
| L42 | total_error_cnt += 1 | TC5, TC6 |
| L44-46 | RF0L → total_rx_lost_cnt | TC6 |
| L50-53 | can_clear_send 条件 | TC5 (条件成立) |

✅ 所有代码行已覆盖。

## 5. 覆盖检查

| 条件 | TC1 | TC2 |
|------|-----|-----|
| param1 < 3 (valid) | ✅ | — |
| param1 >= 3 (invalid) | — | ✅ |

✅ 所有代码路径已覆盖。
