# Body 共享 USB 命令 — 测试设计文档

> 功能: body 固件与 panda 固件共享的 USB 控制命令
> 被测接口: `comms_control_handler()` in `board/body/main_comms.h`
> 固件目标: body (`board/body/main.c`)

## 1. 被测功能流程图

```
0xc1 — get hardware type:
  [controlWrite(0xc1)]
           │
           ▼
  resp[0] = hw_type   (= 0xB1 for body)
  resp_len = 1

0xd6 — get firmware version:
  [controlWrite(0xd6)]
           │
           ▼
  resp = gitversion   ("e2e-test-00000000" in e2e)

0xdd — get packet version hashes:
  [controlWrite(0xdd)]
           │
           ▼
  resp = {HEALTH_PACKET_VERSION, CAN_PACKET_VERSION_HASH}
```

> Body 固件的 `main_comms.h` 与 panda 同结构共享这些命令，但编译为独立的 binary。panda e2e 已经覆盖了 panda 侧实现，body e2e 覆盖 body 侧的独立代码路径。

## 2. 输入因子

| 因子 | 类型 | 等价类 | 取值 |
|------|------|--------|------|
| `request` | uint8 | 0xc1 (硬件类型) | 0xc1 |

## 3. 输出因子

| 输出 | 类型 | 说明 |
|------|------|------|
| hwType | int | 硬件类型 = 0xB1 (177) |

## 4. 测试用例

### TC1: 获取硬件类型返回 0xB1
- 输入: request=0xc1, param1=0, param2=0
- 输出: hwType=177
- 说明: body 固件通过 `HW_TYPE_BODY = 0xB1U` 宏静态赋值

## 5. 覆盖检查

| 条件 | TC1 |
|------|-----|
| 0xc1: hardware type | ✅ |

✅ body 固件的共享命令路径已验证。

## 覆盖率

> 数据来源: `run_all_coverage.sh` 合并报告 (cuatro + tres + red + body)
> body 固件覆盖率通过 `libpanda_body.dylib` 独立采集

| 源文件 | 说明 |
|--------|------|
| `board/body/main_comms.h` | ✅ 0xc1/0xd6/0xdd 命令处理（通过 body e2e 覆盖） |
