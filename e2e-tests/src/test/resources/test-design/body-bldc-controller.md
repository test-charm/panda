# BLDC_controller.c — 测试设计

> 被测文件: `board/body/bldc/BLDC_controller.c`
>
> 集成入口: `bldc_step()` in `board/body/bldc/bldc.h` (e2e wrapper compiles the real `BLDC_controller.c`)
>
> 调用链: `jna_bldc_step()` → `bldc_step()` → `BLDC_controller_step(rtM_Left)` + `BLDC_controller_step(rtM_Right)`

## 1. 作用域与可达路径

`BLDC_controller.c` 是 Simulink 生成的 FOC 控制器。生产 body 固件默认以 FOC + speed mode 集成，但当前 e2e harness 已支持对关键输入与状态进行测试专用注入，因此本文既记录默认集成路径，也记录通过 harness 覆盖到的深层控制器分支。

1. `CTRL_TYP_SEL = FOC_CTRL`
2. `CTRL_MOD_REQ = SPD_MODE`
3. `DIAG_ENA = 1`
4. 左右电机都通过 `bldc_step()` 以完全相同的运行时流程驱动，只是右电机目标值会取反

因此，这份设计以 **body 固件实际可达路径** 为主，但在不改生产代码的前提下，通过 e2e harness 注入把 `Open / Speed / Torque / Sin` 等运行时分支也纳入覆盖。

## 2. 输入因子与取值分析

### 2.1 直接输入因子

| 因子 | 来源 | 等价类 | 边界值/代表值 | 说明 |
|---|---|---|---|---|
| `offsetcount` | `bldc_step()` 内部状态 | `< 2000`、`>= 2000` | `0`、`2000` | 决定是否走 ADC 校准早返回 |
| `enable_motors` | `set motor speeds ... enable = ...` | `false`、`true` | `false`、`true` | 决定 `enableFin` 和 PWM 输出级使能 |
| `rpm_left` | `set motor speeds` | `0`、`正常范围内`、`超上限`、`超下限` | `0`、`100`、`1500`、`-1500` | 覆盖 deadband、正常缩放、上下限钳位 |
| `rpm_right` | `set motor speeds` | `0`、`正常范围内`、`超上限`、`超下限` | `0`、`200`、`1500`、`-1500` | 还需覆盖“右电机目标值最终取反” |

### 2.2 间接输入因子

| 因子 | 当前 e2e 取值 | 说明 |
|---|---|---|
| ADC 原始采样 | 默认 `0`，可由 `BodyControlSetup.adc*` 注入 | 现在可驱动不同电流/电压输入类 |
| Hall 传感器 GPIO | 默认 `0`，可由 `BodyControlSetup.hall*` 注入 | 现在可驱动不同霍尔状态类 |
| `z_ctrlModReq` | 默认 `SPD_MODE`，可由 `BodyControlSetup.ctrlModeReq` 注入 | 覆盖 `OPEN / SPD / TRQ` 切换 |
| `z_ctrlTypSel` | 默认 `FOC_CTRL`，可由 `BodyControlSetup.ctrlTypeSel` 注入 | 覆盖 `FOC / SIN` |
| `z_selPhaCurMeasABC` | 默认 `2`，可由 `BodyControlSetup.phaseSelection` 注入 | 覆盖 `AB / BC / AC` |
| 控制器前态 | 默认冷启动，可由 `schedulerReady` / `seedControlMode` 注入 | 进入 steady-state 与模式机迁移路径 |

### 2.3 输出因子

| 输出因子 | 说明 |
|---|---|
| `leftInputTarget` / `rightInputTarget` | 进入 `BLDC_controller_step()` 前的内部目标值，覆盖 deadband、钳位、右电机符号翻转 |
| `leftOutputEnabled` / `rightOutputEnabled` | TIM8/TIM1 的 `BDTR.MOE`，反映输出级是否真正使能 |
| `leftPwmActive` / `rightPwmActive` | CCR1/2/3 是否出现非零占空比 |

## 3. 运行流程图

```text
[bldc_step]
  ──→ {offsetcount < 2000?}
        ├─ Y ──→ [更新 ADC 偏移] ──→ [return]
        └─ N ──→ [计算左右相电流]
                  ──→ {offsetrrA == 0 || offsetrrC == 0 || !enable_motors?}
                        ├─ Y ──→ [enableFin = 0, 清除 TIM1/TIM8 MOE]
                        └─ N ──→ [enableFin = 1, 置位 TIM1/TIM8 MOE]
                  ──→ [left rpm: deadband + clamp + *16]
                  ──→ [right rpm: deadband + clamp + *16 + 取反]
                  ──→ [BLDC_controller_step(left)]
                  ──→ [BLDC_controller_step(right)]
                  ──→ [把 DC_phaA/B/C 映射到 CCR1/2/3]
```

