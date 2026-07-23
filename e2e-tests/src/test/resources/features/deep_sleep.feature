# language: en
Feature: Deep Sleep Request

  Scenario: Requesting deep sleep sets SILENT mode, power save, and stop mode
    When control write:
      """
      UsbControlRequest: {
        request: -75y
        param1: 0
        param2: 0
      }
      """
    Then control data should be:
      """
      : {
        stopModeRegs: {
          gpioAOdr: 520L
        }
        powerSaveEnabled: true
        stopModeRequested: true
        powerSaveTracking: {
          irqDisableCount: 2
        }
      }
      """

  @cuatro
  Scenario: Entering stop mode configures all GPIO MODER bits (analog → output / input)
    Given exists data:
      """
      RequestDeepSleep: { ... }
      """
    When process stop mode:
    Then control data should be:
      """
      : {
        enterStopModeCallCount: 1
        stopModeRegs: {
          gpioAModer: 0xFFFFFFF1  # PA0→output(bootkick), PA1→input(SBU2)
          gpioBModer: 0xFF5C73FD  # PB0→output(amp), PB5/8→input(CAN2/1), PB7/10/11→output(CAN)
          gpioCModer: 0xFF7FFCFF  # PC4→input(SBU1), PC11→output(bootkick)
          gpioDModer: 0xFCFDFFFF  # PD8→output(CAN3), PD12→input(CAN3 RX)
          gpioEModer: 0xFFFFFFFF
          gpioFModer: 0xFFFFFFFF
          gpioGModer: 0xFFFFFFFF
        }
      }
      """

  @tres
  Scenario: Entering stop mode configures GPIO MODER for tres board
    Given exists data:
      """
      RequestDeepSleep: { ... }
      """
    When process stop mode:
    Then control data should be:
      """
      : {
        enterStopModeCallCount: 1
        stopModeRegs: {
          gpioAModer: 0xFFFFFFF1  # PA0→output(bootkick), PA1→input(SBU2)
          gpioBModer: 0xFF5CF3FF  # PB5/8→input(CAN), PB10/11→output(CAN2/4)
          gpioCModer: 0xFDFFFCFF  # PC4→input(SBU1), PC12→output(bootkick)
          gpioDModer: 0xFCFF7FFF  # PD7→output(tied-CAN), PD12→input(CAN3 RX)
          gpioGModer: 0xFF7FFFFF  # PG11→output(tied-CAN)
        }
      }
      """

  @red
  Scenario: Entering stop mode configures GPIO MODER for red board
    Given exists data:
      """
      RequestDeepSleep: { ... }
      """
    When process stop mode:
    Then control data should be:
      """
      : {
        enterStopModeCallCount: 1
        stopModeRegs: {
          gpioAModer: 0xFFFFFFF3  # PA1→input(SBU2), no bootkick
          gpioBModer: 0xFFFCF17F  # PB3/4→output(CAN2/4), PB5/8→input(CAN)
          gpioCModer: 0xFFFFFCFF  # PC4→input(SBU1)
          gpioDModer: 0xFCFF7FFF  # PD7→output(CAN3), PD12→input(CAN3 RX)
          gpioEModer: 0xFFFFFFFF
          gpioFModer: 0xFFFFFFFF
          gpioGModer: 0xFF7FFFFF  # PG11→output(CAN1)
        }
      }
      """

  Scenario: Entering stop mode disables ADCs in deep power-down
    Given exists data:
      """
      RequestDeepSleep: { ... }
      """
    When process stop mode:
    Then control data should be:
      """
      : {
        stopModeRegs: {
          adc1Cr: 0x20000000     # ADC_CR_DEEPPWD, ADEN cleared
          adc2Cr: 0x20000000
        }
      }
      """

  Scenario: Entering stop mode clears HSI48 clock enable
    Given exists data:
      """
      RequestDeepSleep: { ... }
      """
    When process stop mode:
    Then control data should be:
      """
      : {
        stopModeRegs: {
          rccCr: 0b0000_0000y               # HSI48ON bit cleared
        }
      }
      """

  Scenario: Entering stop mode disables SRAM retention in all domains
    Given exists data:
      """
      RequestDeepSleep: { ... }
      """
    When process stop mode:
    Then control data should be:
      """
      : {
        stopModeRegs: {
          rccAhb2lpenr: 0b0000_0000y         # SRAM1LPEN + SRAM2LPEN cleared
          rccAhb3lpenr: 0b0000_0000y         # AXISRAMLPEN cleared
          rccAhb4lpenr: 0b0000_0000y         # SRAM4LPEN cleared
        }
      }
      """

  Scenario: Entering stop mode configures EXTI for SBU1/2 and CAN wakeup
    Given exists data:
      """
      RequestDeepSleep: { ... }
      """
    When process stop mode:
    Then control data should be:
      """
      : {
        stopModeRegs: {
          syscfgExticr0: 0b0000_0000y       # EXTI1_PA
          syscfgExticr1: 0b0001_0010y      # EXTI4_PC(0x02) | EXTI5_PB(0x10) = 0x12
          syscfgExticr2: 0b0000_0001y       # EXTI8_PB
          syscfgExticr3: 0b0000_0011y       # EXTI12_PD
          extiImr1: 4402L         # SBU(1,4)=18 + CAN(5,8,12)=4384
          extiRtsr1: 0b0001_0010y          # SBU only: bits 1,4
          extiFtsr1: 4402L        # SBU(1,4) + CAN(5,8,12)
          extiPr1: 4402L           # write-1-to-clear: stores written value
        }
      }
      """

  Scenario: Entering stop mode configures PWR for STOP mode
    Given exists data:
      """
      RequestDeepSleep: { ... }
      """
    When process stop mode:
    Then control data should be:
      """
      : {
        stopModeRegs: {
          pwrCpucr: 0b0000_0000y             # PDDS_D1|D2|D3 cleared
          pwrCr1: 16896L          # SVOS_0(0x4000) | FLPS(0x200)
        }
      }
      """

  Scenario: Entering stop mode sets SLEEPDEEP, disables NVIC, enables wakeup IRQs, and triggers WFI→reset
    Given exists data:
      """
      RequestDeepSleep: { ... }
      """
    When process stop mode:
    Then control data should be:
      """
      : {
        stopModeRegs: {
          scbScr: 0b0000_0100y              # SCB_SCR_SLEEPDEEP_Msk = 0x4
          nvicIcer0: 0xFFFFFFFF  # ICER[0] all interrupts disabled
          nvicIcer7: 0xFFFFFFFF  # ICER[7]
          nvicIcpr0: 0xFFFFFFFF  # ICPR[0] all pending cleared
          nvicIcpr7: 0xFFFFFFFF  # ICPR[7]
          irqDisabled: true      # __disable_irq() called
          dsbCalled: true        # __DSB() called
          isbCalled: true        # __ISB() called
          wfiEntered: true       # __WFI() called
          nvicIrqEnableCount: 4  # EXTI1, EXTI4, EXTI9_5, EXTI15_10
        }
        nvicResetCount: 1
      }
      """

  @cuatro
  Scenario: Entering stop mode drives bootkick, amp, and CAN transceiver GPIO outputs
    Given exists data:
      """
      RequestDeepSleep: { ... }
      """
    When process stop mode:
    Then control data should be:
      """
      : {
        stopModeRegs: {
          gpioAOdr: 521L            # PA0→bootkick=1 + PA3+PA9→relay off=1 (set by SILENT mode)
          gpioBOdr: 3200L          # PB0: amp off=low, PB7+PB10+PB11: CAN1/2/4 disable=high
          gpioCOdr: 2048L          # PC11: bootkick STANDBY = high
          gpioDOdr: 256L           # PD8: CAN3 disable = high
        }
      }
      """

  @tres
  Scenario: Entering stop mode drives GPIO outputs for tres board
    Given exists data:
      """
      RequestDeepSleep: { ... }
      """
    When process stop mode:
    Then control data should be:
      """
      : {
        stopModeRegs: {
          gpioAOdr: 521L            # PA0→bootkick=1 + PA3+PA9→relay off (set by SILENT mode via set_intercept_relay)
          gpioBOdr: 3072L          # PB10+PB11: CAN2/4 disable=high
          gpioCOdr: 4096L          # PC12: bootkick = high
          gpioDOdr: 128L           # PD7: tied-CAN = high
          gpioGOdr: 2048L          # PG11: tied-CAN = high
        }
      }
      """

  @red
  Scenario: Entering stop mode drives GPIO outputs for red board
    Given exists data:
      """
      RequestDeepSleep: { ... }
      """
    When process stop mode:
    Then control data should be:
      """
      : {
        stopModeRegs: {
          gpioBOdr: 24L            # PB3+PB4: CAN2/4 disable=high
          gpioDOdr: 128L           # PD7: CAN3 disable=high
          gpioGOdr: 2048L          # PG11: CAN1 disable=high
        }
      }
      """

