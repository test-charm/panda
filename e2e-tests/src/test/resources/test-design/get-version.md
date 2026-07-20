# 固件版本读取 — 测试设计文档

> 功能: get version via `comms_control_handler()` in `board/main_comms.h`
> 被测接口: USB control request 0xd6 (get version)

## 1. 被测功能流程图

```
get version (0xd6):
  [controlWrite(0xd6, 0, 0)]
           │
           ▼
  memcpy(resp, gitversion, sizeof(gitversion))
  resp_len = sizeof(gitversion) - 1
           │
           ▼
        (done)
```

代码路径为直线，无分支。`param1` 和 `param2` 未使用。返回 `gitversion` 字符串到 response buffer。

## 2. 输入因子

| 因子 | 类型 | 等价类 | 取值 |
|------|------|--------|------|
| `request` | uint8 | 0xd6 (唯一) | 0xd6 |

## 3. 输出因子

| 输出 | 类型 | 说明 |
|------|------|------|
| gitversion | String | 固件版本字符串 (e2e 环境: "00000000") |

## 4. 测试用例

### TC1: 读取固件版本
- 前置: 初始状态
- 输入: request=0xd6
- 输出: gitversion="00000000"
- 路径: memcpy → 返回 gitversion 字符串

## 5. 覆盖检查

| 条件 | TC1 |
|------|-----|
| request == 0xd6 | ✅ |

✅ 代码路径已覆盖。