## 4. 最短路径法设计测试用例

| 用例名 | `offsetcount` | `enable_motors` | `rpm_left` | `rpm_right` | 预期输出 |
|---|---:|---|---:|---:|---|
| calibration_returns_early | `0` | `true` | `100` | `200` | `leftInputTarget=0`、`rightInputTarget=0`、`leftPwmActive=false`、`rightPwmActive=false` |
| zero_rpm_keeps_zero_target | `2000` | `true` | `0` | `0` | `leftInputTarget=0`、`rightInputTarget=0`、左右 `MOE=true` |
| saturates_and_inverts_right_target | `2000` | `true` | `1500` | `-1500` | `leftInputTarget=16000`、`rightInputTarget=16000`、左右 `MOE=true` |
| disable_clears_output_stage | `2000` | `false` | `100` | `200` | `leftInputTarget=1600`、`rightInputTarget=-3200`、左右 `MOE=false` |
| enabled_generates_pwm | `2000` | `true` | `100` | `200` | `leftInputTarget=1600`、`rightInputTarget=-3200`、左右 `MOE=true`、左右 `PwmActive=true` |

## 5. 覆盖性检查

### 5.1 代码路径覆盖

| 路径 | 用例 |
|---|---|
| 校准阶段早返回 | `calibration_returns_early` |
| 校准完成后的主路径 | 其余全部 |
| `enableFin = 0` | `disable_clears_output_stage` |
| `enableFin = 1` | `zero_rpm_keeps_zero_target`、`saturates_and_inverts_right_target`、`enabled_generates_pwm` |
| 左电机目标 deadband = 0 | `zero_rpm_keeps_zero_target` |
| 左电机目标正常缩放 | `enabled_generates_pwm` |
| 左电机目标上限钳位 | `saturates_and_inverts_right_target` |
| 右电机目标符号翻转 | `enabled_generates_pwm`、`saturates_and_inverts_right_target` |

### 5.2 条件判断覆盖

| 判断点 | 覆盖方式 |
|---|---|
| `offsetcount < 2000` | `true`: `calibration_returns_early`; `false`: 其余用例 |
| `offsetrrA == 0 || offsetrrC == 0 || !enable_motors` | `false`: `zero_rpm_keeps_zero_target` / `enabled_generates_pwm`; `true`: `disable_clears_output_stage` |
| `ABS(deadband_rpm_left) < RPM_DEADBAND` | `true`: `zero_rpm_keeps_zero_target`; `false`: `enabled_generates_pwm` |
| `CLAMP(left, -MAX_RPM, MAX_RPM)` 上界 | `saturates_and_inverts_right_target` |
| `CLAMP(right, -MAX_RPM, MAX_RPM)` 下界 + 右电机取反 | `saturates_and_inverts_right_target` |

## 6. 缺陷记录

当前新增用例未发现需要通过测试专用 API 绕开的生产缺陷。

需要说明的是，`BLDC_controller.c` 中大量模式切换分支在当前 body 固件接法下为编译期不可达，这不是缺陷，而是产品集成约束；本次测试已覆盖该文件在 body 固件中的实际运行路径。

## 7. 基于 `run_all_coverage.sh` 的未覆盖分析

### 7.1 扩 harness 之前为什么覆盖率卡在 38.4%

在扩 harness 之前，`run_all_coverage.sh` 的 Phase 5 虽然会执行全部 `@body` 场景，但当时 BLDC 控制器只能吃到固定的 speed-mode 单拍输入。

因此当时 `build/coverage/html/index.html` 里 `board/body/bldc/BLDC_controller.c` 仍然只有 **38.4% (489/1274)**，原因不是脚本漏跑，而是测试还**没有把控制器推进到新的内部状态机分支**：

1. 仍然只通过 `bldc_step()` 走 body 固件现有接法
2. `bldc_step()` 每次都会把 `z_ctrlModReq` 固定写成 `SPD_MODE`
3. 当前 e2e stub 的 ADC/Hall 输入基本固定
4. 大多数场景只执行 1 次 `bldc_step()`，只能覆盖初始化/首拍路径，覆盖不到 steady-state PI、模式切换和 reset 分支

所以新增用例主要验证了**同一条已命中的 FOC 主路径**，没有打开新的 `BLDC_controller.c` 分支。

### 7.2 按覆盖报告拆分的未覆盖代码

#### A. 完全未覆盖的 helper / reset 函数

