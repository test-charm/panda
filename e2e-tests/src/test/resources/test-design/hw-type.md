# 硬件类型读取 — 测试设计文档

> 功能: get hardware type via `comms_control_handler()` in `board/main_comms.h`
> 被测接口: USB control request 0xc1 (get hardware type)

## 1. 被测功能流程图

```
get hardware type (0xc1):
  [controlWrite(0xc1, 0, 0)]
           │
           ▼
  resp[0] = hw_type
  resp_len = 1
           │
           ▼
        (done)
```

## 2. 输入因子

| 因子 | 类型 | 等价类 | 取值 |
|------|------|--------|------|
| `request` | uint8 | 0xc1 (唯一) | 0xc1 |
| `hw_type` (前置) | uint8 | 非零值 | 171 (0xAB) |

## 3. 输出因子

| 输出 | 类型 | 说明 |
|------|------|------|
| respBuffer.len | int | resp_len = 1 |
| respBuffer.bytes[0] | byte | 0xAB (-85) |

## 4. 测试用例

### TC1: 预设 hw_type → 通过 handler 写 resp buffer
- 前置: 设 hw_type=171 (0xAB)
- 输入: request=0xc1
- 输出: resp_len=1, bytes[0]=0xAB

## 5. 覆盖检查

| 条件 | TC1 |
|------|-----|
| request == 0xc1 | ✅ |

✅ 代码路径已覆盖。

## 覆盖率

> 数据来源: `run_all_coverage.sh` 合并报告 (cuatro + tres + red)
> 综合行覆盖率: **65.1%** (全量), 本功能涉及以下源文件:

| 源文件 | 行覆盖 | 说明 |
|--------|--------|------|
| `main_comms.h` | 93.3% (251/269) | USB 命令处理 |

