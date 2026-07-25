# language: en
Feature: WFI Idle Path (Power Save Light Sleep)

  When power save is enabled, the main loop's idle path (board/main.c:377-385)
  calls __WFI() for light sleep on non-CUATRO boards (tres, red) and on CUATRO
  when SOM GPIO is high. The CUATRO enter_stop_mode() deep sleep path is already
  covered by deep_sleep.feature.

  Background:
    When control write:
      """
      SetPowerSaveState: {
        param1: 1
      }
      """

  @tres
  Scenario: WFI idle path enters light sleep on tres board
    When process wfi idle
    Then control data should be:
      """
      : {
        stopModeRegs: {
          wfiEntered: true
          scbScr: 0x0
        }
        powerSaveEnabled: true
      }
      """

  @red
  Scenario: WFI idle path enters light sleep on red board
    When process wfi idle
    Then control data should be:
      """
      : {
        stopModeRegs: {
          wfiEntered: true
          scbScr: 0x0
        }
        powerSaveEnabled: true
      }
      """

  @cuatro
  Scenario: WFI idle path enters light sleep on cuatro with SOM GPIO high
    Given exists data:
      """
      ControlSetup: {
        somGpio: 1
      }
      """
    When process wfi idle
    Then control data should be:
      """
      : {
        stopModeRegs: {
          wfiEntered: true
          scbScr: 0x0
        }
        powerSaveEnabled: true
      }
      """
