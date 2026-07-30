# language: en
Feature: SOM GPIO Reading

  @cuatro @tres
  Scenario: Reading SOM GPIO with preset value returns 1 in resp buffer
    Given exists data:
      """
      ControlSetup: {
        somGpio: 1
      }
      """
    When control write:
      """
      UsbControlRequest: {
        request: -58y
        param1: 0
        param2: 0
      }
      """
    Then control data should be:
      """
      : {
        respBuffer= {
          len: 1
          bytes: [ 1y ]
        }
      }
      """

  @cuatro @tres
  Scenario: Reading SOM GPIO with preset 1 returns 1 in resp buffer
    Given exists data:
      """
      ControlSetup: {
        somGpio: 1
      }
      """
    When control write:
      """
      UsbControlRequest: {
        request: -58y
        param1: 0
        param2: 0
      }
      """
    Then control data should be:
      """
      : {
        respBuffer= {
          len: 1
          bytes: [ 1y ]
        }
      }
      """

  @red
  Scenario: ReadSomGpio on red returns 0 even when stub is set to non-zero
    Given exists data:
      """
      ControlSetup: {
        somGpio: 1
      }
      """
    When control write:
      """
      UsbControlRequest: {
        request: -58y
        param1: 0
        param2: 0
      }
      """
    Then control data should be:
      """
      : {
        respBuffer: {
          len: 1
          bytes: [ 0y ]
        }
      }
      """
