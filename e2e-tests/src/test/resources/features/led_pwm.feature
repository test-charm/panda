# language: en
Feature: LED PWM initialization

  led_init() configures TIM3 PWM channels for boards with PWM-driven LEDs.
  Only cuatro uses PWM LEDs ({1, 2, 4}); tres and red use pure GPIO.
  led_init() runs during jna_panda_init() before any scenario starts.

  @cuatro
  Scenario: Cuatro led_init configures TIM3 CR1 with counter enable and auto-reload preload
    Then control data should be:
      """
      : {
        ledPwmState: {
          tim3Cr1: 1
          tim3Arr: 4800
        }
      }
      """

  @cuatro
  Scenario: Cuatro led_init configures TIM3 CCMR for PWM mode 1 with preload on channels 1, 2, 4
    Then control data should be:
      """
      : {
        ledPwmState: {
          tim3Ccmr1: 26728
          tim3Ccmr2: 26624
        }
      }
      """

  @cuatro
  Scenario: Cuatro led_init enables TIM3 CCER outputs for channels 1, 2, 4
    Then control data should be:
      """
      : {
        ledPwmState: {
          tim3Ccer: 4113
        }
      }
      """

  @cuatro
  Scenario: Cuatro led_init sets CCR registers to 100% duty (LEDs off after init)
    Then control data should be:
      """
      : {
        ledPwmState: {
          tim3Ccr1: 4800
          tim3Ccr2: 4800
          tim3Ccr3: 0
          tim3Ccr4: 4800
        }
      }
      """

  @tres
  Scenario: Tres init writes pwm_init TIM3 channel 4 for IR via tres_init
    When board init
    Then control data should be:
      """
      : {
        ledPwmState: {
          tim3Cr1: 1
          tim3Arr: 4800
          tim3Ccmr1: 0
          tim3Ccmr2: 26624
          tim3Ccer: 4096
          tim3Ccr4: 0
        }
      }
      """

  @tres
  Scenario: Tres led_init does not touch TIM3 (GPIO-only LEDs)
    Then control data should be:
      """
      : {
        ledPwmState: {
          tim3Ccr1: 0
          tim3Ccr2: 0
          tim3Ccr3: 0
        }
      }
      """
