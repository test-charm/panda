# 系统复位与 Bootloader 模式 — 测试设计文档

> 功能: NVIC 系统复位 (0xd8) + bootloader/softloader 模式进入 (0xd1)
> 被测接口: USB control request 0xd8 (reset ST) / 0xd1 (enter bootloader mode)
> 合并自: `reset-st.md` + `bootloader.md` (第十三节 D4+D5 合并)

## 1. 被测功能流程图

```
reset ST (0xd8):
  [controlWrite(0xd8, 0, 0)]
           │
           ▼
  NVIC_SystemReset()
           │
           ▼
        (done)

enter bootloader (0xd1):
  [controlWrite(0xd1, param1, 0)]
           │
           ▼
  switch (param1):
     ├── 0: enter_bootloader_mode = ENTER_BOOTLOADER_MAGIC
     │       NVIC_SystemReset()
     ├── 1: enter_bootloader_mode = ENTER_SOFTLOADER_MAGIC
     │       NVIC_SystemReset()
     └── default: print("invalid"), nothing
```

## 2. 输入因子

| 因子 | 类型 | 等价类 | 取值 |
|------|------|--------|------|
| `request` | uint8 | 0xd8 (reset) | 0xd8 |
| `request` | uint8 | 0xd1 (bootloader) | 0xd1 |
| `param1` (仅 0xd1) | uint16 | 0 (bootloader) | 0 |
| `param1` (仅 0xd1) | uint16 | 1 (softloader) | 1 |
| `param1` (仅 0xd1) | uint16 | 其他 (invalid) | 2 |

## 3. 输出因子（副作用）

| 输出 | 类型 | 说明 |
|------|------|------|
| nvicResetCount | int | NVIC_SystemReset 调用次数 |
| enterBootloaderMode | int | ENTER_BOOTLOADER_MAGIC(1) / ENTER_SOFTLOADER_MAGIC(2) / 0 |

## 4. 测试用例

### TC1: 触发系统复位 (0xd8)
- 前置: 初始状态 (nvicResetCount=0)
- 输入: request=0xd8
- 输出: nvicResetCount=1

### TC2: param1=0 → 触发 bootloader 复位 (0xd1)
- 输入: request=0xd1, param1=0
- 输出: nvicResetCount=1, enterBootloaderMode=1

### TC3: param1=1 → 触发 softloader 复位 (0xd1)
- 输入: request=0xd1, param1=1
- 输出: nvicResetCount=1, enterBootloaderMode=2

### TC4: param1=2 → 无效，无复位 (0xd1)
- 输入: request=0xd1, param1=2
- 输出: nvicResetCount=0, enterBootloaderMode=0

## 5. 覆盖检查

### 0xd8 (reset)
| 条件 | TC1 |
|------|:--:|
| request == 0xd8 | ✅ |

### 0xd1 (bootloader)
| 条件 | TC2 | TC3 | TC4 |
|------|:--:|:--:|:--:|
| param1 == 0 | ✅ | — | — |
| param1 == 1 | — | ✅ | — |
| param1 == default | — | — | ✅ |

✅ 所有分支已覆盖。

## 覆盖率

> 数据来源: `run_all_coverage.sh` 合并报告 (cuatro + tres + red)

| 源文件 | 行覆盖 | 说明 |
|--------|--------|------|
| `main_comms.h` | 95.5% (257/269) | USB 命令处理 |
