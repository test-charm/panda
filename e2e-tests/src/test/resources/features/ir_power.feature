# language: en
Feature: IR Power Control

  Scenario: Setting IR power to 0
    When control write:
      """
      UsbControlRequest: {
        request: -80y
        param1: 0
        param2: 0
      }
      """
    Then control data should be:
      """
      : {
        irPwm: 0
      }
      """

  Scenario: Setting IR power to non-zero value
    When control write:
      """
      SetIrPower: {
        param1: 50
      }
      """
    Then control data should be:
      """
      : {
        irPwm: 50
      }
      """

  Scenario: Setting IR power to max uint8 value
    When control write:
      """
      SetIrPower: {
        param1: 255
      }
      """
    Then control data should be:
      """
      : {
        irPwm: 255
      }
      """