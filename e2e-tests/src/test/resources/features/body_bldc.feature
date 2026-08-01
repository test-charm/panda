# language: en
@body
Feature: Body Firmware BLDC Motor Control

  Scenario: B8/B13/B21 — startup initializes board GPIO, BLDC PWM, and body CAN
    Then body control data should be:
      """
      : {
        leftTimerEnabled: true
        rightTimerEnabled: true
        canRxMode: 2
        canTxMode: 2
        canRxAf: 9
        canTxAf: 9
        obdcPowerMode: 1
        gpuPowerMode: 1
        ignitionOutputMode: 1
        chargingDetectPupdr: 1
        exticr3: 8224
        extiImr1: 40960
        extiRtsr1: 40960
        extiFtsr1: 40960
        obdcPowerOn: true
        gpuPowerOn: false
        ignitionOutputOn: false
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
