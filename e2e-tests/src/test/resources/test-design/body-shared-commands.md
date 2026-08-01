# Body 共享 USB 命令 — 测试设计文档

> 功能: body 固件与 panda 固件共享的 USB 控制命令
> 被测接口: `comms_control_handler()` in `board/body/main_comms.h`
> 固件目标: body (`board/body/main.c`)
> 已完成: B1-B7 (2026-08-01)

## 1. 被测功能流程图

```
0xc1 — get hardware type:
  [controlWrite(0xc1)] → resp[0] = hw_type (0xB1), resp_len = 1

0xd6 — get firmware version:
  [controlWrite(0xd6)] → resp = gitversion[0..17] ("e2e-test-00000000"), resp_len = 18

0xdd — get packet version hashes:
  [controlWrite(0xdd)] → resp = {HEALTH_PACKET_VERSION, CAN_PACKET_VERSION_HASH} (8B LE), resp_len = 8

0xd8 — reset ST:
  [controlWrite(0xd8)] → NVIC_SystemReset() → nvicResetCount++

0xd3 — firmware signature (offset=0):
  [controlWrite(0xd3)] → resp = _app_start[code_len+0..code_len+63], resp_len = 64

0xd4 — firmware signature (offset=64):
  [controlWrite(0xd4)] → resp = _app_start[code_len+64..code_len+127], resp_len = 64

0xd1 — enter bootloader / softloader:
  [controlWrite(0xd1, param1)]
       │
   ┌───┴────┬────────┐
  param1=0  param1=1  default
     │         │         │
     ▼         ▼         ▼
  BOOTLOADER SOFTLOADER no-op
  magic=1    magic=2
     │         │
     ▼         ▼
  NVIC_SystemReset()
```

> Body 固件的 `main_comms.h` 与 panda 同结构共享 0xd1/0xd3/0xd4/0xd6/0xd8/0xdd 命令，但编译为独立的 binary。panda e2e 已经覆盖了 panda 侧实现，body e2e 覆盖 body 侧的独立代码路径。

## 2. 输入因子

| 因子 | 类型 | 等价类 | 取值 |
|------|------|--------|------|
| `request` | uint8 | 0xc1, 0xd1, 0xd3, 0xd4, 0xd6, 0xd8, 0xdd | 见测试用例 |
| `param1` (0xd1) | uint16 | 0 (bootloader), 1 (softloader), other | 0, 1 |
| `codeLen` (0xd3/0xd4 前置) | int | 签名区域偏移 | 16 |
| `signatureChunk0` (0xd3 前置) | hex string | 64 字节签名数据 | "AA"×32 + "BB"×32 |
| `signatureChunk1` (0xd4 前置) | hex string | 64 字节签名数据 | "CC"×32 + "DD"×32 |

## 3. 输出因子

| 输出 | 类型 | 说明 |
|------|------|------|
| hwType | int | 硬件类型 = 0xB1 (177) |
| respBuffer | RespBuffer | 命令响应字节数组 + 长度 |
| nvicResetCount | int | NVIC 复位调用次数 |
| enterBootloaderMode | int | 0=无, 1=bootloader, 2=softloader |

## 4. 测试用例

### TC1: 获取硬件类型返回 0xB1
- 输入: request=0xc1, param1=0, param2=0
- 输出: hwType=177
- 说明: body 固件通过 `HW_TYPE_BODY = 0xB1U` 宏静态赋值

### TC2 (B1): 获取固件版本返回 git commit hash
- 输入: request=0xd6, param1=0, param2=0
- 输出: respBuffer.len=18, bytes="e2e-test-00000000"
- 说明: `memcpy(resp, gitversion, sizeof(gitversion)); resp_len = sizeof(gitversion) - 1`

### TC3 (B2): 获取数据包版本号
- 输入: request=0xdd, param1=0, param2=0
- 输出: respBuffer.len=8, bytes={0xE29D3FF6, 0x76F2AB75} (LE)
- 说明: `uint32_t versions[2] = {HEALTH_PACKET_VERSION, CAN_PACKET_VERSION_HASH}`

### TC4 (B3): 系统复位触发 NVIC_SystemReset
- 输入: request=0xd8, param1=0, param2=0
- 输出: nvicResetCount=1
- 说明: NVIC_SystemReset 在 e2e 中替换为计数器

### TC5 (B4): 获取固件签名前 64 字节
- 前置: `body setup write: {codeLen: 16, signatureChunk0: "AA"×32+"BB"×32}`
- 输入: request=0xd3, param1=0, param2=0
- 输出: respBuffer.len=64, bytes[0]=0xAA, bytes[31]=0xAA, bytes[32]=0xBB, bytes[63]=0xBB
- 说明: `memcpy(resp, &code[code_len + 0], 64)` — 使用 body setup write 预置非零签名数据

### TC6 (B5): 获取固件签名后 64 字节
- 前置: `body setup write: {codeLen: 16, signatureChunk1: "CC"×32+"DD"×32}`
- 输入: request=0xd4, param1=0, param2=0
- 输出: respBuffer.len=64, bytes[0]=0xCC, bytes[31]=0xCC, bytes[32]=0xDD, bytes[63]=0xDD
- 说明: `memcpy(resp, &code[code_len + 64], 64)` — 使用 body setup write 预置非零签名数据

### TC7 (B6): 进入 bootloader 模式
- 输入: request=0xd1, param1=0, param2=0
- 输出: nvicResetCount=1, enterBootloaderMode=1
- 说明: `enter_bootloader_mode = ENTER_BOOTLOADER_MAGIC; NVIC_SystemReset()`

### TC8 (B7): 进入 softloader 模式
- 输入: request=0xd1, param1=1, param2=0
- 输出: nvicResetCount=1, enterBootloaderMode=2
- 说明: `enter_bootloader_mode = ENTER_SOFTLOADER_MAGIC; NVIC_SystemReset()`

## 5. 覆盖检查

| 条件 | TC1 | TC2 | TC3 | TC4 | TC5 | TC6 | TC7 | TC8 |
|------|-----|-----|-----|-----|-----|-----|-----|-----|
| 0xc1: hardware type | ✅ | — | — | — | — | — | — | — |
| 0xd6: firmware version | — | ✅ | — | — | — | — | — | — |
| 0xdd: packet versions | — | — | ✅ | — | — | — | — | — |
| 0xd8: reset ST | — | — | — | ✅ | — | — | — | — |
| 0xd3: signature offset 0 | — | — | — | — | ✅ | — | — | — |
| 0xd4: signature offset 64 | — | — | — | — | — | ✅ | — | — |
| 0xd1: bootloader | — | — | — | — | — | — | ✅ | — |
| 0xd1: softloader | — | — | — | — | — | — | — | ✅ |

✅ body 固件 8 个共享命令路径全部验证。`main_comms.h` 覆盖率 86.4% (57/66 行)。

## 覆盖率

> 数据来源: `run_all_coverage.sh` 合并报告 (cuatro + tres + red + body)
> body 固件覆盖率通过 `libpanda_body.dylib` 独立采集

| 源文件 | 行覆盖 | 说明 |
|--------|--------|------|
| `board/body/main_comms.h` | 86.4% (57/66) | 0xc1/0xd1/0xd3/0xd4/0xd6/0xd8/0xdd 全部 8 个命令覆盖 |
