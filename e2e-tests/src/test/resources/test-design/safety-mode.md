# 安全模式切换 — 测试设计文档

> 功能: `set_safety_mode()` in `board/main.c` (lines 41-89)
> 被测接口: USB control request 0xdc (Panda.set_safety_mode)

## 1. 被测功能流程图

```
set_safety_mode(mode, param)
        │
        ▼
  set_safety_hooks(mode, param)
        │
   ┌────┴────────┐
   │ set_hooks   │──err→ mode=SILENT, set_safety_hooks(SILENT,0)
   │ returns -1? │        assert_fatal  if  SILENT  also  fails
   └────┬────────┘        (this is a terminal error path)
        │ ok
        ▼
   safety_tx_blocked = 0
   safety_rx_invalid = 0
        │
        ▼
   switch(mode_copy)
   ┌────┼───────────┬───────────┬────────────┐
   │    │           │           │            │
 SILENT NOOUTPUT   ELM327     ALLOUTPUT    car_safety
 (0)   (19)        (3)        (17)        (HONDA=32,
   │    │           │           │          TOYOTA=16...)
   │    │      ┌────┴────┐      │            │
   │    │   param=0?  param≠0   │            │
   │    │   OBD_CAN2  NORMAL    │            │
   │    │      │         │      │            │
   ▼    ▼      ▼         ▼      ▼            ▼
relay: off  off       off      off          on
CAN: normal normal    normal   normal       normal
silent: T   F        F        F            F
heartbeat:  -   -    reset     -           reset
can_clear:  -   -    bus1      -           -
        │    │      │         │            │
        └────┴──────┴─────────┴────────────┘
                      │
                      ▼
               can_init_all()
```

## 2. 输入因子

| 因子 | 类型 | 等价类 | 边界值 |
|------|------|--------|--------|
| `mode` | uint16 | SILENT(0), NOOUTPUT(19), ELM327(3), ALLOUTPUT(17), 车辆特定模式(e.g. TOYOTA=16), 无效模式(不在安全模型范围内) | 0, 1, 2, 3, 16, 17, 19, 32, 0xFFFF |
| `param` | uint16 | 仅 ELM327 区分: param=0 (OBD_CAN2), param≠0 (NORMAL) | 0, 1 |

## 3. 输出因子 (通过 health 控制请求 0xd2 观测)

| 输出 | 类型 | 含义 |
|------|------|------|
| `safety_mode` | uint8 (offset 36) | 当前安全模式 |
| `safety_tx_blocked` | uint32 (offset 12) | 安全 hook 阻断的发送计数 |
| `heartbeat_lost` | uint8 (offset 41) | 心跳是否丢失 |
| CAN 发送行为 | 间接 | SILENT 下 TX 不出现在正常总线 (出现在 bus 192) |

## 4. 测试用例

### TC1: SILENT 模式 — CAN TX 被阻断
- 输入: mode=SILENT(0), param=0
- 输出: safety_mode=0, CAN 发送不出现在 bus 0 (出现在 bus 192)
- 路径: set_hooks → SILENT case → relay off, can_silent=true

### TC2: SILENT 模式 — health 中 safety_mode 验证
- 输入: mode=SILENT(0), param=0
- 输出: health.safety_mode=0

### TC3: NOOUTPUT 模式 — CAN TX 不被固件阻断，由安全 hook 处理
- 输入: mode=NOOUTPUT(19), param=0
- 输出: health.safety_mode=19, CAN 发送不被 can_silent 阻断
- 路径: set_hooks → NOOUTPUT case → relay off, can_silent=false

### TC4: ELM327 param=0 — OBD CAN2 模式
- 输入: mode=ELM327(3), param=0
- 输出: health.safety_mode=3, heartbeat 重置, can_silent=false
- 路径: set_hooks → ELM327 case (param=0) → OBD_CAN2

### TC5: ELM327 param≠0 — NORMAL 模式
- 输入: mode=ELM327(3), param=1
- 输出: health.safety_mode=3, heartbeat 重置, can_silent=false
- 路径: set_hooks → ELM327 case (param≠0) → NORMAL

### TC6: ALLOUTPUT 模式 — CAN 全部放行
- 输入: mode=ALLOUTPUT(17), param=0
- 输出: health.safety_mode=17, can_silent=false
- 路径: set_hooks → ALLOUTPUT case → relay off

### TC7: 车辆特定模式 — relay 开启
- 输入: mode=TOYOTA(16), param=0
- 输出: health.safety_mode=16, can_silent=false
- 路径: set_hooks → default case → relay on, heartbeat reset

### TC8: 无效模式 — 回退 SILENT
- 输入: mode=0xFFFF (不在任何安全模型中), param=0
- 输出: health.safety_mode=0 (回退到 SILENT)
- 路径: set_hooks returns -1 → mode=SILENT

## 5. 覆盖检查

| 条件 | TC1 | TC2 | TC3 | TC4 | TC5 | TC6 | TC7 | TC8 |
|------|-----|-----|-----|-----|-----|-----|-----|-----|
| SILENT branch | ✅ | ✅ | — | — | — | — | — | ✅ |
| NOOUTPUT branch | — | — | ✅ | — | — | — | — | — |
| ELM327 param=0 | — | — | — | ✅ | — | — | — | — |
| ELM327 param≠0 | — | — | — | — | ✅ | — | — | — |
| ALLOUTPUT branch | — | — | — | — | — | ✅ | — | — |
| default (car) branch | — | — | — | — | — | — | ✅ | — |
| set_hooks error fallback | — | — | — | — | — | — | — | ✅ |
| 所有 mode 等价类覆盖 | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| param 等价类覆盖 | ✅ | ✅ | ✅ | ✅ | ✅ | — | — | — |

✅ 所有条件分支和等价类已覆盖。
