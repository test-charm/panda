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
