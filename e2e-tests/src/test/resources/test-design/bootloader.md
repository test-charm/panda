# Bootloader 模式进入 — 测试设计文档

> 功能: enter bootloader mode via `comms_control_handler()` in `board/main_comms.h`
> 被测接口: USB control request 0xd1 (enter bootloader mode)

## 1. 被测功能流程图

```
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
| `request` | uint8 | 0xd1 (唯一) | 0xd1 |
| `param1` | uint16 | 0 (bootloader) | 0 |
| `param1` | uint16 | 1 (softloader) | 1 |
| `param1` | uint16 | 其他 (invalid) | 2 |

## 3. 输出因子（副作用）

| 输出 | 类型 | 说明 |
|------|------|------|
| nvicResetCount | int | NVIC_SystemReset 调用次数 |
| enterBootloaderMode | int | ENTER_BOOTLOADER_MAGIC(1) / ENTER_SOFTLOADER_MAGIC(2) / 0 |

## 4. 测试用例

### TC1: param1=0 → 触发 bootloader 复位
- 输入: request=0xd1, param1=0
- 输出: nvicResetCount=1, enterBootloaderMode=1

### TC2: param1=1 → 触发 softloader 复位
- 输入: request=0xd1, param1=1
- 输出: nvicResetCount=1, enterBootloaderMode=2

### TC3: param1=2 → 无效，无复位
- 输入: request=0xd1, param1=2
- 输出: nvicResetCount=0, enterBootloaderMode=0

## 5. 覆盖检查

| 条件 | TC1 | TC2 | TC3 |
|------|:--:|:--:|:--:|
| param1 == 0 | ✅ | — | — |
| param1 == 1 | — | ✅ | — |
| param1 == default | — | — | ✅ |

✅ 所有分支已覆盖。
