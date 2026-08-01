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
        schedulerReady: 1
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
        schedulerReady: 1
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
        schedulerReady: 1
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
        schedulerReady: 1
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
        schedulerReady: 1
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
        schedulerReady: 1
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
        schedulerReady: 1
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
