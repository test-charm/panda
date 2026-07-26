# language: en
Feature: Clock Source Initialization

  clock_source_init(bool enable_channel1) configures TIM1 as master timer (0.1ms tick)
  and TIM8 as slave timer (external clock mode 1, triggered by TIM1).
  It also sets up GPIO alternate functions for timer output channels.

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
