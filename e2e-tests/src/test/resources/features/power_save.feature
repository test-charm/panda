# language: en
Feature: Power Save State Control

  Scenario: Disabling power save when already disabled is idempotent
    When control write:
      """
      UsbControlRequest: {
        request: -25y
        param1: 0
        param2: 0
      }
      """
    Then control data should be:
      """
      : {
        powerSaveEnabled: false
        powerSaveTracking: {
          irqDisableCount: 0
          irqEnableCount: 0
          irPowerCallCount: 0
        }
      }
      """

  Scenario: Enabling power save disables CAN interrupts, transceivers, and IR
    When control write:
      """
      SetPowerSaveState: {
        param1: 1
      }
      """
    Then control data should be:
      """
      : {
        powerSaveEnabled: true
        powerSaveTracking= {
          irqDisableCount: 2
          irqEnableCount: 0
          lastIrqEnabledBus: -1
          irqDisabledBus0: false
          irqDisabledBus1: true
          irqDisabledBus2: true
          irPowerValue: 0
          irPowerCallCount: 1
        }
      }
      """

  Scenario: Any non-zero param1 enables power save
    When control write:
      """
      SetPowerSaveState: {
        param1: 255
      }
      """
    Then control data should be:
      """
      : {
        powerSaveEnabled: true
        powerSaveTracking: {
          irqDisableCount: 2
        }
      }
      """

  Scenario: Idempotency — repeated enable does not re-trigger hardware calls
    Given exists data:
      """
      SetPowerSaveState: {
        param1: 1
      }
      """
    When control write:
      """
      SetPowerSaveState: {
        param1: 1
      }
      """
    Then control data should be:
      """
      : {
        powerSaveEnabled: true
        powerSaveTracking: {
          irqDisableCount: 2
          irPowerCallCount: 1
        }
      }
      """

  Scenario: Idempotency — repeated disable does not re-trigger hardware calls
    Given exists data:
      """
      SetPowerSaveState: {
        param1: 0
      }
      """
    When control write:
      """
      SetPowerSaveState: {
        param1: 0
      }
      """
    Then control data should be:
      """
      : {
        powerSaveEnabled: false
        powerSaveTracking: {
          irqDisableCount: 0
          irqEnableCount: 0
          irPowerCallCount: 0
        }
      }
      """

  Scenario: Disabling power save re-enables CAN interrupts and transceivers
    Given exists data:
      """
      SetPowerSaveState: {
        param1: 1
      }
      """
    When control write:
      """
      SetPowerSaveState: {
        param1: 0
      }
      """
    Then control data should be:
      """
      : {
        powerSaveEnabled: false
        powerSaveTracking: {
          irqEnableCount: 2
          lastIrqEnabledBus: 1
          irPowerCallCount: 1
        }
      }
      """

  @cuatro
  Scenario: Enabling power save drives CAN transceiver GPIO pins
    When control write:
      """
      SetPowerSaveState: {
        param1: 1
      }
      """
    Then control data should be:
      """
      : {
        powerSaveEnabled: true
        stopModeRegs: {
          gpioBOdr: 3072L          # PB10+PB11: CAN2/4 disabled (active-low HIGH)
          gpioDOdr: 256L           # PD8: CAN3 disabled
        }
      }
      """

  @cuatro
  Scenario: Disabling power save releases CAN transceiver GPIO pins
    Given exists data:
      """
      SetPowerSaveState: {
        param1: 1
      }
      """
    When control write:
      """
      SetPowerSaveState: {
        param1: 0
      }
      """
    Then control data should be:
      """
      : {
        powerSaveEnabled: false
        stopModeRegs: {
          gpioBOdr: 0L
          gpioDOdr: 0L
        }
      }
      """

  @tres
  Scenario: Enabling power save drives CAN transceiver GPIO for tres
    When control write:
      """
      SetPowerSaveState: {
        param1: 1
      }
      """
    Then control data should be:
      """
      : {
        powerSaveEnabled: true
        stopModeRegs: {
          gpioBOdr: 3072L          # PB10+PB11: CAN2/4 disabled
          gpioDOdr: 0L             # CAN3 software-only, tied-CAN low (bus1 enabled)
        }
      }
      """

  @tres
  Scenario: Disabling power save releases CAN transceiver GPIO for tres
    Given exists data:
      """
      SetPowerSaveState: {
        param1: 1
      }
      """
    When control write:
      """
      SetPowerSaveState: {
        param1: 0
      }
      """
    Then control data should be:
      """
      : {
        powerSaveEnabled: false
        stopModeRegs: {
          gpioBOdr: 0L
          gpioDOdr: 0L
        }
      }
      """

  @red
  Scenario: Enabling power save drives CAN transceiver GPIO for red
    When control write:
      """
      SetPowerSaveState: {
        param1: 1
      }
      """
    Then control data should be:
      """
      : {
        powerSaveEnabled: true
        stopModeRegs: {
          gpioBOdr: 24L            # PB3+PB4: CAN2/4 disabled
          gpioDOdr: 128L           # PD7: CAN3 disabled
          gpioGOdr: 0L             # PG11: bus1 stays enabled (main bus)
        }
      }
      """

  @red
  Scenario: Disabling power save releases CAN transceiver GPIO for red
    Given exists data:
      """
      SetPowerSaveState: {
        param1: 1
      }
      """
    When control write:
      """
      SetPowerSaveState: {
        param1: 0
      }
      """
    Then control data should be:
      """
      : {
        powerSaveEnabled: false
        stopModeRegs: {
          gpioBOdr: 0L
          gpioDOdr: 0L
          gpioGOdr: 0L
        }
      }
      """

  @cuatro
  Scenario: Flipped harness — bus3 becomes main bus, bus1 follows enable_can_transceivers
    Given exists data:
      """
      ControlSetup: {
        harnessStatus: 2
      }
      """
    When control write:
      """
      SetPowerSaveState: {
        param1: 1
      }
      """
    Then control data should be:
      """
      : {
        powerSaveEnabled: true
        stopModeRegs: {
          gpioBOdr: 3200L          # PB7(CAN1 disabled!) + PB10(CAN2 disabled) + PB11(CAN4 disabled)
          gpioDOdr: 0L             # PD8: CAN3 — bus3 is main bus, stays enabled (LOW)
        }
      }
      """

  @red
  Scenario: Flipped harness for red — bus3 stays enabled, bus1 disabled
    Given exists data:
      """
      ControlSetup: {
        harnessStatus: 2
      }
      """
    When control write:
      """
      SetPowerSaveState: {
        param1: 1
      }
      """
    Then control data should be:
      """
      : {
        powerSaveEnabled: true
        stopModeRegs: {
          gpioBOdr: 24L            # PB3+PB4: CAN2/4 disabled (same as normal)
          gpioDOdr: 0L             # PD7: CAN3 — bus3 is main bus, stays enabled (LOW, was 128)
          gpioGOdr: 2048L          # PG11: CAN1 now disabled (follows enable_can_transceivers(false))
        }
      }
      """

  @tres
  Scenario: Flipped harness for tres — bus3 becomes main bus (software-only CAN1/CAN3)
    Given exists data:
      """
      ControlSetup: {
        harnessStatus: 2
      }
      """
    When control write:
      """
      SetPowerSaveState: {
        param1: 1
      }
      """
    Then control data should be:
      """
      : {
        powerSaveEnabled: true
        powerSaveTracking: {
          irqDisableCount: 2
          irPowerCallCount: 1
        }
        stopModeRegs: {
          gpioBOdr: 3072L          # PB10+PB11: CAN2/4 disabled (same as normal)
          gpioDOdr: 0L             # CAN1/CAN3 software-only, no GPIO change
        }
      }
      """