| 代码范围 | 当前覆盖 | 原因 | 如何覆盖 |
|---|---:|---|---|
| `div_nde_s32_floor` (`191-197`) | 0% | 仅在 `SIN_Method` 相位超前分支中被调用；body 当前固定 `FOC_CTRL`，不会走到 | 需要新增测试入口，允许把 `z_ctrlTypSel` 改成 `SIN_CTRL`，并打开 `b_fieldWeakEna` |
| `I_backCalc_fixdt_Reset` (`481-555`) | 0% | 只有扭矩/限幅保护子系统重入时才触发，当前没有模式切换 | 需要让测试可切换 `z_ctrlModReq`，构造 `SPD -> TRQ -> SPD` 或 `VLT -> TRQ` 的多拍序列 |
| `PI_clamp_fixdt_Reset` (`563-704`) | 0% | `Vd_Calculation` 子系统未进入或未重入 | 需要先让控制器稳定进入 FOC steady-state，再制造子系统重入条件 |
| `PI_clamp_fixdt_b_Reset` (`712-853`) | 0% | `Speed_Mode` reset 只在模式切换时触发，当前没有从别的控制模式切回速度模式 | 需要支持 `OPEN/VLT/TRQ/SPD` 之间切换 |
| `PI_clamp_fixdt_g_Reset` (`861-1001`) | 0% | 同上，当前没有驱动到相应子系统的 reset 路径 | 需要支持模式切换和多拍执行 |

#### B. `BLDC_controller_step()` 内部大块未覆盖分支

| 代码范围 | 当前覆盖现象 | 原因 | 如何覆盖 |
|---|---|---|---|
| `Clarke_PhasesAB` / `Clarke_PhasesBC` (`1453-1509`) | 未覆盖 | `bldc_init()` 把 `z_selPhaCurMeasABC` 固定设为 `2`，当前只走 `Clarke_PhasesAC` | 增加测试入口，允许把 `z_selPhaCurMeasABC` 分别改成 `0/1/2` |
| `F03_02_Control_Mode_Manager` 主要分支 (`1806-1874`) | 仅少量初始化命中，主体分支基本未覆盖 | 当前只首拍进入 `IN_ACTIVE/IN_SPEED_MODE`，没有后续拍，也没有切换到 `TRQ/VLT/OPEN` | 同一场景里连续执行多次 `bldc_step()`；并提供 `z_ctrlModReq` 注入接口 |
| `Motor_Limitations` 的 mode switch (`2240-2315`) | 0% | `z_ctrlMod` 没有被驱动到对应 steady-state case | 在 controller 已进入 `ACTIVE` 后继续跑第二拍/第三拍，并切换 `z_ctrlModReq` |
| `Speed_Mode` PI + feedforward (`2528-2633`) | 0% | 当前场景还没跑到真正的 speed loop steady-state | 同一用例中至少连续跑 2~3 次 `bldc_step()`；保持 `enable_motors=true` 和非零 target |
| `Vd_Calculation` (`2688-2715`) | 0% | 依赖更深的 FOC steady-state 条件，首拍达不到 | 需要连续步进，并允许调 Hall/电流输入，让 d/q 电流环真正工作 |
| `SIN_Method` (`2963-2986`) | 0% | body 固件参数固定 `FOC_CTRL`，运行时不会走正弦控制 | 只能通过测试专用入口切换 `z_ctrlTypSel=1` 覆盖 |

#### C. 已进入大分支，但只覆盖了其中一部分

| 代码范围 | 未覆盖点 | 原因 | 如何覆盖 |
|---|---|---|---|
| `Clarke_Park_Transform_Forward` (`1467-1475`, `1486-1493`, `1502-1509`) | AB/BC 两组公式和饱和分支没命中 | 当前只走 `AC` 电流相选择，且输入幅值太小，打不到饱和 | 允许切换 `z_selPhaCurMeasABC`，并能注入更大的 ADC 电流值 |
| `Clarke_Park_Transform_Inverse` (`2860-2945`) | 部分饱和和边界判断未命中 | 现在 PWM/电流输入太温和 | 需要可控 Hall、ADC、电压输入，把 `Vd/Vq` 推到上下界 |
| `COM_Method` | 仍有少量未命中 | 当前霍尔状态固定，没把换相表所有索引走完 | 需要可注入 6 组 Hall 状态 |

### 7.3 现有 e2e harness 的真正瓶颈

当前限制不是 feature 数量，而是 **harness 可控输入太少**。现在的测试只能改：

- `rpm_left`
- `rpm_right`
- `enable_motors`
- 是否跳过校准

但覆盖报告里未命中的大部分代码依赖下面这些输入，而当前都没有测试入口：

| 缺少的测试控制项 | 影响的未覆盖区域 |
|---|---|
| `z_ctrlModReq` | `OPEN/VLT/SPD/TRQ` 模式切换、全部 reset 分支、Motor_Limitations switch case |
| `z_ctrlTypSel` | `FOC_Method` / `SIN_Method` 分支、`div_nde_s32_floor` |
| `z_selPhaCurMeasABC` | `Clarke_PhasesAB/BC/AC` 三路分支 |
| Hall 传感器原始状态 | 换相表、角度/诊断路径、COM method 剩余分支 |
| ADC 原始采样值 | PI 饱和、限流、`Vd_Calculation`、逆变换饱和分支 |
| `b_cruiseCtrlEna` / `n_cruiseMotTgt` 等参数 | `Speed_Mode` 里 cruise/feedforward 相关路径 |

