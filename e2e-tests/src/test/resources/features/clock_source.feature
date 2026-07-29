# language: en
Feature: Custom Clock Source Configuration

  Scenario: Setting clock source writes correct TIM register values
    When control write:
      """
      UsbControlRequest: {
        request: -26y
        param1: 100
        param2: 50
      }
      """
    Then control data should be:
      """
      : {
        clockSource= {
          ccr1: 0        # ((100 & 0xFF00) >> 8) * 10
          ccr2: 1000     # (100 & 0xFF) * 10
          ccr3: 0        # ((50 & 0xFF00) >> 8) * 10
          arr: 499       # ((50 & 0xFF) * 10) - 1
          ccr4: 250      # (499 + 1) / 2
        }
      }
      """

  Scenario: Setting clock source to zero produces underflow for ARR
    When control write:
      """
      SetClockSource: {
        param1: 0
        param2: 0
      }
      """
    Then control data should be:
      """
      : {
        clockSource= {
          ccr1: 0
          ccr2: 0
          ccr3: 0
          arr: 65535     # ((0 & 0xFF) * 10) - 1, masked to 0xFFFF
          ccr4: (65535 + 1) / 2
        }
      }
      """

  Scenario: Setting clock source with max values splits correctly
    When control write:
      """
      UsbControlRequest: {
        request: -26y
        param1: 32767
        param2: 32767
      }
      """
    Then control data should be:
      """
      : {
        clockSource= {
          ccr1: 1270     # ((0x7FFF & 0xFF00) >> 8) * 10 = 127 * 10
          ccr2: 2550     # (0x7FFF & 0xFF) * 10 = 255 * 10
          ccr3: 1270     # same as ccr1
          arr: (255 * 10) - 1
          ccr4: (2549 + 1) / 2
        }
      }
      """

  # ---- clock source init (merged from clock_source_init.feature) ----
  # clock_source_init(bool enable_channel1) configures TIM1 as master timer
  # (0.1ms tick) and TIM8 as slave timer (external clock mode 1, triggered
  # by TIM1). Also sets up GPIO alternate functions for timer output channels.

  Scenario: Init with channel1 enabled configures TIM1 master, TIM8 slave, and GPIO
    When clock source init with channel1 enabled
    Then control data should be:
      """
      : {
        clockSourceInit= {
          # TIM1 master timer
          tim1Psc: 51199
          tim1Arr: 499
          tim1Ccmr1: 24672
          tim1Ccmr2: 28768
          tim1Ccer: 5
          tim1Ccr1: 20
          tim1Ccr2: 20
          tim1Ccr4: 250
          tim1Dier: 3
          tim1Smcr: 0
          tim1Cr1: 1
          tim1Cr2: 112
          tim1Bdtr: 32768

          # TIM8 slave timer
          tim8Psc: 51199
          tim8Arr: 499
          tim8Ccmr2: 96
          tim8Ccr3: 20
          tim8Ccer: 16
          tim8Smcr: 4
          tim8Cr1: 1
          tim8Bdtr: 32768

          # GPIOA (pin 8 alternate = AF1_TIM1)
          gpioAModer: 131072
          gpioAAfr1: 1

          # GPIOB (pin 14 alternate = AF1_TIM1, pin 15 alternate = AF3_TIM8)
          gpioBModer: 2684354560
          gpioBAfr1: 822083584

          # NVIC IRQ disable calls
          nvicDisableIrqCount: 2
          nvicDisableIrq0: 25
          nvicDisableIrq1: 27
        }
      }
      """

  Scenario: Init with channel1 disabled does not enable GPIOA8 alternate
    When clock source init with channel1 disabled
    Then control data should be:
      """
      : {
        clockSourceInit: {
          gpioAModer: 0
          gpioAAfr1: 0
        }
      }
      """

  Scenario: Init with channel1 disabled still enables GPIOB14 and GPIOB15
    When clock source init with channel1 disabled
    Then control data should be:
      """
      : {
        clockSourceInit: {
          gpioBModer: 2684354560
          gpioBAfr1: 822083584
        }
      }
      """

  Scenario: BDTR MOE bit is set on both timers after init
    When clock source init with channel1 enabled
    Then control data should be:
      """
      : {
        clockSourceInit: {
          tim1Bdtr: 32768
          tim8Bdtr: 32768
        }
      }
      """

  Scenario: Both TIM1 and TIM8 CEN bits are set after init
    When clock source init with channel1 enabled
    Then control data should be:
      """
      : {
        clockSourceInit: {
          tim1Cr1: 1
          tim8Cr1: 1
        }
      }
      """

  Scenario: Init disables TIM1 update and capture-compare interrupts via NVIC
    When clock source init with channel1 enabled
    Then control data should be:
      """
      : {
        clockSourceInit: {
          nvicDisableIrqCount: 2
          nvicDisableIrq0: 25
          nvicDisableIrq1: 27
        }
      }
      """