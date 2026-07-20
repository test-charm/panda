# language: en
Feature: Heartbeat Mechanism

  Scenario: Heartbeat with param1=0 reports not engaged
    Given control write:
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
        heartbeatCounter: 0
        heartbeatLost: 0
        heartbeatDisabled: 0
        heartbeatEngaged: 0
      }
      """

  Scenario: Heartbeat with param1=1 reports engaged
    Given control write:
      """
      Heartbeat: {
        param1: 1
      }
      """
    Then control data should be:
      """
      : {
        heartbeatCounter: 0
        heartbeatLost: 0
        heartbeatDisabled: 0
        heartbeatEngaged: 1
      }
      """

  Scenario: Heartbeat with param1=2 is equivalent to param1=0 (not engaged)
    Given control write:
      """
      Heartbeat: {
        param1: 2
      }
      """
    Then control data should be:
      """
      : {
        heartbeatCounter: 0
        heartbeatLost: 0
        heartbeatDisabled: 0
        heartbeatEngaged: 0
      }
      """

  Scenario: Disabling heartbeat in non-car safety mode (SILENT)
    Given control write:
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
        heartbeatDisabled: 1
      }
      """

  Scenario: Heartbeat clears disabled flag
    Given control write:
      """
      DisableHeartbeat: {
        param1: 0
      }
      """
    When control write "Heartbeat":
      """
      {
        param1: 1
      }
      """
    Then control data should be:
      """
      : {
        heartbeatCounter: 0
        heartbeatLost: 0
        heartbeatDisabled: 0
        heartbeatEngaged: 1
      }
      """

  Scenario: Cannot disable heartbeat in car safety mode (TOYOTA)
    Given control write:
      """
      SetSafetyMode: {
        param1: 2
      }
      """
    When control write "DisableHeartbeat":
      """
      {
        param1: 0
      }
      """
    Then control data should be:
      """
      : {
        heartbeatDisabled: 0
      }
      """