### 9.4 本次补测结果

本轮补测在 `e2e-tests/src/test/resources/features/body_bldc_controller.feature` 新增 7 个场景：

| 用例名 | 目标 | 结果 |
|---|---|---|
| `hall_state_transitions_trigger_commutation_detection_and_update_electrical_angle` | 注入两个不同 Hall 状态，跨步触发换相检测、方向检测和原始速度估算 | ✅ PASS |
| `angle_measurement_enabled_with_mech_angle_produces_non_zero_electrical_angle` | `b_angleMeasEna=true` + `a_mechAngle` 注入，走 `F01_06_Electrical_Angle_Measurement`，验证 `a_elecAngle` 输出 | ✅ PASS |
| `cruise_control_with_positive_target_engages_feedforward_clamping` | `b_cruiseCtrlEna=true` + `n_cruiseMotTgt=500`，命中 `MinMax4/MinMax3` 巡航前馈钳位分支 | ✅ PASS |
| `hall_all_low_with_diagnostics_enabled_triggers_error_code` | Hall 全 0，设置 `errQual=2` 快速触发误差检测，验证 `z_errCode=1` | ✅ PASS |
| `diagnostics_disabled_suppresses_error_code_on_hall_fault` | `diagEna=0`，即使 Hall 全 0 也保持 `z_errCode=0` | ✅ PASS |
| `voltage_mode_to_speed_mode_transition_triggers_speed_pi_reset` | `seedControlMode=3`（VLT）→ `ctrlModeReq=2`（SPD），跨步触发 `PI_clamp_fixdt_b_Reset` | ✅ PASS |
| `phase_current_injection_through_ADC_drives_iq_and_id_non_zero` | 注入非零 ADC 相电流，通过 Clarke/Park 变换产生非零 iq/id | ✅ PASS |

### 9.5 本轮覆盖影响

本次补测聚焦于通过新的 harness 控制项打开之前未覆盖的控制路径：

| 区域 | 本轮命中情况 |
|---|---|
| `F01_06_Electrical_Angle_Measurement`（角度测量路径） | ✅ 通过 `b_angleMeasEna=true` + `a_mechAngle` 命中 |
| 换相检测/方向检测/原始速度估算 | ✅ 通过 Hall 状态跨步变化命中 |
| Cruise 控制前馈钳位（`MinMax4/MinMax3`） | ✅ 通过 `b_cruiseCtrlEna=true` + `n_cruiseMotTgt` 命中 |
| 诊断错误码路径（Hall 全低/全高检测） | ✅ 通过 Hall 状态 + `errQual=2` 快速触发 |
| 诊断禁用分支（`b_diagEna=false`） | ✅ 通过 `diagEna=0` 验证跳过诊断 |
| `PI_clamp_fixdt_b_Reset`（speed-mode PI reset） | ✅ 通过 VLT→SPD 模式切换触发 |
| Clarke 变换 + Park 变换（含非零电流输入） | ✅ 通过 ADC 电流注入命中 |

### 9.6 本轮新增的 harness 接口总结

| 接口 | 层级 | 作用 |
|---|---|---|
| `jna_body_set_angle_meas_ena` | C → Java → Spec | 开关角度测量模式 |
| `jna_body_set_mech_angle` | C → Java → Spec | 注入机械角度值 |
| `jna_body_set_diag_ena` | C → Java → Spec | 开关电机诊断 |
| `jna_body_set_err_qual` | C → Java → Spec | 设置误差检测 qualification/dequalification 时间 |

## 10. 第四轮：根因修复与 FOC PI 路径覆盖

### 10.1 根因分析：为什么 PI 控制器代码 0% 覆盖

BLDC_controller 使用三段式 Task_Scheduler 状态机来调度控制/中间/FOC 三个阶段：

```text
          [U2=T, U5=F, U6=F]  ← init
         ┌─── IF (控制) ──────── F03 模式管理器、诊断
         │   U2←U6=F, U5←T, U6←F
         ▼
          [U2=F, U5=T, U6=F]
         ┌─── ELSE IF (中间) ── F04 磁场削弱、Motor_Limitations
         │   U2←U6=F, U5←F, U6←T
         ▼
          [U2=F, U5=F, U6=T]
         └─── ELSE (FOC) ─────── PI 控制器执行
             U2←U6=T, U5←F, U6←F
             循环回到 IF
```

