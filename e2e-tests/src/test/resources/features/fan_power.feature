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