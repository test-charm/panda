# language: en
Feature: Siren Control

  Scenario: Disabling siren sets GPIO PB14 low
    When control write:
      """
      UsbControlRequest: {
        request: -10y
        param1: 0
        param2: 0
      }
      """
    When tick siren:
    Then control data should be:
      """
      : {
        stopModeRegs: {
          gpioBOdr: 0L
        }
      }
      """

  Scenario: Enabling siren sets GPIO PB14 high
    When control write:
      """
      SetSiren: {
        param1: 1
      }
      """
    When tick siren:
    Then control data should be:
      """
      : {
        stopModeRegs: {
          gpioBOdr: 16384L
        }
      }
      """

  Scenario: Any non-zero param1 enables siren
    When control write:
      """
      SetSiren: {
        param1: 255
      }
      """
    When tick siren:
    Then control data should be:
      """
      : {
        stopModeRegs: {
          gpioBOdr: 16384L
        }
      }
      """