**关键发现**：`schedulerReady: 1` 将 `UnitDelay6` 提前设为 `true`，破坏了初始状态 `[T,F,F]`，变成 `[T,F,T]`。这导致状态机陷入 `IF ↔ ELSE_IF` 的死循环，永远到不了 `ELSE (FOC)` 分支：

```text
[T,F,T] → [T,T,F] → [F,T,T] → [T,F,T] → [T,T,F] → ...   ❌ FOC 永远不执行
```

**修复**：从所有 FOC-path 测试中移除 `schedulerReady: 1`，让调度器自然轮转到 FOC（第 3 步）。

### 10.2 本轮新增测试场景

| 用例名 | 步骤数 | 目标 |
|---|---|---|
| `speed-mode_steady_state_FOC_produces_non_zero_iq_and_id_after_two_cycles` | 6 | 无 schedulerReady，自然轮转 2 个完整 FOC 周期，覆盖 `PI_clamp_fixdt_l` 执行体 |
| `speed-mode_PI_reset_triggers_on_VLT_to_SPD_mode_transition` | 6 | VLT→SPD 模式切换 + FOC 到达，覆盖 `PI_clamp_fixdt_b_Reset` |
| `angle_measurement_enters_Vd_Calculation_path` | 6 | `b_angleMeasEna=1` 使 `rtb_LogicalOperator=true`，FOC 到达时进入 `Vd_Calculation`，覆盖 `PI_clamp_fixdt_Reset` + `PI_clamp_fixdt` |
| `VLT_mode_FOC_path_exercises_I_backCalc_fixdt_voltage_protection` | 6 | `seedControlMode=3` + `ctrlModeReq=1`，FOC 到达时 `z_ctrlMod=VLT`，进入 `Voltage_Mode_Protection`，覆盖 `I_backCalc_fixdt_Reset` + `I_backCalc_fixdt` |
| `SIN_control_type_with_field_weakening_exercises_div_nde_s32_floor_path` | 6 | SIN 控制类型 + 磁场削弱，中间步骤进入 `F04_Field_Weakening`，覆盖 `div_nde_s32_floor`（SIN 分支） |

### 10.3 已修复的现有测试

移除 `schedulerReady: 1` 的测试（共 9 个）：
- `repeated_speed_mode_steps_reach_the_steady_state_foc_speed_loop`
- `repeated_steps_keep_the_controller_in_speed_mode`
- `torque_mode_request_switches_the_controller_out_of_speed_mode`
- `open_mode_request_clears_the_active_torque_mode`
- `current_phase_selection_AB_drives_the_AB_clarke_branch`
- `current_phase_selection_BC_drives_the_BC_clarke_branch`
- `sin_control_mode_executes_the_sine_table_path`
- `voltage_mode_to_speed_mode_transition_triggers_speed_pi_reset`
- `phase_current_injection_through_ADC_drives_iq_and_id_non_zero`

**保留** `schedulerReady: 1` 的测试（纯诊断测试，不走 FOC 路径）：
- `hall_all_low_with_diagnostics_enabled_triggers_error_code`
- `diagnostics_disabled_suppresses_error_code_on_hall_fault`

### 7.4 如果要继续提高覆盖率，优先级应该怎么排

| 优先级 | 建议 | 预计能解锁的代码 |
|---|---|---|
| P1 | 给 e2e 增加“连续执行 N 次 `bldc_step()`”能力 | `F03_Control_Mode_Manager` steady-state、`Speed_Mode` 主体、部分 `Motor_Limitations` |
| P2 | 增加 `z_ctrlModReq` 的测试注入接口 | `OPEN/VLT/SPD/TRQ` 切换、4 个 reset helper、mode switch case |
| P3 | 增加 Hall/ADC 原始输入注入 | `Vd_Calculation`、PI 饱和、换相/角度相关分支 |
| P4 | 增加 `z_selPhaCurMeasABC` 参数覆盖 | `Clarke_PhasesAB/BC` |
| P5 | 增加 `z_ctrlTypSel` 的测试专用切换 | `SIN_Method`、`div_nde_s32_floor` |

### 7.5 结论

当前 `38.4%` 的核心原因不是“测试不够多”，而是**body 集成层把 `BLDC_controller.c` 压缩成了一条很窄的可达路径**：

1. 运行时固定 `FOC_CTRL`
2. 每拍固定 `SPD_MODE`
3. 电流/Hall 输入几乎固定
4. 场景大多只跑单拍

因此，下一步如果要让 `BLDC_controller.c` 的覆盖率明显上升，重点不该继续加“更多单拍 RPM 用例”，而是先扩展 e2e harness，让测试可以：

1. 连续跑多拍
2. 切模式
3. 改传感器输入
4. 改控制器参数

没有这些能力，`run_all_coverage.sh` 再多跑几个 feature，`BLDC_controller.c` 的覆盖率也基本不会动。

## 8. 本次 harness 扩展与补测结果

