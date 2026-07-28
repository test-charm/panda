# language: en
Feature: Fan Power Control

  Scenario: Setting fan power to 0 turns off fan
    When control write:
      """
      UsbControlRequest: {
        request: -79y
        param1: 0
        param2: 0
      }
      """
    Then control data should be:
      """
      : {
        fanPower: 0
      }
      """

  Scenario: Setting fan power to a value in range passes through
    When control write:
      """
      SetFanPower: {
        param1: 50
      }
      """
    Then control data should be:
      """
      : {
        fanPower: 50
      }
      """

  # ---- set_fan_enabled on RED is unreachable through firmware paths ----
  # RED has has_fan=false, so fan_tick() skips set_fan_enabled().
  # We call current_board->set_fan_enabled() directly via JNA to exercise
  # the board wiring and unused_set_fan_enabled. Verify it's a no-op:
  # GPIO PD3 stays 0 and fanPower stays as set by fan_set_power.

  @red
  Scenario: set_fan_enabled through board function pointer is a no-op on red
    When control write:
      """
      SetFanPower: {
        param1: 50
      }
      """
    And set fan enabled through board 1
    Then control data should be:
      """
      : {
        fanPower: 50
        stopModeRegs: {
          gpioDOdr: 0L
        }
      }
      """

  @cuatro
  Scenario: SetFanPower on cuatro drives PD3 low via cuatro_set_fan_enabled
    When control write:
      """
      SetFanPower: {
        param1: 50
      }
      """
    Then control data should be:
      """
      : {
        fanPower: 50
        stopModeRegs: {
          gpioDOdr: 0L
        }
      }
      """

  @cuatro
  Scenario: SetFanPower to zero on cuatro releases PD3 high after cooldown
    When control write:
      """
      SetFanPower: {
        param1: 0
      }
      """
    And call tick handler 24 times
    Then control data should be:
      """
      : {
        fanPower: 0
        stopModeRegs: {
          gpioDOdr: 264L
        }
      }
      """

  @tres
  Scenario: SetFanPower on tres drives PD3 high via tres_set_fan_enabled
    When control write:
      """
      SetFanPower: {
        param1: 50
      }
      """
    And call tick handler 1 times
    Then control data should be:
      """
      : {
        fanPower: 50
        stopModeRegs: {
          gpioDOdr: 8L
        }
      }
      """

  Scenario: Setting fan power below 20 clamps to 20
    When control write:
      """
      SetFanPower: {
        param1: 5
      }
      """
    Then control data should be:
      """
      : {
        fanPower: 20
      }
      """

  Scenario: Setting fan power above 100 clamps to 100
    When control write:
      """
      SetFanPower: {
        param1: 200
      }
      """
    Then control data should be:
      """
      : {
        fanPower: 100
      }
      """

  Scenario: Setting fan power to max uint8 clamps to 100
    When control write:
      """
      SetFanPower: {
        param1: 255
      }
      """
    Then control data should be:
      """
      : {
        fanPower: 100
      }
      """