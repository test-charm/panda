# language: en
@body
Feature: Body Firmware BLDC Motor Control

  Scenario: B8/B13 — startup initializes BLDC PWM and body CAN
    Then body control data should be:
      """
      : {
        leftTimerEnabled: true
        rightTimerEnabled: true
        bodyCan: {
          canSilent: false
          canLoopback: false
          bodySafetyHooksSet: true
          canTransceiverEnabled: true
        }
      }
      """

  Scenario: B9 — bldc_step executes FOC algorithm and generates PWM output on TIM8 and TIM1
    When bldc skip calibration
    When set motor speeds: left = 100 rpm, right = 200 rpm, enable = true
    When bldc step
    Then body control data should be:
      """
      : {
        leftPwmActive: true
        rightPwmActive: true
      }
      """