### 8.1 新增的 harness 控制项

本次没有改生产代码，只扩展了 `e2e-tests` 下的 body harness，使测试可以从 `BodyControlSetup` 注入以下输入：

| 控制项 | 作用 |
|---|---|
| `ctrlModeReq` | 覆盖 `z_ctrlModReq`，驱动 `OPEN / SPD / TRQ` 相关分支 |
| `ctrlTypeSel` | 覆盖 `z_ctrlTypSel`，让测试能切到 `SIN_CTRL` |
| `phaseSelection` | 覆盖 `z_selPhaCurMeasABC`，命中 `Clarke_PhasesAB / BC / AC` |
| `schedulerReady` | 直接置 `UnitDelay6_DSTATE`，把控制器推入 steady-state 路径 |
| `seedControlMode` | 直接设定控制模式状态机起点，命中 `IN_SPEED_MODE / IN_TORQUE_MODE / IN_OPEN` 切换分支 |
| `cruiseEnabled` / `cruiseTarget` | 覆盖 speed-mode 中与巡航/前馈有关的判断 |
| `fieldWeakEnabled` | 覆盖 `SIN_Method` 中 field weakening 分支 |
| `hallLeft*` / `hallRight*` | 注入左右电机 Hall 输入 |
| `adcLeft*` / `adcRight*` / `adcBattery` | 注入相电流、母线电流和电池 ADC 原始值 |

### 8.2 本次新增测试场景

新增并最终合并到：`e2e-tests/src/test/resources/features/body_bldc_controller.feature`

| 用例名 | 目标 |
|---|---|
| `repeated_speed_mode_steps_reach_the_steady_state_foc_speed_loop` | 连续执行多拍，命中 speed-mode steady-state FOC 主路径 |
| `repeated_steps_keep_the_controller_in_speed_mode` | 保持 `SPD_MODE`，验证 steady-state 不误切换 |
| `torque_mode_request_switches_the_controller_out_of_speed_mode` | 覆盖 `SPD → TRQ` |
| `open_mode_request_clears_the_active_torque_mode` | 覆盖 `TRQ → OPEN` |
| `current_phase_selection_ab_drives_the_ab_clarke_branch` | 覆盖 `Clarke_PhasesAB` |
| `current_phase_selection_bc_drives_the_bc_clarke_branch` | 覆盖 `Clarke_PhasesBC` |
| `sin_control_mode_executes_the_sine_table_path` | 覆盖 `SIN_Method` |

### 8.3 覆盖结果更新

重新执行 `./run_all_coverage.sh` 后，合并报告 `e2e-tests/build/coverage/html/index.html` 中：

| 文件 | 变更前 | 变更后 |
|---|---:|---:|
| `board/body/bldc/BLDC_controller.c` | `38.4%` (`489/1274`) | `53.0%` (`675/1274`) |
| 全量合并覆盖 | `76.2%` (`3246/4260`) | `80.6%` (`3434/4260`) |

body 单板 `llvm-cov` 报告中，该文件当前为：

| 指标 | 当前值 |
|---|---:|
| Function coverage | `73.08%` (`19/26`) |
| Line coverage | `52.69%` (`666/1264`) |
| Region coverage | `44.65%` (`346/775`) |
| Branch coverage | `35.40%` (`206/582`) |

### 8.4 已经被打到的原未覆盖区域

这次补测后，上一轮分析里最重要的几块已经命中：

| 区域 | 当前状态 |
|---|---|
| `Clarke_PhasesAB / Clarke_PhasesBC` | 已覆盖 |
| `F03_02_Control_Mode_Manager` 的 `speed / torque / open` 相关路径 | 已覆盖 |
| `SIN_Method` | 已覆盖 |
| `I_backCalc_fixdt_Reset` | 已覆盖 |
| `BLDC_controller_step()` 主函数 | 从原先单拍主路径提升到多拍 steady-state 路径 |

### 8.5 仍未覆盖或覆盖仍很低的部分

根据最新 body 覆盖报告，以下函数仍然没有被打到，或者仍然是 0%：

