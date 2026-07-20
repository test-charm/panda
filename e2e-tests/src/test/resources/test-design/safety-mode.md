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
 (0)   (19)        (3)        (17)        (TOYOTA=2,
   │    │           │           │          HONDA=1...)
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
| `mode` | uint16 | SILENT(0), NOOUTPUT(19), ELM327(3), ALLOUTPUT(17), 车辆特定模式(e.g. TOYOTA=2), 无效模式(不在安全模型范围内) | 0, 1, 2, 3, 17, 19, 0xFFFF |
| `param` | uint16 | 仅 ELM327 区分: param=0 (OBD_CAN2), param≠0 (NORMAL) | 0, 1 |

## 3. 输出因子 (通过控制数据查询观测)

| 输出 | 说明 | feature 中验证 |
|------|------|---------------|
| safetyTxBlocked | 安全 hook 阻断的发送计数 | 阻断模式=1, 放行模式=0 |
| relayCall.a / relayCall.b | 继电器驱动状态 | SILENT/NOOUTPUT=false, ALLOUTPUT/TOYOTA=true |
| canModeCall.value | CAN 静默模式 (SILENT=0, NORMAL=0, OBD_CAN2=1) | ELM327 OBD_CAN2=1 |
| rxQueue | 接收队列（含 rejected 标记） | 阻断时含 rejected=true 的消息 |
| txQueue[0] | 发送队列（空或含消息） | 阻断时为空，放行时含 rejected=false 的消息 |
| fdcanRegs[N].cccr | FDCAN CCCR 寄存器（SILENT 模式下 CCCR.MON=1） | 非 SILENT=0x00, SILENT=0x20 |
| fdcanRegs<<0,1,2>> (全部寄存器) | 模式切换后 can_init_all() 完全重初始化 | TC8 验证 ie/nbtp/dbtp/txbc/rxf0c/txesc/rxesc/gfc/ile |

## 4. 测试用例 (对应 safety_mode.feature 场景)

### TC1: SILENT 模式 — CAN TX 被阻断
- 输入: mode=SILENT(0), param=0 (default from SetSafetyMode spec)
- 输出: safetyTxBlocked=1, rxQueue 含 rejected 消息, txQueue[0] 为空
- 路径: set_hooks → SILENT case → relay off, can_silent=true → nooutput_hooks.tx 阻断

### TC2: NOOUTPUT 模式 — CAN TX 被安全 hook 阻断
- 输入: mode=NOOUTPUT(19), param=0 (default from SetSafetyMode spec)
- 输出: safetyTxBlocked=1, rxQueue 含 rejected 消息, txQueue[0] 为空
- 路径: set_hooks → NOOUTPUT case → relay off, can_silent=false → nooutput_hooks.tx 阻断

### TC3: ALLOUTPUT 模式 — CAN 全部放行
- 输入: mode=ALLOUTPUT(17), param=0 (default from SetSafetyMode spec)
- 输出: safetyTxBlocked=0, rxQueue=[], txQueue[0] 含放行消息
- 路径: set_hooks → ALLOUTPUT case → relay off → alloutput_hooks.tx 放行

### TC4: ELM327 OBD_CAN2 — param=0 子模式
- 输入: mode=ELM327(3), param=0
- 输出: safetyTxBlocked=0, rxQueue=[], txQueue[0] 含放行消息
- 路径: set_hooks → ELM327 case (param=0) → OBD_CAN2, elm327_hooks 校验通过

### TC5: ELM327 NORMAL — param≠0 子模式
- 输入: mode=ELM327(3), param=1
- 输出: safetyTxBlocked=0, rxQueue=[], txQueue[0] 含放行消息
- 路径: set_hooks → ELM327 case (param≠0) → NORMAL, elm327_hooks 校验通过

### TC6: TOYOTA 车辆特定模式 — 非 TOYOTA 消息被阻断
- 输入: mode=TOYOTA(2), param=0 (default from SetSafetyMode spec)
- 输出: safetyTxBlocked=1, rxQueue 含 rejected 消息, txQueue[0] 为空
- 路径: set_hooks → default case → relay on, toyota_hooks.tx 阻断非 TOYOTA 消息

### TC7: 无效模式 — 回退 SILENT
- 输入: mode=7 (不在 safety_hook_registry 中), param=0 (default from SetSafetyMode spec)
- 输出: safetyTxBlocked=1, rxQueue 含 rejected 消息, txQueue[0] 为空, cccr[0]=0x20 (MON)
- 路径: set_hooks returns -1 → 回退 SAFETY_SILENT → nooutput_hooks.tx 阻断

### TC8: 模式切换 — 清空 TX 队列 + 重初始化 FDCAN
- 输入: 先切换到 ALLOUTPUT(17), 发送一条 CAN 消息, 再切换到 ALLOUTPUT(17)
- 输出: rxQueue=[], txQueue[0]=[], fdcanRegs<<0,1,2>> 所有寄存器被 can_init_all() 重初始化
- 路径: set_safety_mode → set_safety_hooks → can_init_all() → 所有 FDCAN 寄存器恢复默认值, TX 队列清空

## 5. 覆盖检查

| 条件 | TC1 | TC2 | TC3 | TC4 | TC5 | TC6 | TC7 | TC8 |
|------|-----|-----|-----|-----|-----|-----|-----|-----|
| SILENT branch | ✅ | — | — | — | — | — | ✅ | — |
| NOOUTPUT branch | — | ✅ | — | — | — | — | — | — |
| ALLOUTPUT branch | — | — | ✅ | — | — | — | — | ✅ |
| ELM327 param=0 | — | — | — | ✅ | — | — | — | — |
| ELM327 param≠0 | — | — | — | — | ✅ | — | — | — |
| default (car) branch | — | — | — | — | — | ✅ | — | — |
| set_hooks error fallback | — | — | — | — | — | — | ✅ | — |
| can_init_all() 重初始化 | — | — | — | — | — | — | — | ✅ |
| 所有 mode 等价类覆盖 | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| param 等价类覆盖 | ✅ | ✅ | ✅ | ✅ | ✅ | — | — | — |

✅ 所有条件分支、等价类和副作用（can_init_all 重初始化）已覆盖。
