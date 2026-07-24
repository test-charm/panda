# language: en
Feature: Relay Malfunction Fault Detection

  Scenario: Setting relay malfunction triggers FAULT_RELAY_MALFUNCTION
    Given exists data:
      """
      ControlSetup: {
        relayMalfunctionVal: 1
      }
      """
    When tick handler
    Then control data should be:
      """
      : {
        readFaults: 1     # FAULT_RELAY_MALFUNCTION = bit 0
      }
      """

  Scenario: Clearing relay malfunction triggers fault recovery
    Given exists data:
      """
      ControlSetup: {
        relayMalfunctionVal: 1
      }
      """
    When tick handler
    Given exists data:
      """
      ControlSetup: {
        relayMalfunctionVal: 0
      }
      """
    When tick handler
    Then control data should be:
      """
      : {
        readFaults: 0
      }
      """

  Scenario: No edge change does not affect faults
    Given exists data:
      """
      ControlSetup: {
        relayMalfunctionVal: 0
      }
      """
    When tick handler
    Then control data should be:
      """
      : {
        readFaults: 0
      }
      """
