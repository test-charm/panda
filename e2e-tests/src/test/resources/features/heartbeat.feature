# language: en
Feature: Heartbeat Mechanism

  Scenario: Heartbeat with param1=0 reports not engaged
    When control write:
      """
      UsbControlRequest: {
        request: -13y
        param1: 0
        param2: 0
      }
      """
    Then control data should be:
      """
      : {
        heartbeat= {
          counter: 0
          lost: 0
          disabled: 0
          engaged: 0
        }
      }
      """

  Scenario: Heartbeat with param1=1 reports engaged
    When control write:
      """
      Heartbeat: {
        param1: 1
      }
      """
    Then control data should be:
      """
      : {
        heartbeat= {
          counter: 0
          lost: 0
          disabled: 0
          engaged: 1
        }
      }
      """

  Scenario: Heartbeat with param1=2 is equivalent to param1=0 (not engaged)
    When control write:
      """
      Heartbeat: {
        param1: 2
      }
      """
    Then control data should be:
      """
      : {
        heartbeat= {
          counter: 0
          lost: 0
          disabled: 0
          engaged: 0
        }
      }
      """

  Scenario: Disabling heartbeat in non-car safety mode (SILENT)
    When control write:
      """
      UsbControlRequest: {
        request: -8y
        param1: 0
        param2: 0
      }
      """
    Then control data should be:
      """
      : {
        heartbeat= {
          disabled: 1
        }
      }
      """

  Scenario: Heartbeat clears disabled flag
    Given exists data:
      """
      DisableHeartbeat: {
        param1: 0
      }
      """
    When control write:
      """
      Heartbeat: {
        param1: 1
      }
      """
    Then control data should be:
      """
      : {
        heartbeat= {
          counter: 0
          lost: 0
          disabled: 0
          engaged: 1
        }
      }
      """

  Scenario: Cannot disable heartbeat in car safety mode (TOYOTA)
    Given exists data:
      """
      SetSafetyMode: {
        param1: 2
      }
      """
    When control write:
      """
      DisableHeartbeat: {
        param1: 0
      }
      """
    Then control data should be:
      """
      : {
        heartbeat= {
          disabled: 0
        }
      }
      """
