# SOM GPIO 读取 — 测试设计文档

> 功能: read SOM GPIO via `comms_control_handler()` in `board/main_comms.h`
> 被测接口: USB control request 0xc6 (DEBUG: read SOM GPIO)

## 1. 被测功能流程图

```
read SOM GPIO (0xc6):
  [controlWrite(0xc6, 0, 0)]
           │
           ▼
  resp[0] = current_board->read_som_gpio()
  resp_len = 1
           │
           ▼
        (done)
```

代码路径为直线，无分支。`param1` 和 `param2` 未使用。

## 2. 输入因子

| 因子 | 类型 | 等价类 | 取值 |
|------|------|--------|------|
| `request` | uint8 | 0xc6 (唯一) | 0xc6 |
| `som_gpio_value` (前置) | bool | true (1), false (0) | 1 |

## 3. 输出因子

| 输出 | 类型 | 说明 |
|------|------|------|
| respBuffer.len | int | resp_len = 1 |
| respBuffer.bytes[0] | byte | GPIO 值 (0 或 1) |

## 4. 测试用例

### TC1: 预设 SOM GPIO=1 → 通过 handler 写 resp buffer
- 前置: 设 `som_gpio_value = true`
- 输入: request=0xc6
- 输出: resp_len=1, bytes[0]=1

## 5. 覆盖检查

| 条件 | TC1 |
|------|-----|
| request == 0xc6 | ✅ |

✅ 代码路径已覆盖。
