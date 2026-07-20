# language: en
Feature: Hardware Type Retrieval

  Scenario: Get hardware type returns 0 in e2e environment
    When control write:
      """
      UsbControlRequest: {
        request: -63y
        param1: 0
        param2: 0
      }
      """
    Then control data should be:
      """
      : {
        hwType: 0
      }
      """