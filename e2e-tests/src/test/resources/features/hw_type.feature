# language: en
Feature: Hardware Type Retrieval

  Scenario: Get hardware type returns hw_type in resp buffer
    Given exists data:
      """
      ControlSetup: {
        hwType: 171    # 0xAB
      }
      """
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
        respBuffer= {
          len: 1
          bytes: [ -85y ]   # 0xAB = 171, signed byte = -85
        }
      }
      """