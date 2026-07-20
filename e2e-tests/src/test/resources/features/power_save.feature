# language: en
Feature: Power Save State Control

  Scenario: Disabling power save with param1=0
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
      }
      """

  Scenario: Enabling power save with param1=1
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
      }
      """
