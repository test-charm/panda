# language: en
Feature: OBD CAN Multiplexing Mode

  Scenario: Setting NORMAL mode with param1=0
    When control write:
      """
      UsbControlRequest: {
        request: -37y
        param1: 0
        param2: 0
      }
      """
    Then control data should be:
      """
      : {
        canModeCall= {
          value: 0
        }
      }
      """

  Scenario: Setting OBD_CAN2 mode with param1=1
    When control write:
      """
      SetCanMode: {
        param1: 1
      }
      """
    Then control data should be:
      """
      : {
        canModeCall= {
          value: 1
        }
      }
      """

  Scenario: Setting NORMAL mode with non-1 param1 value
    When control write:
      """
      SetCanMode: {
        param1: 2
      }
      """
    Then control data should be:
      """
      : {
        canModeCall= {
          value: 0
        }
      }
      """
