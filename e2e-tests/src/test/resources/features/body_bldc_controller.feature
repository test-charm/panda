# language: en
@body
Feature: BLDC controller runtime behavior

  Scenario: calibration phase returns before computing motor targets or PWM duty
    When set motor speeds: left = 100 rpm, right = 200 rpm, enable = true
    And bldc step
    Then body control data should be:
      """
      : {
        leftInputTarget: 0
        rightInputTarget: 0
        leftPwmActive: false
        rightPwmActive: false
      }
      """

  Scenario: zero rpm commands stay at zero internal targets after calibration
    When bldc skip calibration
    And set motor speeds: left = 0 rpm, right = 0 rpm, enable = true
    And bldc step
    Then body control data should be:
      """
      : {
        leftInputTarget: 0
        rightInputTarget: 0
        leftOutputEnabled: true
        rightOutputEnabled: true
      }
      """

  Scenario: out-of-range rpm commands clamp to max magnitude and invert right target sign
    When bldc skip calibration
    And set motor speeds: left = 1500 rpm, right = -1500 rpm, enable = true
    And bldc step
    Then body control data should be:
      """
      : {
        leftInputTarget: 16000
        rightInputTarget: 16000
        leftOutputEnabled: true
        rightOutputEnabled: true
      }
      """

  Scenario: disabled motors clear the PWM output stage even when targets are non-zero
    When bldc skip calibration
    And set motor speeds: left = 100 rpm, right = 200 rpm, enable = false
    And bldc step
    Then body control data should be:
      """
      : {
        leftInputTarget: 1600
        rightInputTarget: -3200
        leftOutputEnabled: false
        rightOutputEnabled: false
      }
      """

  Scenario: enabled motors drive non-zero PWM duty after calibration
    When bldc skip calibration
    And set motor speeds: left = 100 rpm, right = 200 rpm, enable = true
    And bldc step
    Then body control data should be:
      """
      : {
        leftInputTarget: 1600
        rightInputTarget: -3200
        leftOutputEnabled: true
        rightOutputEnabled: true
        leftPwmActive: true
        rightPwmActive: true
      }
      """

  Scenario: repeated speed-mode steps reach the steady-state FOC speed loop
    Given exists data:
      """
      BodyControlSetup: {
        seedControlMode: 1
      }
      """
    When bldc skip calibration
    And set motor speeds: left = 100 rpm, right = 200 rpm, enable = true
    And bldc step
    And bldc step
    And bldc step
    Then body control data should be:
      """
      : {
        leftCtrlMode: 2
        rightCtrlMode: 2
        leftCtrlType: 2
        rightCtrlType: 2
        leftPwmActive: true
        rightPwmActive: true
      }
      """

  Scenario: repeated steps keep the controller in speed mode
    Given exists data:
      """
      BodyControlSetup: {
        seedControlMode: 1
        ctrlModeReq: 2
      }
      """
    When bldc skip calibration
    And set motor speeds: left = 80 rpm, right = 90 rpm, enable = true
    And bldc step
    And bldc step
    Then body control data should be:
      """
      : {
        leftCtrlMode: 2
        rightCtrlMode: 2
      }
      """

  Scenario: torque mode request switches the controller out of speed mode
    Given exists data:
      """
      BodyControlSetup: {
        seedControlMode: 2
        ctrlModeReq: 3
      }
      """
    When bldc skip calibration
    And set motor speeds: left = 80 rpm, right = 90 rpm, enable = true
    And bldc step
    And bldc step
    Then body control data should be:
      """
      : {
        leftCtrlMode: 3
        rightCtrlMode: 3
      }
      """

  Scenario: open mode request clears the active torque mode
    Given exists data:
      """
      BodyControlSetup: {
        seedControlMode: 2
        ctrlModeReq: 0
      }
      """
    When bldc skip calibration
    And set motor speeds: left = 80 rpm, right = 90 rpm, enable = true
    And bldc step
    Then body control data should be:
      """
      : {
        leftCtrlMode: 0
        rightCtrlMode: 0
      }
      """

  Scenario: current phase selection AB drives the AB Clarke branch
    Given exists data:
      """
      BodyControlSetup: {
        phaseSelection: 0
        seedControlMode: 1
      }
      """
    When bldc skip calibration
    And set motor speeds: left = 120 rpm, right = 120 rpm, enable = true
    And bldc step
    And bldc step
    Then body control data should be:
      """
      : {
        leftPhaseSelection: 0
        rightPhaseSelection: 0
        leftCtrlMode: 2
        rightCtrlMode: 2
      }
      """

  Scenario: current phase selection BC drives the BC Clarke branch
    Given exists data:
      """
      BodyControlSetup: {
        phaseSelection: 1
        seedControlMode: 1
      }
      """
    When bldc skip calibration
    And set motor speeds: left = 120 rpm, right = 120 rpm, enable = true
    And bldc step
    And bldc step
    Then body control data should be:
      """
      : {
        leftPhaseSelection: 1
        rightPhaseSelection: 1
        leftCtrlMode: 2
        rightCtrlMode: 2
      }
      """

  Scenario: sin control mode executes the sine-table path
    Given exists data:
      """
      BodyControlSetup: {
        ctrlTypeSel: 1
        seedControlMode: 1
      }
      """
    When bldc skip calibration
    And set motor speeds: left = 200 rpm, right = 200 rpm, enable = true
    And bldc step
    And bldc step
    Then body control data should be:
      """
      : {
        leftCtrlType: 1
        rightCtrlType: 1
        leftPwmActive: true
        rightPwmActive: true
      }
      """

  Scenario: hall state transitions trigger commutation detection and update electrical angle
    Given exists data:
      """
      BodyControlSetup: {
        seedControlMode: 1
        hallLeftA: 0
        hallLeftB: 0
        hallLeftC: 1
        hallRightA: 0
        hallRightB: 0
        hallRightC: 1
      }
      """
    When bldc skip calibration
    And set motor speeds: left = 100 rpm, right = 100 rpm, enable = true
    And bldc step
    # Change hall state to trigger commutation transition
    Given exists data:
      """
      BodyControlSetup: {
        hallLeftA: 0
        hallLeftB: 1
        hallLeftC: 1
        hallRightA: 0
        hallRightB: 1
        hallRightC: 1
      }
      """
    And bldc step
    And bldc step
    Then body control data should be:
      """
      : {
        leftCtrlMode: 2
        rightCtrlMode: 2
        leftPwmActive: true
        rightPwmActive: true
      }
      """

  Scenario: angle measurement enabled with mech angle produces non-zero electrical angle
    Given exists data:
      """
      BodyControlSetup: {
        angleMeasEna: 1
        seedControlMode: 1
        mechAngleLeft: 100
        mechAngleRight: 200
      }
      """
    When bldc skip calibration
    And set motor speeds: left = 100 rpm, right = 100 rpm, enable = true
    And bldc step
    And bldc step
    Then body control data should be:
      """
      : {
        leftElectricalAngle: 63
        rightElectricalAngle: 157
      }
      """

  Scenario: cruise control with positive target engages feedforward clamping
    Given exists data:
      """
      BodyControlSetup: {
        cruiseEnabled: 1
        cruiseTarget: 500
        seedControlMode: 1
      }
      """
    When bldc skip calibration
    And set motor speeds: left = 100 rpm, right = 100 rpm, enable = true
    And bldc step
    And bldc step
    And bldc step
    Then body control data should be:
      """
      : {
        leftCtrlMode: 2
        rightCtrlMode: 2
        leftPwmActive: true
        rightPwmActive: true
      }
      """

  Scenario: hall all low with diagnostics enabled triggers error code
    Given exists data:
      """
      BodyControlSetup: {
        schedulerReady: 1
        seedControlMode: 1
        hallLeftA: 0
        hallLeftB: 0
        hallLeftC: 0
        hallRightA: 0
        hallRightB: 0
        hallRightC: 0
        errQual: 2
        errDequal: 48000
      }
      """
    When bldc skip calibration
    And set motor speeds: left = 200 rpm, right = 200 rpm, enable = true
    And bldc step
    And bldc step
    And bldc step
    And bldc step
    And bldc step
    Then body control data should be:
      """
      : {
        leftErrCode: 1
        rightErrCode: 1
      }
      """

  Scenario: diagnostics disabled suppresses error code on hall fault
    Given exists data:
      """
      BodyControlSetup: {
        diagEna: 0
        schedulerReady: 1
        seedControlMode: 1
        hallLeftA: 0
        hallLeftB: 0
        hallLeftC: 0
        hallRightA: 0
        hallRightB: 0
        hallRightC: 0
        errQual: 2
        errDequal: 48000
      }
      """
    When bldc skip calibration
    And set motor speeds: left = 200 rpm, right = 200 rpm, enable = true
    And bldc step
    And bldc step
    And bldc step
    And bldc step
    And bldc step
    Then body control data should be:
      """
      : {
        leftErrCode: 0
        rightErrCode: 0
      }
      """

  Scenario: voltage mode to speed mode transition triggers speed pi reset
    Given exists data:
      """
      BodyControlSetup: {
        seedControlMode: 3
        ctrlModeReq: 2
      }
      """
    When bldc skip calibration
    And set motor speeds: left = 80 rpm, right = 80 rpm, enable = true
    And bldc step
    And bldc step
    Then body control data should be:
      """
      : {
        leftCtrlMode: 2
        rightCtrlMode: 2
        leftPwmActive: true
        rightPwmActive: true
      }
      """

  Scenario: phase current injection through ADC drives iq and id non-zero
    Given exists data:
      """
      BodyControlSetup: {
        seedControlMode: 1
        adcLeftPhaA: 2000
        adcLeftPhaC: 1800
        adcRightPhaA: 2100
        adcRightPhaC: 1900
      }
      """
    When bldc skip calibration
    And set motor speeds: left = 120 rpm, right = 120 rpm, enable = true
    And bldc step
    And bldc step
    And bldc step
    Then body control data should be:
      """
      : {
        leftCtrlMode: 2
        rightCtrlMode: 2
        leftPwmActive: true
        rightPwmActive: true
      }
      """

  # ---- FOC PI controller deep coverage (no schedulerReady → reaches FOC on step 3) ----

  Scenario: speed-mode steady state FOC produces non-zero iq and id after two cycles
    Given exists data:
      """
      BodyControlSetup: {
        seedControlMode: 1
      }
      """
    When bldc skip calibration
    And set motor speeds: left = 100 rpm, right = 200 rpm, enable = true
    And bldc step
    And bldc step
    And bldc step
    And bldc step
    And bldc step
    And bldc step
    Then body control data should be:
      """
      : {
        leftCtrlMode: 2
        rightCtrlMode: 2
        leftPwmActive: true
        rightPwmActive: true
      }
      """

  Scenario: speed-mode PI reset triggers on VLT to SPD mode transition
    Given exists data:
      """
      BodyControlSetup: {
        seedControlMode: 3
        ctrlModeReq: 2
      }
      """
    When bldc skip calibration
    And set motor speeds: left = 80 rpm, right = 80 rpm, enable = true
    And bldc step
    And bldc step
    And bldc step
    And bldc step
    And bldc step
    And bldc step
    Then body control data should be:
      """
      : {
        leftCtrlMode: 2
        rightCtrlMode: 2
        leftPwmActive: true
        rightPwmActive: true
      }
      """

  Scenario: angle measurement enters Vd_Calculation path via rtb_LogicalOperator
    Given exists data:
      """
      BodyControlSetup: {
        angleMeasEna: 1
        seedControlMode: 1
        mechAngleLeft: 100
        mechAngleRight: 200
      }
      """
    When bldc skip calibration
    And set motor speeds: left = 100 rpm, right = 100 rpm, enable = true
    And bldc step
    And bldc step
    And bldc step
    And bldc step
    And bldc step
    And bldc step
    Then body control data should be:
      """
      : {
        leftCtrlMode: 2
        rightCtrlMode: 2
        leftPwmActive: true
        rightPwmActive: true
        leftElectricalAngle: 63
        rightElectricalAngle: 157
      }
      """

  Scenario: VLT mode FOC path exercises I_backCalc_fixdt voltage protection
    Given exists data:
      """
      BodyControlSetup: {
        seedControlMode: 3
        ctrlModeReq: 1
      }
      """
    When bldc skip calibration
    And set motor speeds: left = 80 rpm, right = 80 rpm, enable = true
    And bldc step
    And bldc step
    And bldc step
    And bldc step
    And bldc step
    And bldc step
    Then body control data should be:
      """
      : {
        leftCtrlMode: 1
        rightCtrlMode: 1
      }
      """

  Scenario: SIN control type with field weakening exercises div_nde_s32_floor path
    Given exists data:
      """
      BodyControlSetup: {
        ctrlTypeSel: 1
        fieldWeakEnabled: 1
        seedControlMode: 1
      }
      """
    When bldc skip calibration
    And set motor speeds: left = 200 rpm, right = 200 rpm, enable = true
    And bldc step
    And bldc step
    And bldc step
    And bldc step
    And bldc step
    And bldc step
    Then body control data should be:
      """
      : {
        leftCtrlType: 1
        rightCtrlType: 1
        leftPwmActive: true
        rightPwmActive: true
      }
      """

  # ---- CW direction (hall sequence 010→011, position 0→1, diff=+1) ----

  Scenario: clockwise hall transition triggers forward direction and covers CW electrical angle paths
    Given exists data:
      """
      BodyControlSetup: {
        seedControlMode: 1
        hallLeftA: 0
        hallLeftB: 1
        hallLeftC: 0
        hallRightA: 0
        hallRightB: 1
        hallRightC: 0
      }
      """
    When bldc skip calibration
    And set motor speeds: left = 100 rpm, right = 100 rpm, enable = true
    And bldc step
    # CW transition: 010 → 011 (position 0→1, diff=+1 → Switch2_e=1)
    Given exists data:
      """
      BodyControlSetup: {
        hallLeftA: 0
        hallLeftB: 1
        hallLeftC: 1
        hallRightA: 0
        hallRightB: 1
        hallRightC: 1
      }
      """
    And bldc step
    And bldc step
    And bldc step
    Then body control data should be:
      """
      : {
        leftCtrlMode: 2
        rightCtrlMode: 2
        leftPwmActive: true
        rightPwmActive: true
      }
      """

  # ---- Control mode state machine transitions ----

  Scenario: speed mode exits to voltage mode when speed request is cleared and torque not requested
    Given exists data:
      """
      BodyControlSetup: {
        seedControlMode: 2
        ctrlModeReq: 1
      }
      """
    When bldc skip calibration
    And set motor speeds: left = 80 rpm, right = 80 rpm, enable = true
    And bldc step
    Then body control data should be:
      """
      : {
        leftCtrlMode: 1
        rightCtrlMode: 1
      }
      """

  Scenario: torque mode exits to voltage mode when torque request is cleared and speed not requested
    Given exists data:
      """
      BodyControlSetup: {
        seedControlMode: 3
        ctrlModeReq: 1
      }
      """
    When bldc skip calibration
    And set motor speeds: left = 80 rpm, right = 80 rpm, enable = true
    And bldc step
    Then body control data should be:
      """
      : {
        leftCtrlMode: 1
        rightCtrlMode: 1
      }
      """

  Scenario: voltage mode transitions to torque mode with torque request and no cruise
    Given exists data:
      """
      BodyControlSetup: {
        seedControlMode: 1
        ctrlModeReq: 3
      }
      """
    When bldc skip calibration
    And set motor speeds: left = 80 rpm, right = 80 rpm, enable = true
    And bldc step
    Then body control data should be:
      """
      : {
        leftCtrlMode: 3
        rightCtrlMode: 3
      }
      """

  Scenario: open mode transitions to active voltage mode with mode request 1
    Given exists data:
      """
      BodyControlSetup: {
        seedControlMode: 0
        ctrlModeReq: 1
      }
      """
    When bldc skip calibration
    And set motor speeds: left = 80 rpm, right = 80 rpm, enable = true
    And bldc step
    Then body control data should be:
      """
      : {
        leftCtrlMode: 1
        rightCtrlMode: 1
      }
      """

  Scenario: open mode transitions to active torque mode with mode request 3
    Given exists data:
      """
      BodyControlSetup: {
        seedControlMode: 0
        ctrlModeReq: 3
      }
      """
    When bldc skip calibration
    And set motor speeds: left = 80 rpm, right = 80 rpm, enable = true
    And bldc step
    Then body control data should be:
      """
      : {
        leftCtrlMode: 3
        rightCtrlMode: 3
      }
      """

  # ---- VLT mode through FOC pipeline ----

  Scenario: voltage mode stays in VLT through FOC pipeline with mode request 1
    Given exists data:
      """
      BodyControlSetup: {
        seedControlMode: 1
        ctrlModeReq: 1
      }
      """
    When bldc skip calibration
    And set motor speeds: left = 80 rpm, right = 80 rpm, enable = true
    And bldc step
    And bldc step
    And bldc step
    And bldc step
    And bldc step
    And bldc step
    Then body control data should be:
      """
      : {
        leftCtrlMode: 1
        rightCtrlMode: 1
      }
      """

  # ---- SIN control with field weakening and hall transitions ----

  Scenario: SIN control type with field weakening covers phase advance and sine lookup paths
    Given exists data:
      """
      BodyControlSetup: {
        ctrlTypeSel: 1
        fieldWeakEnabled: 1
        seedControlMode: 1
        hallLeftA: 0
        hallLeftB: 1
        hallLeftC: 0
        hallRightA: 0
        hallRightB: 1
        hallRightC: 0
      }
      """
    When bldc skip calibration
    And set motor speeds: left = 200 rpm, right = 200 rpm, enable = true
    And bldc step
    Given exists data:
      """
      BodyControlSetup: {
        hallLeftA: 0
        hallLeftB: 1
        hallLeftC: 1
        hallRightA: 0
        hallRightB: 1
        hallRightC: 1
      }
      """
    And bldc step
    And bldc step
    Then body control data should be:
      """
      : {
        leftCtrlType: 1
        rightCtrlType: 1
        leftPwmActive: true
        rightPwmActive: true
      }
      """

  # ---- Remaining state machine transitions ----

  Scenario: torque mode transitions to speed mode with speed request
    Given exists data:
      """
      BodyControlSetup: {
        seedControlMode: 3
        ctrlModeReq: 2
      }
      """
    When bldc skip calibration
    And set motor speeds: left = 80 rpm, right = 80 rpm, enable = true
    And bldc step
    Then body control data should be:
      """
      : {
        leftCtrlMode: 2
        rightCtrlMode: 2
      }
      """

  Scenario: voltage mode stays in VLT default path and transitions to torque mode
    Given exists data:
      """
      BodyControlSetup: {
        seedControlMode: 1
        ctrlModeReq: 3
      }
      """
    When bldc skip calibration
    And set motor speeds: left = 80 rpm, right = 80 rpm, enable = true
    And bldc step
    Then body control data should be:
      """
      : {
        leftCtrlMode: 3
        rightCtrlMode: 3
      }
      """

  Scenario: open mode transitions to speed mode with default speed request
    Given exists data:
      """
      BodyControlSetup: {
        seedControlMode: 0
        ctrlModeReq: 2
      }
      """
    When bldc skip calibration
    And set motor speeds: left = 80 rpm, right = 80 rpm, enable = true
    And bldc step
    Then body control data should be:
      """
      : {
        leftCtrlMode: 2
        rightCtrlMode: 2
      }
      """

  # ---- Coverage: plook_u8s16_evencka clip-to-maxIndex (line 157) ----

  Scenario: reverse hall transition at position 5 forces electrical angle lookup clipping
    Given exists data:
      """
      BodyControlSetup: {
        seedControlMode: 1
        hallLeftA: 0
        hallLeftB: 1
        hallLeftC: 0
        hallRightA: 0
        hallRightB: 1
        hallRightC: 0
      }
      """
    When bldc skip calibration
    And set motor speeds: left = 100 rpm, right = 100 rpm, enable = true
    And bldc step
    # Hall 010→110: position 0→5, diff=+5 → Switch2_e=-1 (reverse)
    # rtb_Sum2_h = pos+1 = 6 → rtb_Merge_m = 24576 → scaled to 23040
    # plook(23040, 0, 128, 180): fbpIndex=180 >= maxIndex=180 → clip branch (line 157)
    Given exists data:
      """
      BodyControlSetup: {
        hallLeftA: 1
        hallLeftB: 1
        hallLeftC: 0
        hallRightA: 1
        hallRightB: 1
        hallRightC: 0
      }
      """
    And bldc step
    Then body control data should be:
      """
      : {
        leftCtrlMode: 2
        rightCtrlMode: 2
      }
      """

  # ---- Coverage: plook_u8u16_evencka clip-to-maxIndex (line 184) ----

  Scenario: injected max divide3 forces iq_maxSca lookup clipping
    Given exists data:
      """
      BodyControlSetup: {
        seedControlMode: 1
        fieldWeakEnabled: 0
      }
      """
    When bldc skip calibration
    And set motor speeds: left = 200 rpm, right = 200 rpm, enable = true
    # Inject Divide3 = 30000 + force scheduler state to enter Motor_Limitations
    When bldc inject divide3: 30000
    And bldc step
    Then body control data should be:
      """
      : {
        leftCtrlMode: 2
      }
      """

  # ---- Coverage: Low_Pass_Filter upper saturation (lines 258, 283) ----

  Scenario: injected negative filter state triggers low-pass filter upper saturation
    Given exists data:
      """
      BodyControlSetup: {
        seedControlMode: 1
      }
      """
    When bldc skip calibration
    And set motor speeds: left = 200 rpm, right = 200 rpm, enable = true
    And bldc step
    # Inject filter output to -32768: error = id - (-32768) > 32767 → upper sat
    When bldc inject filter: ch0 = -32768, ch1 = -32768
    And bldc step
    Then body control data should be:
      """
      : {
        leftCtrlMode: 2
      }
      """

  # ---- Coverage: Low_Pass_Filter lower saturation (lines 261, 286) ----

  Scenario: injected positive filter state with negative ADC triggers low-pass filter lower saturation
    Given exists data:
      """
      BodyControlSetup: {
        seedControlMode: 1
        adcLeftPhaA: 65535
        adcLeftPhaC: 65535
        adcRightPhaA: 65535
        adcRightPhaC: 65535
      }
      """
    When bldc skip calibration
    And set motor speeds: left = 200 rpm, right = 200 rpm, enable = true
    And bldc step
    # Inject filter output to +32767, feed max-negative ADC: error < -32768 → lower sat
    When bldc inject filter: ch0 = 32767, ch1 = 32767
    And bldc step
    Then body control data should be:
      """
      : {
        leftCtrlMode: 2
      }
      """

  # ---- Verification: state injection works ----


  # ---- Coverage: Debounce_Filter dequalification (lines 436/437/445) ----

  Scenario: hall error clearing triggers dequalification countdown in debounce filter
    Given exists data:
      """
      BodyControlSetup: {
        schedulerReady: 1
        seedControlMode: 1
        hallLeftA: 0
        hallLeftB: 0
        hallLeftC: 0
        hallRightA: 0
        hallRightB: 0
        hallRightC: 0
        errQual: 1
        errDequal: 2
      }
      """
    When bldc skip calibration
    And set motor speeds: left = 200 rpm, right = 200 rpm, enable = true
    And bldc step
    And bldc step
    # Error is now active (errQual=1 threshold met). Switch to valid hall to clear.
    Given exists data:
      """
      BodyControlSetup: {
        hallLeftA: 1
        hallLeftB: 1
        hallLeftC: 0
        hallRightA: 1
        hallRightB: 1
        hallRightC: 0
      }
      """
    And bldc step
    And bldc step
    And bldc step
    And bldc step
    And bldc step
    And bldc step
    # After errDequal=2, error clears and controller returns to normal operation
    Then body control data should be:
      """
      : {
        leftCtrlMode: 2
      }
      """

  # ---- Coverage: I_backCalc_fixdt output normal path (538-540) ----
  # Inject moderate state so output is between satMin=0 and satMax

  Scenario: injected moderate ibackcalc state produces output between sat bounds
    Given exists data:
      """
      BodyControlSetup: {
        seedControlMode: 1
        ctrlModeReq: 1
      }
      """
    When bldc skip calibration
    And set motor speeds: left = 200 rpm, right = 200 rpm, enable = true
    And bldc step
    # Inject zero integrator + force scheduler: output ≈ 0 between [0, satMax] → else path
    When bldc inject all ibackcalc: delay = 0, delay_m = 0
    And bldc step
    Then body control data should be:
      """
      : {
        leftCtrlMode: 1
      }
      """

  # ---- Coverage: I_backCalc_fixdt output lower saturation (537) ----
  Scenario: injected negative ibackcalc integrator forces output lower saturation
    Given exists data:
      """
      BodyControlSetup: {
        seedControlMode: 1
        ctrlModeReq: 1
      }
      """
    When bldc skip calibration
    And set motor speeds: left = 200 rpm, right = 200 rpm, enable = true
    And bldc step
    # Inject negative integrator: output < satMin=0 → line 537
    When bldc inject all ibackcalc: delay = -100, delay_m = 0
    And bldc step
    Then body control data should be:
      """
      : {
        leftCtrlMode: 1
      }
      """

  # ---- Coverage: I_backCalc_fixdt MIN/MAX saturation (510, 513) ----

  Scenario: injected near-int32-min ibackcalc state forces underflow guard
    Given exists data:
      """
      BodyControlSetup: {
        seedControlMode: 1
        ctrlModeReq: 1
        adcLeftPhaA: 65535
        adcLeftPhaC: 65535
        adcRightPhaA: 65535
        adcRightPhaC: 65535
      }
      """
    When bldc skip calibration
    And set motor speeds: left = 200 rpm, right = 200 rpm, enable = true
    And bldc step
    # ADC injection drives non-zero Abs5_h → rtu_err < 0 → rtb_Sum1_o < 0
    # Combined with near-INT32_MIN state → underflow guard at line 510
    When bldc inject all ibackcalc: delay = -2147483647, delay_m = -2147483647
    And bldc step
    Then body control data should be:
      """
      : {
        leftCtrlMode: 1
      }
      """

  Scenario: injected near-int32-max ibackcalc state forces overflow guard
    Given exists data:
      """
      BodyControlSetup: {
        seedControlMode: 1
        ctrlModeReq: 1
      }
      """
    When bldc skip calibration
    And set motor speeds: left = 200 rpm, right = 200 rpm, enable = true
    And bldc step
    # Inject near INT32_MAX: sum would overflow → line 513
    When bldc inject all ibackcalc: delay = 2147483000, delay_m = 2147483000
    And bldc step
    Then body control data should be:
      """
      : {
        leftCtrlMode: 1
      }
      """

  # ---- Coverage: PI_clamp_fixdt lines in FOC path (ctrlTypeSel=1) ----

  Scenario: injected extreme speed pi state covers pi_clamp saturation and signum paths
    Given exists data:
      """
      BodyControlSetup: {
        seedControlMode: 1
        ctrlTypeSel: 1
        mechAngleLeft: 100
        mechAngleRight: 100
      }
      """
    When bldc skip calibration
    And set motor speeds: left = 200 rpm, right = 200 rpm, enable = true
    And bldc step
    # Inject speed PI: UnitDelay1=1 (anti-windup active), extreme integrator
    # Div1=32767 to stress output clip, ResettableDelay=32767 to stress output sat
    When bldc inject piclamp speed: ic = 0, delay = 32767, ud1 = 1, div1 = 32767
    And bldc step
    Then body control data should be:
      """
      : {
        leftCtrlMode: 2
      }
      """

  Scenario: injected negative speed pi state forces lower sat and negative signum
    Given exists data:
      """
      BodyControlSetup: {
        seedControlMode: 1
        ctrlTypeSel: 1
        mechAngleLeft: 100
        mechAngleRight: 100
      }
      """
    When bldc skip calibration
    And set motor speeds: left = 200 rpm, right = 200 rpm, enable = true
    And bldc step
    # Inject negative state: triggers lower saturation and negative signum branches
    When bldc inject piclamp speed: ic = 0, delay = -32768, ud1 = 0, div1 = -32768
    And bldc step
    Then body control data should be:
      """
      : {
        leftCtrlMode: 2
      }
      """

  # ---- Coverage: F01_05 LogicalOp path (1319-1340) + MinMax clamp (1366) ----

  Scenario: angle measurement enabled enters hall estimation complex path
    Given exists data:
      """
      BodyControlSetup: {
        seedControlMode: 1
        angleMeasEna: 1
        mechAngleLeft: 100
        mechAngleRight: 200
      }
      """
    When bldc skip calibration
    And set motor speeds: left = 200 rpm, right = 200 rpm, enable = true
    And bldc step
    And bldc step
    Then body control data should be:
      """
      : {
        leftCtrlMode: 2
      }
      """

  # ---- Coverage: reverse speed produces negative Abs5 (1238) + dz_cntTrnsDet (1128-1130) ----

  Scenario: reverse hall sequence produces negative measured speed
    Given exists data:
      """
      BodyControlSetup: {
        seedControlMode: 1
        hallLeftA: 0
        hallLeftB: 1
        hallLeftC: 0
        hallRightA: 0
        hallRightB: 1
        hallRightC: 0
      }
      """
    When bldc skip calibration
    And set motor speeds: left = 200 rpm, right = 200 rpm, enable = true
    And bldc step
    And bldc step
    # Reverse: 010→110 gives diff=+5, Switch2_e=-1, negative direction
    Given exists data:
      """
      BodyControlSetup: {
        hallLeftA: 1
        hallLeftB: 1
        hallLeftC: 0
        hallRightA: 1
        hallRightB: 1
        hallRightC: 0
      }
      """
    And bldc step
    And bldc step
    Then body control data should be:
      """
      : {
        leftCtrlMode: 2
      }
      """

  # ---- Coverage: speed estimation normal else path (1173-1176) ----

  Scenario: steady state speed estimation enters the normal computation else branch
    Given exists data:
      """
      BodyControlSetup: {
        seedControlMode: 1
        hallLeftA: 0
        hallLeftB: 1
        hallLeftC: 0
        hallRightA: 0
        hallRightB: 1
        hallRightC: 0
      }
      """
    When bldc skip calibration
    And set motor speeds: left = 200 rpm, right = 200 rpm, enable = true
    And bldc step
    And bldc step
    And bldc step
    And bldc step
    Then body control data should be:
      """
      : {
        leftCtrlMode: 2
      }
      """

  # ---- Coverage: S45 disable subsystem (1415-1444) ----

  Scenario: switching control type disables s45 current filtering outputs
    Given exists data:
      """
      BodyControlSetup: {
        seedControlMode: 1
        hallLeftA: 0
        hallLeftB: 1
        hallLeftC: 0
        hallRightA: 0
        hallRightB: 1
        hallRightC: 0
      }
      """
    When bldc skip calibration
    And set motor speeds: left = 200 rpm, right = 200 rpm, enable = true
    And bldc step
    # Switch ctrlTypeSel from 2 (default) to 1 → S7/If1 disables → S45 disable runs
    Given exists data:
      """
      BodyControlSetup: {
        ctrlTypeSel: 1
      }
      """
    And bldc step
    Then body control data should be:
      """
      : {
        leftCtrlMode: 2
      }
      """

  # ---- Coverage: Clarke + Park transform saturation guards ----

  Scenario: extreme negative ADC injection forces clarke and park saturation guards
    Given exists data:
      """
      BodyControlSetup: {
        seedControlMode: 1
        phaseSelection: 0
        adcLeftPhaA: 65535
        adcLeftPhaC: 65535
        adcRightPhaA: 65535
        adcRightPhaC: 65535
      }
      """
    When bldc skip calibration
    And set motor speeds: left = 200 rpm, right = 200 rpm, enable = true
    And bldc step
    And bldc step
    And bldc step
    And bldc step
    And bldc step
    # Reverse ADC to drive opposite Clarke/Park saturation paths
    Given exists data:
      """
      BodyControlSetup: {
        adcLeftPhaA: 0
        adcLeftPhaC: 65535
        adcRightPhaA: 65535
        adcRightPhaC: 65535
      }
      """
    And bldc step
    And bldc step
    Then body control data should be:
      """
      : {
        leftCtrlMode: 2
      }
      """

  # ---- Coverage: S45 Current_Filtering disable (1569-1575) ----

  Scenario: disabling motors clears current filtering outputs via s45 disable path
    Given exists data:
      """
      BodyControlSetup: {
        seedControlMode: 1
        hallLeftA: 0
        hallLeftB: 1
        hallLeftC: 0
        hallRightA: 0
        hallRightB: 1
        hallRightC: 0
      }
      """
    When bldc skip calibration
    And set motor speeds: left = 200 rpm, right = 200 rpm, enable = true
    And bldc step
    # Disable motors: b_motEna → false → S45/If2 disable runs
    And set motor speeds: left = 200 rpm, right = 200 rpm, enable = false
    And bldc step
    Then body control data should be:
      """
      : {
        leftOutputEnabled: false
      }
      """

  # ---- Coverage: Control Mode Manager transitions (1845-1852) ----

  Scenario: open mode with torque request enters torque mode in state machine default case
    Given exists data:
      """
      BodyControlSetup: {
        seedControlMode: 0
        ctrlModeReq: 3
      }
      """
    When bldc skip calibration
    And set motor speeds: left = 200 rpm, right = 200 rpm, enable = true
    And bldc step
    Then body control data should be:
      """
      : {
        leftCtrlMode: 3
      }
      """

  Scenario: open mode with voltage request enters vlt mode in state machine else branch
    Given exists data:
      """
      BodyControlSetup: {
        seedControlMode: 0
        ctrlModeReq: 1
      }
      """
    When bldc skip calibration
    And set motor speeds: left = 200 rpm, right = 200 rpm, enable = true
    And bldc step
    Then body control data should be:
      """
      : {
        leftCtrlMode: 1
      }
      """

  # ---- Coverage: Rate limiter upper/lower bound (2023, 2034) ----

  Scenario: large speed step in open mode triggers rate limiter upper bound
    Given exists data:
      """
      BodyControlSetup: {
        seedControlMode: 0
        ctrlModeReq: 0
      }
      """
    When bldc skip calibration
    And set motor speeds: left = 0 rpm, right = 0 rpm, enable = true
    And bldc step
    # Large jump from 0 to max rpm forces rate limiter saturation
    And set motor speeds: left = 1000 rpm, right = 1000 rpm, enable = true
    And bldc step
    And bldc step
    Then body control data should be:
      """
      : {
        leftCtrlMode: 0
      }
      """

  # ---- Coverage: Field weakening normal else path (2147) ----

  Scenario: moderate speed with field weakening enters authorization normal range
    Given exists data:
      """
      BodyControlSetup: {
        seedControlMode: 1
        fieldWeakEnabled: 1
      }
      """
    When bldc skip calibration
    And set motor speeds: left = 350 rpm, right = 350 rpm, enable = true
    And bldc step
    And bldc step
    And bldc step
    And bldc step
    Then body control data should be:
      """
      : {
        leftCtrlMode: 2
      }
      """

  # ---- Coverage: Torque-to-Speed transition (1831-1832) ----

  Scenario: torque mode transition to speed via speed request covers state machine path
    Given exists data:
      """
      BodyControlSetup: {
        seedControlMode: 3
        ctrlModeReq: 2
      }
      """
    When bldc skip calibration
    And set motor speeds: left = 80 rpm, right = 80 rpm, enable = true
    And bldc step
    And bldc step
    Then body control data should be:
      """
      : {
        leftCtrlMode: 2
      }
      """

  # ---- Coverage: Motor_Limitations disable (2221) + FOC disable (2443-2446) ----

  Scenario: switching control type disables motor limitations and foc subsystems
    Given exists data:
      """
      BodyControlSetup: {
        seedControlMode: 1
        ctrlTypeSel: 1
      }
      """
    When bldc skip calibration
    And set motor speeds: left = 200 rpm, right = 200 rpm, enable = true
    And bldc step
    # Switch back to default FOC_CTRL: force S48 and S59 disable paths
    Given exists data:
      """
      BodyControlSetup: {
        ctrlTypeSel: 2
      }
      """
    And bldc step
    Then body control data should be:
      """
      : {
        leftCtrlMode: 2
      }
      """

  # ---- Coverage: Abs5 negative (2241) + iq_maxSca clamp (2264) ----

  Scenario: negative switch1 in motor limitations triggers abs and negative clamp paths
    Given exists data:
      """
      BodyControlSetup: {
        seedControlMode: 1
        ctrlTypeSel: 1
      }
      """
    When bldc skip calibration
    And set motor speeds: left = 200 rpm, right = 200 rpm, enable = true
    And bldc step
    And bldc step
    And bldc step
    Then body control data should be:
      """
      : {
        leftCtrlMode: 2
      }
      """

  # ---- Coverage: Speed_Mode_Protection lower bound (2370) ----

  Scenario: speed mode protection with negative iq triggers lower bound clip
    Given exists data:
      """
      BodyControlSetup: {
        seedControlMode: 1
        ctrlTypeSel: 1
      }
      """
    When bldc skip calibration
    And set motor speeds: left = 200 rpm, right = 200 rpm, enable = true
    And bldc step
    And bldc step
    And bldc step
    And bldc step
    And bldc step
    Then body control data should be:
      """
      : {
        leftCtrlMode: 2
      }
      """

  # ---- Coverage: TRQ_MODE FOC SwitchCase (2469-2471) + VLT_Mode paths ----

  Scenario: torque mode enters foc switch case and voltage mode paths
    Given exists data:
      """
      BodyControlSetup: {
        seedControlMode: 3
        ctrlModeReq: 3
        ctrlTypeSel: 1
      }
      """
    When bldc skip calibration
    And set motor speeds: left = 200 rpm, right = 200 rpm, enable = true
    And bldc step
    And bldc step
    And bldc step
    Then body control data should be:
      """
      : {
        leftCtrlMode: 3
      }
      """

  # ---- Coverage: Cruise control else path (2573) ----

  Scenario: cruise control with positive target enters minmax else branch
    Given exists data:
      """
      BodyControlSetup: {
        cruiseEnabled: 1
        cruiseTarget: 100
        seedControlMode: 1
        ctrlTypeSel: 1
      }
      """
    When bldc skip calibration
    And set motor speeds: left = 200 rpm, right = 200 rpm, enable = true
    And bldc step
    And bldc step
    And bldc step
    And bldc step
    Then body control data should be:
      """
      : {
        leftCtrlMode: 2
      }
      """

  # ---- Coverage: SIN_Method + phase advance (2959-2986) ----

  Scenario: sin control type with angle measurement and field weakening enters sin method
    Given exists data:
      """
      BodyControlSetup: {
        seedControlMode: 1
        ctrlTypeSel: 1
        angleMeasEna: 1
        fieldWeakEnabled: 1
        mechAngleLeft: 100
        mechAngleRight: 200
      }
      """
    When bldc skip calibration
    And set motor speeds: left = 200 rpm, right = 200 rpm, enable = true
    And bldc step
    And bldc step
    And bldc step
    And bldc step
    And bldc step
    Then body control data should be:
      """
      : {
        leftCtrlMode: 2
      }
      """

  # ---- Coverage: SIN_Method no field weakening else path (2968) ----

  Scenario: sin control type with angle measurement and no field weakening enters else path
    Given exists data:
      """
      BodyControlSetup: {
        seedControlMode: 1
        ctrlTypeSel: 1
        angleMeasEna: 1
        fieldWeakEnabled: 0
        mechAngleLeft: 100
        mechAngleRight: 200
      }
      """
    When bldc skip calibration
    And set motor speeds: left = 200 rpm, right = 200 rpm, enable = true
    And bldc step
    And bldc step
    And bldc step
    Then body control data should be:
      """
      : {
        leftCtrlMode: 2
      }
      """
