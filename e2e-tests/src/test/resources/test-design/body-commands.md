# Body 电机命令 — 测试设计文档

> 功能: `comms_control_handler()` in `board/body/main_comms.h`
> 被测接口: USB control request 0xb3 (电机转速) + 0xb4 (电机启停)
> 固件目标: body (`board/body/main.c`)

## 1. 被测功能流程图

```
0xb3 — set motor speed:
  [controlWrite(0xb3, param1, param2)]
           │
           ▼
  rpm_left  = (int16)param1
  rpm_right = (int16)param2

0xb4 — enable/disable motors:
  [controlWrite(0xb4, param1)]
           │
      ┌────┴────┐
   param1=1   param1=0
      │          │
      ▼          ▼
  enable_motors=1  enable_motors=0
                    rpm_left=0
                    rpm_right=0
```

> **输出因子**: `rpmLeft`, `rpmRight`, `motorEnabled` — body 固件全局变量（JNA 直接读取）

## 2. 输入因子

| 因子 | 类型 | 等价类 | 取值 |
|------|------|--------|------|
| `request` | uint8 | 0xb3 (转速), 0xb4 (启停) | 0xb3, 0xb4 |
| `param1` (0xb3) | int16 | 正转速, 零, 负转速 | 100, 50, -30 |
| `param2` (0xb3) | int16 | 右轮转速 | 200, 0 |
| `param1` (0xb4) | uint16 | 1 (启用), 0 (禁用) | 0, 1 |

## 3. 输出因子

| 输出 | 类型 | 说明 |
|------|------|------|
| rpmLeft | int | 左轮目标转速 (rpm) |
| rpmRight | int | 右轮目标转速 (rpm) |
| motorEnabled | bool | 电机启用状态 |

## 4. 测试用例

### TC1: 设置左右电机转速
- 输入: request=0xb3, param1=100, param2=200
- 输出: rpmLeft=100, rpmRight=200

### TC2: 电机默认禁用
- 输入: 无（固件初始状态）
- 输出: motorEnabled=false

### TC3: 启用电机
- 输入: request=0xb4, param1=1
- 输出: motorEnabled=true

### TC4: 禁用电机
- 输入: 先 0xb4 param1=1（启用），再 0xb4 param1=0（禁用）
- 输出: motorEnabled=false

### TC5: 禁用电机清零转速
- 输入: 0xb4 param1=1 → 0xb3 param1=50 param2=-30 → 0xb4 param1=0
- 输出: rpmLeft=0, rpmRight=0, motorEnabled=false
- 说明: `enable_motors=0` 时 `rpm_left=0; rpm_right=0` 逻辑在命令处理中执行

## 5. 覆盖检查

| 条件 | TC1 | TC2 | TC3 | TC4 | TC5 |
|------|-----|-----|-----|-----|-----|
| 0xb3: 设置目标转速 | ✅ | — | — | — | ✅ |
| 0xb4: 启用 | — | — | ✅ | ✅ | ✅ |
| 0xb4: 禁用 | — | — | — | ✅ | ✅ |
| 初始状态禁用 | — | ✅ | — | — | — |
| 禁用时清零转速 | — | — | — | — | ✅ |

✅ 所有命令路径和状态转换已覆盖。

## 覆盖率

> 数据来源: `run_all_coverage.sh` 合并报告 (cuatro + tres + red + body)
> body 固件覆盖率通过 `libpanda_body.dylib` 独立采集

| 源文件 | 说明 |
|--------|------|
| `board/body/main_comms.h` | ✅ 0xb3/0xb4 命令处理（覆盖） |
| `board/body/main.c` | body 主固件（USB 命令路径覆盖，主循环/GPIO 初始化因 e2e 无硬件主循环未覆盖） |
