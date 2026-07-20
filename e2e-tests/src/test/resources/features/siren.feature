# language: en
Feature: Siren Control

  Scenario: Disabling siren with param1=0
    When control write:
      """
      UsbControlRequest: {
        request: -10y
        param1: 0
        param2: 0
      }
      """
    Then control data should be:
      """
      : {
        sirenEnabled: false
      }
      """

  Scenario: Enabling siren with param1=1
    When control write:
      """
      SetSiren: {
        param1: 1
      }
      """
    Then control data should be:
      """
      : {
        sirenEnabled: true
      }
      """

  Scenario: Any non-zero param1 enables siren
    When control write:
      """
      SetSiren: {
        param1: 255
      }
      """
    Then control data should be:
      """
      : {
        sirenEnabled: true
      }
      """
