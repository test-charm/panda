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

## 2. 输入因子

| 因子 | 类型 | 等价类 | 取值 |
|------|------|--------|------|
| `request` | uint8 | 0xd6 (唯一) | 0xd6 |
| `gitversion` (前置) | char[64] | 任意 8-char 字符串 | "abcdef01" |

## 3. 输出因子

| 输出 | 类型 | 说明 |
|------|------|------|
| respBuffer.len | int | resp_len = 63 |
| respBuffer.bytes[0..7] | List\<Byte\> | 前 8 字节为 gitversion 字符 |

## 4. 测试用例

### TC1: 预设版本 → handler 路径验证 resp buffer
- 前置: 设 gitversion="abcdef01"
- 输入: request=0xd6
- 输出: resp_len=63, bytes[0..7]=97,98,99,100,101,102,48,49

## 5. 覆盖检查

| 条件 | TC1 |
|------|-----|
| request == 0xd6 | ✅ |

✅ 代码路径已覆盖。
