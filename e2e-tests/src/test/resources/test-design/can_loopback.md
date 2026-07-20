# CAN Loopback 测试设计

## 被测功能

USB 控制请求 `0xe5` — 设置 CAN 回环模式（用于测试）。

入口：`board/main_comms.h` 的 `comms_control_handler`，case 0xe5：

```c
case 0xe5:
  can_loopback = req->param1 > 0U;
  can_init_all();
  break;
```

`can_init_all()` 清空所有 TX 队列并调用 `can_init(i)` 重初始化每个 CAN 总线。
`llcan_set_speed()` 根据 `can_loopback` 和 `can_silent` 配置 FDCAN 寄存器：
- loopback=true → CCCR.TEST=1, TEST.LBCK=1, CCCR.MON=1
- loopback=false → 清除 TEST/LBCK，MON 由 can_silent 决定

## 输入因子

| 因子 | 类型 | 取值说明 |
|------|------|----------|
| param1 | uint16_t | 回环模式开关：0=关闭，>0=开启 |

**等价类：**
- EQ1: `param1 = 0` — 关闭回环
- EQ2: `param1 > 0` — 开启回环（取 1）

**边界值：** 0, 1（紧邻比较运算符 `>` 的边界）

## 输出因子

| 因子 | 说明 | 验证方式 |
|------|------|----------|
| CCCR (byte[0]) | bit7=TEST, bit5=MON | fdcanRegs[N].cccr[0] |
| CCCR (byte[1]) | 标准配置 | fdcanRegs[N].cccr[1] |
| IE (中断使能) | 各 bus 的 IE 寄存器 | fdcanRegs<<0,1,2>>.ie |
| NBTP / DBTP | 标称/数据位时序 | fdcanRegs<<0,1,2>>.nbtp / .dbtp |
| TXBC / RXF0C | FIFO/队列配置 | fdcanRegs<<0,1,2>>.txbc / .rxf0c |
| TXESC / RXESC | 元素大小配置 | fdcanRegs<<0,1,2>>.txesc / .rxesc |
| GFC (全局过滤) | 过滤配置 | fdcanRegs<<0,1,2>>.gfc |
| ILE (中断线使能) | 中断线选择 | fdcanRegs<<0,1,2>>.ile |
| TX 队列 | can_init_all() 清空 | txQueue[0] |
| can_send 正常 | 回环使能后 CAN 发送不阻塞 | canSend 返回值 |

## 流程图

```
[case 0xe5] → param1 > 0?
                ├─ N → can_loopback = false → [can_init_all()] → CCCR.TEST=0, TEST.LBCK=0
                └─ Y → can_loopback = true  → [can_init_all()] → CCCR.TEST=1, TEST.LBCK=1, CCCR.MON=1
```

代码路径覆盖：
1. `param1 == 0`：执行分支 N，覆盖条件 `param1 > 0U` 为 false
2. `param1 == 1`：执行分支 Y，覆盖条件 `param1 > 0U` 为 true

两个等价类覆盖两条代码路径，条件分支的 true/false 均已覆盖。

## e2e 测试环境限制

e2e 测试环境中 `process_can()` 被 stub，FDCAN 硬件不存在，因此：
- **不支持**：CAN 消息从 TX 自动回环到 RX 队列
- **可验证**：FDCAN 寄存器配置（CCCR、TEST）、TX 队列清空行为、CAN 发送不阻塞

## 测试用例

| # | 用例名 (对应 feature 场景) | param1 | 前置状态 | 验证内容 | 说明 |
|---|---------------------------|--------|----------|----------|------|
| 1 | Enabling-loopback-sets-FDCAN-TEST-and-MON-bits | 1 | silent=true (默认) | cccr=0b1010_0000, ie/nbtp/dbtp/txbc/rxf0c/txesc/rxesc/gfc/ile 全部初始值 | 回环开启后 CCCR 置 TEST+MON，所有 FDCAN 寄存器被 can_init_all() 重初始化 |
| 2 | Disabling-loopback-clears-FDCAN-TEST-bit-but-keeps-MON-from-silent-mode | 0 | silent=true (默认) | cccr[0]=0x20 (MON only) | 回环关闭后 TEST 清除，MON 由 silent 模式保持 |
| 3 | Re-enabling-loopback-clears-existing-CAN-TX-queues | 1 | ALLOUTPUT, TX 队列有消息 | txQueue[0] 为空, rxQueue 为空, cccr=0b1010_0000 | can_init_all 清空已有 TX 消息并重初始化 FDCAN |
| 4 | CAN-send-still-works-after-loopback-is-enabled | 1 | ALLOUTPUT + loopback on | txQueue[0] 含 address=512 的发送消息 | 回环不影响 CAN 发送路径 |

**覆盖度验证：**
- 代码路径：param1=0 (用例2) + param1>0 (用例1,3,4) ✓
- 条件分支：`param1 > 0U` 的 true (用例1) 和 false (用例2) 均覆盖 ✓
- 等价类：EQ1 (用例2) + EQ2 (用例1,3,4) ✓
- 边界值：0 (用例2) + 1 (用例1,3,4) ✓
- FDCAN 寄存器全面验证：用例1 覆盖 can_init_all() 对三总线所有寄存器的初始化 ✓

## 实现要点

- 由于 JFactory 在同一 scenario 内不会自动清除状态，多步 `control write` 场景中 `jFactory.type(...).query()` 会返回第一步创建的对象，导致后续步骤使用错误数据。
- **修复**：在 `SafetyModeSteps.controlWriteWithExpression()` 开始时调用 `jFactory.clear()`。
- feature 文件中使用显式 `UsbControlRequest: { request: -27y, param1: 1, param2: 0 }` 形式，不依赖 Spec 别名，确保 request 字段值明确。
- Java signed byte 的限制：`0xA0`（160）超出 signed byte 范围（-128~127），需使用 `-96y`（signed 表示）而非 `0b1010_0000y` 或 `0xA0y`。
