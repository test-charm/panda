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
        relayCall= {
          a: false
          b: false
        }
        powerSaveEnabled: true
        stopModeRequested: true
        powerSaveTracking: {
          irqDisableCount: 2
        }
      }
      """

  Scenario: Entering stop mode sets all GPIO MODER to 0xFFFFFFFF (analog mode)
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
          gpioAModer: 0xFFFFFFFF
          gpioBModer: 0xFFFFFFFF
          gpioCModer: 0xFFFFFFFF
          gpioDModer: 0xFFFFFFFF
          gpioEModer: 0xFFFFFFFF
          gpioFModer: 0xFFFFFFFF
          gpioGModer: 0xFFFFFFFF
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

  Scenario: Entering stop mode sets SLEEPDEEP and triggers NVIC_SystemReset
    Given exists data:
      """
      RequestDeepSleep: { ... }
      """
    When process stop mode:
    Then control data should be:
      """
      : {
        stopModeRegs: {
          scbScr: 0b0000_0100y               # SCB_SCR_SLEEPDEEP_Msk = 0x4
          nvicIcer0: 0xFFFFFFFF   # all interrupts disabled (0xFFFFFFFF)
        }
        nvicResetCount: 1
      }
      """

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
          gpioAOdr: 1L                           # PA0: bootkick STANDBY = high
          gpioBOdr: 3200L                        # PB0: amp off=low, PB7+PB10+PB11: CAN1/2/4 disable=high
          gpioCOdr: 2048L                        # PC11: bootkick STANDBY = high
          gpioDOdr: 256L                         # PD8: CAN3 disable = high
        }
      }
      """