| 函数 | 当前覆盖 | 仍未覆盖的原因 | 后续覆盖方法 |
|---|---:|---|---|
| `div_nde_s32_floor` | 0% | 虽然进了 `SIN_Method`，但还没把相位超前分支推到真正调用该函数的数值区间 | 继续扩大 `fieldWeak`/角度/速度输入范围，或增加 `a_mechAngle` 测试注入 |
| `PI_clamp_fixdt_Reset` | 0% | `Vd_Calculation` reset 触发条件仍未满足 | 需要更细的电流环状态注入，或直接 seed `If1_ActiveSubsystem_a` 相关状态 |
| `PI_clamp_fixdt` | 0% | `Vd_Calculation` 子系统主体仍没进入 | 需要可控 d/q 电流误差，让 `rtb_LogicalOperator` 进入该支路 |
| `PI_clamp_fixdt_b_Reset` | 0% | speed-mode reset 仍未被当前序列触发 | 需要补 `VLT/TRQ -> SPD` 且保留对应前态 |
| `PI_clamp_fixdt_l` | 0% | speed-mode PI 主体条件仍未完全满足 | 需要进一步调校 Hall/ADC/状态，使 `SwitchCase_ActiveSubsystem == 1` 后进入主体 |
| `PI_clamp_fixdt_g_Reset` | 0% | iq 电流环 reset 条件仍未满足 | 需要更细粒度 seed 当前子系统状态 |
| `PI_clamp_fixdt_k` | 0% | iq 电流环主体未进入 | 需要让 `FOC_Enabled` 下的电流环条件成立 |

### 8.6 下一步最有效的补测方向

如果还要继续拉高 `BLDC_controller.c` 覆盖率，优先级已经从“增加 feature 数量”变成“继续扩内部状态控制”：

1. 增加 `a_mechAngle` 和更多 FOC 内部状态 seed
2. 增加 `If1_ActiveSubsystem*` / `SwitchCase_ActiveSubsystem*` 的测试注入
3. 增加更细粒度的 d/q 电流误差与限幅场景
4. 专门为 `PI_clamp_fixdt*` 三组控制器写多拍迁移用例

到这一步，`BLDC_controller.c` 剩余的低覆盖区域已经主要集中在**更深层的 PI 状态机和电流环内部细分支**，不再是最外层模式切换和输入选择分支。

## 9. 第三轮 harness 扩展与补测

### 9.1 新增的 harness 控制项

本次扩展 e2e harness，使测试可以注入 FOC 控制器更深层的内部输入：

| 控制项 | JNA 函数 | 作用 |
|---|---|---|
| `angleMeasEna` | `jna_body_set_angle_meas_ena` | 设置 `b_angleMeasEna`，启用机械角度测量模式，直接影响 `rtb_LogicalOperator` 从而进入 `Vd_Calculation` 路径 |
| `mechAngleLeft/Right` | `jna_body_set_mech_angle` | 设置 `a_mechAngle` 输入，控制电气角度计算（需要 `b_angleMeasEna=true` 且 `n_polePairs` 非零） |
| `diagEna` | `jna_body_set_diag_ena` | 覆盖 `b_diagEna`，控制是否执行电机诊断逻辑（hall 错误、堵转检测） |

### 9.2 本次新增测试场景

新增到：`e2e-tests/src/test/resources/features/body_bldc_controller.feature`

#### 9.2.1 控制模式管理器完整状态迁移路径

| 用例名 | 目标 |
|---|---|
| `voltage_mode_to_speed_mode_resets_speed_pi` | 从 VLT_MODE 切到 SPD_MODE，触发 `PI_clamp_fixdt_b_Reset`，验证 speed-mode PI reset |
| `voltage_mode_to_torque_mode_resets_i_backcalc` | 从 VLT_MODE 切到 TRQ_MODE，触发 `I_backCalc_fixdt_Reset` |
| `torque_mode_to_speed_mode_resets_speed_pi` | 从 TRQ_MODE 切到 SPD_MODE，覆盖 `PI_clamp_fixdt_b_Reset` 从 torque 态切换 |

#### 9.2.2 电机诊断与错误码路径

| 用例名 | 目标 |
|---|---|
| `hall_all_low_triggers_error_code_7` | Hall 全为 0（Sum==0），双拍后触发 `z_errCode=7`（Hall 错误 + 堵转） |
| `hall_all_high_triggers_error_code_1` | Hall 全为 1（Sum==7），触发 `z_errCode=1`（Hall 全高错误） |
| `diagnostics_disabled_skips_error_detection` | 设置 `diagEna=0`，验证即使 hall 全 0 也不触发错误码 |

#### 9.2.3 角度测量与电气角度路径

| 用例名 | 目标 |
|---|---|
| `angle_measurement_with_mech_angle_produces_electrical_angle` | `b_angleMeasEna=true` + `a_mechAngle` 输入，验证 `a_elecAngle` 输出非零 |
| `angle_measurement_enables_vd_calculation` | `b_angleMeasEna=true` 使 `rtb_LogicalOperator=true`，进入 `Vd_Calculation` 触发器 |

#### 9.2.4 巡航控制路径

| 用例名 | 目标 |
|---|---|
| `cruise_control_with_positive_target_limits_iq_to_vq_max` | `b_cruiseCtrlEna=true` + `n_cruiseMotTgt` 正目标，命中 `MinMax4/MinMax3` 钳位分支 |
| `cruise_control_with_negative_target_limits_iq_to_gain5` | `b_cruiseCtrlEna=true` + `n_cruiseMotTgt` 负目标，验证负巡航钳位 |

