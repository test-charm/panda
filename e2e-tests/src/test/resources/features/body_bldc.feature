# language: en
@body
Feature: Body Firmware BLDC Motor Control

  Scenario: B8 — BLDC initialization at startup sets up TIM8 and TIM1 for PWM
    Then body control data should be:
      """
      : {
        leftTimerEnabled: true
        rightTimerEnabled: true
      }
      """
