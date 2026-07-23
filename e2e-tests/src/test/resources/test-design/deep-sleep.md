# 深度休眠请求 — 测试设计文档

> 功能: request deep sleep via `comms_control_handler()` in `board/main_comms.h`
> 被测接口: USB control request 0xb5 (DEBUG: enter silent + stop mode)
> 条件: `#ifdef ALLOW_DEBUG`（e2e 构建已启用）

## 1. 被测功能流程图

```
request deep sleep (0xb5):
  [controlWrite(0xb5, 0, 0)]
           │
           ▼
  set_safety_mode(SAFETY_SILENT, 0)
           │
           ▼
  set_power_save_state(true)
           │
           ▼
  stop_mode_requested = true
           │
           ▼
        (done)
```

代码路径为直线，无分支。

## 2. 输入因子

| 因子 | 类型 | 等价类 | 取值 |
|------|------|--------|------|
| `request` | uint8 | 0xb5 (唯一) | 0xb5 |

## 3. 输出因子

| 输出 | 类型 | 说明 |
|------|------|------|
| safetyTxBlocked | int | SILENT 模式阻塞所有 TX |
| powerSaveEnabled | boolean | 省电模式已启用 |
| powerSaveTracking.irqDisableCount | int | llcan_irq_disable 调用次数 (=2) |
| stopModeRequested | boolean | stop_mode_requested=true |

## 4. 测试用例

### TC1: 触发深度休眠
- 前置: ALLOUTPUT 模式 (验证安全模式被切换为 SILENT)
- 输入: request=0xb5
- 输出: safetyTxBlocked=1 (SILENT 生效), powerSaveEnabled=true, irqDisableCount=2, stopModeRequested=true

## 5. 覆盖检查

| 条件 | TC1 |
|------|-----|
| request == 0xb5 (set_safety_mode 路径) | ✅ |
| request == 0xb5 (set_power_save_state 路径) | ✅ |
| request == 0xb5 (stop_mode_requested 路径) | ✅ |

✅ 所有代码路径已覆盖。