#### 9.2.5 电流注入与饱和路径

| 用例名 | 目标 |
|---|---|
| `phase_current_injection_drives_clarke_transform_output` | 注入非零 `adcLeftPhaA/adcLeftPhaC`，验证 Clarke 变换输出非零，走 iq/id 计算 |
| `dc_link_current_injection_with_near_zero_speed_engages_protection` | 注入大 ADC 电流 + 小转速，让 `i_backCalc_fixdt` 保护路径运行 |

### 9.3 输入因子扩展分析

#### 新因子：`b_angleMeasEna`

| 取值 | 等价类 | 影响 |
|---|---|---|
| `false` (0) | 角度估计模式（默认） | `rtb_LogicalOperator = n_commDeacv_Mode && !dz_cntTrnsDet`，需要 commutation 才能进入 Vd_Calculation |
| `true` (1) | 角度测量模式 | `rtb_LogicalOperator = true`，Vd_Calculation 无条件进入 |

#### 新因子：`a_mechAngle`

| 取值 | 等价类 | 边界值 |
|---|---|---|
| 0 | 标准零位 | 0 |
| 非零正常值 | 产生非零电气角度 | 100, 500, 1000 |
| 范围外/环绕 | 测试 mod 360° 环绕 | 5760（正好一圈）, 11520 |

#### 新因子：`b_diagEna`

| 取值 | 等价类 | 说明 |
|---|---|---|
| `false` (0) | 禁用 | 跳过所有诊断逻辑，`z_errCode` 不更新 |
| `true` (1) | 启用（默认） | Hall 错误、堵转检测全部运行 |

## 11. 死代码记录

### 11.1 `PI_clamp_fixdt_k` / `PI_clamp_fixdt_g_Reset`（子系统 `<S62>`，iq PI 控制器）

**状态**：❌ 不可覆盖（Simulink 模型死代码）

**证据**：FOC 路径 switch case（line 2479）仅包含 `case 0`（VLT）、`case 1`（SPD）、`case 3`（OPEN），**无 `case 2`**（TRQ_MODE）。`z_ctrlMod=3` 映射到 `UnitDelay3=2`，落入 switch 末尾不执行任何代码。

```c
// FOC switch (line 2461 → line 2479)
switch (z_ctrlMod) {
    case 1: break;        // VLT → UnitDelay3=0
    case 2: UnitDelay3=1; // SPD → UnitDelay3=1 → case 1: PI_clamp_fixdt_l
    case 3: UnitDelay3=2; // TRQ → UnitDelay3=2 → NO MATCHING CASE ❌
    default: UnitDelay3=3;
}
switch (UnitDelay3) {
    case 0: ... // Voltage_Mode
    case 1: ... // Speed_Mode → PI_clamp_fixdt_l
    case 3: ... // Open_Mode
    // ⚠️ case 2 缺失
}
```

`PI_clamp_fixdt_k`（64 行）和 `PI_clamp_fixdt_g_Reset`（4 行）仅被 `PI_clamp_fixdt_f_Init()` 初始化过，从未在 `BLDC_controller_step()` 中被调用。需重新生成 Simulink 模型（增加 Torque_Mode FOC 执行体）才能覆盖。

### 11.2 函数覆盖总结

| 函数 | 行数 | 覆盖 | 原因 |
|------|------|------|------|
| `div_nde_s32_floor` | 4 | ✅ 100% | SIN_Method 磁场削弱分支 |
| `Counter` | 16 | ✅ 100% | 换相检测 |
| `Counter_n` | 18 | ✅ 100% | Debounce_Filter 计数器 |
| `either_edge` | 3 | ✅ 100% | 错误码边沿检测 |
| `Debounce_Filter` | 6 | 50% | dequalification 路径未覆盖 |
| `Low_Pass_Filter` | 23 | 74% | 饱和分支未覆盖 |
| `I_backCalc_fixdt_Reset` | 4 | ✅ Phase M | VLT/TRQ 保护首次切入 |
| `I_backCalc_fixdt` | 26 | ✅ Phase M | VLT 保护每拍执行 |
| `PI_clamp_fixdt_Reset` | 4 | ✅ Phase M | Vd_Calculation 首次切入 |
| `PI_clamp_fixdt` | 64 | ✅ Phase M | Vd_Calculation PI 执行体 |
| `PI_clamp_fixdt_b_Reset` | 4 | ✅ Phase M | Speed_Mode 首次切入 |
| `PI_clamp_fixdt_l` | 64 | ✅ Phase M | Speed_Mode PI 执行体 |
| `PI_clamp_fixdt_g_Reset` | 4 | ❌ 死代码 | FOC switch 无 TRQ case |
| `PI_clamp_fixdt_k` | 64 | ❌ 死代码 | FOC switch 无 TRQ case |
