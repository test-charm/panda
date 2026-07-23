# language: en
Feature: System Reset

  Scenario: Reset ST triggers NVIC_SystemReset
    When control write:
      """
      UsbControlRequest: {
        request: -40y
        param1: 0
        param2: 0
      }
      """
    Then control data should be:
      """
      : {
        nvicResetCount: 1
      }
      """