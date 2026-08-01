# Body CAN 通信 — 测试设计文档

> 功能: `body_can_*()` in `board/body/can.h`
> 被测接口: `jna_panda_init()` → `body_can_init()` (B13 启动路径); `jna_body_can_send_*()` / `jna_body_can_receive_target()` / `jna_body_can_periodic()` (B14-B17)
> 固件目标: body (`board/body/main.c`)
> 已完成: B13-B17 (2026-08-01)

## 1. 被测功能流程图

```
jna_panda_init() (body 固件启动模拟)
     │
     ▼
body_can_init()
     │
     ├─ last_can_cmd_timestamp_us = 0
     ├─ can_silent = false
     ├─ can_loopback = false
     ├─ set_safety_hooks(SAFETY_BODY, 0)
     ├─ set_gpio_output(CAN_TRANSCEIVER_EN, 0)      — 使能 CAN 收发器
     └─ can_init_all()                              — 初始化 FDCAN

body_can_send_motor_speeds(bus, left, right)
     │
     └─ 0x201: [left_hi, left_lo, right_hi, right_lo, 0, 0, counter, checksum]

body_can_send_var_values(bus, ignition, enable, fault, left_err, right_err)
     │
     └─ 0x202: [flags, left_err, right_err]

body_can_send_body_data(bus, temp, voltage, percentage, charging)
     │
     └─ 0x203: [temp, voltage_hi, voltage_lo, charging|(percentage<<1)]

body_can_rx(msg addr=0x250)
     │
     ├─ 解析 left/right target (deci-rpm)
     └─ body_can_process_target()
           ├─ rpm_left  = left_target / 10
           ├─ rpm_right = right_target / 10
           └─ last_can_cmd_timestamp_us = microsecond_timer_get()

body_can_periodic(now, ignition, charging)
     │
     ├─ [命令超时?] now-last >= 100ms → rpm_left=0, rpm_right=0, last_can_cmd_timestamp_us=0
     │
     └─ [距离上次发送 ≥ 10ms?]
           ├─ 发送 0x201 电机转速
           ├─ 发送 0x202 状态变量
           ├─ 发送 0x203 电池数据
           └─ 发送 0x222 body v2 ID
```

> **e2e 特性**: `can_send(..., skip_tx_hook=true)` 会立即 `process_can()`，并把发送出去的帧以 `returned=true` 的形式回灌到 `rxQueue`。因此 B14/B17 在测试中断言的是 `rxQueue`，不是硬件 TX FIFO。
> **B13 融合方式**: `body_can_init()` 已并入 `body_bldc.feature` 的启动场景 `B8/B13`，不再保留单独 feature 场景。

## 2. 输入因子

| 因子 | 类型 | 等价类 | 取值 |
|------|------|--------|------|
| `left_speed_rpm` | float/int | 正值 | 300 |
| `right_speed_rpm` | float/int | 正值（编码时取反） | 150 |
| `ignition` | bool | false / true | false, true |
| `enable_motors` | bool | false / true | false, true |
| `fault` | uint8 | 6 bit 故障位 | 5 |
| `left_z_errcode` / `right_z_errcode` | uint8 | 非零错误码 | 7, 9 |
| `mcu_temp_raw` | uint8 | 普通值 | 42 |
| `batt_voltage_raw` | uint16 | 非零值 | 4660 (0x1234) |
| `batt_percentage` | uint8 | 普通值 | 80 |
| `charger_connected` | bool | false / true | false, true |
| `left_target_rpm` / `right_target_rpm` | int | 正值 / 负值 | 123, -45 |
| `now_us` | uint32 | 超时前 / 超时后 / 周期边界 | 1000, 10000, 15000, 20000, 101000 |

## 3. 输出因子

| 输出 | 类型 | 说明 |
|------|------|------|
| `bodyCan.canSilent` | bool | `body_can_init()` 后应为 false |
| `bodyCan.canLoopback` | bool | `body_can_init()` 后应为 false |
| `bodyCan.bodySafetyHooksSet` | bool | 当前安全模式应为 `SAFETY_BODY` |
| `bodyCan.canTransceiverEnabled` | bool | CAN 收发器使能脚应为 output low |
| `bodyCan.lastCanCmdTimestampUs` | int | 最近一次接收电机目标的时间戳 |
| `rpmLeft` / `rpmRight` | int | 电机目标转速（rpm） |
| `rxQueue` | `AdaptiveList<CanMessage>` | e2e 中发送出去的 body CAN 帧回显队列 |

## 4. 测试用例

### TC1 (B13, 合并到 body_bldc.feature): 启动时完成 body CAN 初始化
- 前置: 无（`jna_panda_init()` 自动执行）
- 输出:
  - `bodyCan.canSilent=false`
  - `bodyCan.canLoopback=false`
  - `bodyCan.bodySafetyHooksSet=true`
  - `bodyCan.canTransceiverEnabled=true`
