# 系统复位 — 测试设计文档

> 功能: ST 复位 via `comms_control_handler()` in `board/main_comms.h`
> 被测接口: USB control request 0xd8 (reset ST)

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
```

代码路径为直线，无分支。`param1` 和 `param2` 未使用。真实硬件会触发系统复位，e2e 环境中 `NVIC_SystemReset` 被 stub，仅追踪调用次数。

## 2. 输入因子

| 因子 | 类型 | 等价类 | 取值 |
|------|------|--------|------|
| `request` | uint8 | 0xd8 (唯一) | 0xd8 |

## 3. 输出因子

| 输出 | 类型 | 说明 |
|------|------|------|
| nvicResetCount | int | NVIC_SystemReset 被调用的次数 |

## 4. 测试用例

### TC1: 触发系统复位
- 前置: 初始状态 (nvicResetCount=0)
- 输入: request=0xd8
- 输出: nvicResetCount=1

## 5. 覆盖检查

| 条件 | TC1 |
|------|-----|
| request == 0xd8 | ✅ |

✅ 代码路径已覆盖。