- 验证方式: 读取 `BodyCanState`

### TC2 (B14): 发送 helper 生成 0x201 / 0x202 / 0x203 三类帧
- 步骤:
  1. `body_can_send_motor_speeds(300, 150)`
  2. `body_can_send_var_values(true, true, 5, 7, 9)`
  3. `body_can_send_body_data(42, 0x1234, 80, true)`
- 输出:
  - `rxQueue[0].address=0x201`, data=`[0x01, 0x2C, 0xFF, 0x6A, 0x00, 0x00, 0x00, 0x00]`
  - `rxQueue[1].address=0x202`, data=`[0x17, 0x07, 0x09]`
  - `rxQueue[2].address=0x203`, data=`[0x2A, 0x12, 0x34, 0xA1]`（DAL 中最后一字节表现为 `-95`）

### TC3 (B15): 接收 0x250 目标转速帧后正确更新 rpm 与时间戳
- 前置: `body can set microsecond timer: 54321`
- 步骤: `body can receive target: left = 123 rpm, right = -45 rpm`
- 输出:
  - `rpmLeft=123`
  - `rpmRight=-45`
  - `bodyCan.lastCanCmdTimestampUs=54321`

### TC4 (B16): 100ms 超时后将目标转速归零
- 前置:
  1. `body can set microsecond timer: 1000`
  2. `body can receive target: left = 100 rpm, right = 50 rpm`
- 步骤: `body can periodic: now_us = 101000, ignition = true, charging = false`
- 输出:
  - `rpmLeft=0`
  - `rpmRight=0`
  - `bodyCan.lastCanCmdTimestampUs=0`

### TC5 (B17): 周期发送 10ms 节流
- 步骤:
  1. `body can periodic: now_us = 10000, ignition = true, charging = true`
  2. `body can periodic: now_us = 15000, ignition = true, charging = true`
  3. `body can periodic: now_us = 20000, ignition = true, charging = true`
- 输出:
  - 第 1 次：`rxQueue` 中有 `0x201/0x202/0x203/0x222`
  - 第 2 次：`rxQueue=[]`
  - 第 3 次：再次发送 `0x201` 与 `0x222`（feature 仅抽样断言索引 0 和 3）

## 5. 覆盖检查

| 条件 | TC1 | TC2 | TC3 | TC4 | TC5 |
|------|-----|-----|-----|-----|-----|
| `body_can_init()` | ✅ | — | — | — | — |
| `can_silent=false` / `can_loopback=false` | ✅ | — | — | — | — |
| `set_safety_hooks(SAFETY_BODY)` | ✅ | — | — | — | — |
| CAN 收发器使能 GPIO | ✅ | — | — | — | — |
| `body_can_send_motor_speeds()` | — | ✅ | — | — | ✅ |
| `body_can_send_var_values()` | — | ✅ | — | — | ✅ |
| `body_can_send_body_data()` | — | ✅ | — | — | ✅ |
| 0x222 body v2 ID 帧 | — | — | — | — | ✅ |
| `body_can_rx()` / `body_can_process_target()` | — | — | ✅ | ✅ | — |
| 超时归零路径 | — | — | — | ✅ | — |
| `<10ms` 不发送 | — | — | — | — | ✅ |
| `>=10ms` 发送 | — | — | — | — | ✅ |

✅ `board/body/can.h` 7 个函数 + 0x222 v2 ID 发送路径已全部覆盖。

## 6. 与生产固件的关系

在生产固件 `board/body/main.c` 中：
```c
void body_main(void) {
  // ... 硬件初始化 ...
  body_can_init();       // line 115
  dotstar_init();        // line 116
  bldc_init();           // line 117

  while (true) {
    // ...
    if (ignition) {
      motor_set_enable(true);
      body_can_periodic(now, ignition, plug_charging);
    } else {
      motor_set_enable(false);
    }
    // ...
  }
}
```

e2e 环境中：
1. `jna_panda_init()` 模拟启动序列，先覆盖 `body_can_init()`
2. `body_can_send_*()` / `body_can_rx()` / `body_can_periodic()` 通过独立 JNA 入口直接调用
3. 这样无需执行 `while(true)` 主循环，也能覆盖 CAN 子系统全部可测逻辑

## 覆盖率

> 数据来源: `COVERAGE=1 ./gradlew cucumberCoverage -Pboard=body -Ptags='@body'` (2026-08-01)

| 源文件 | 行覆盖 | 函数覆盖 | 说明 |
|--------|--------|---------|------|
| `board/body/can.h` | 100.00% (82/82) | 100.00% (7/7) | ✅ B13-B17 全覆盖；仅 4 个分支未命中，分支覆盖 75.00% |
