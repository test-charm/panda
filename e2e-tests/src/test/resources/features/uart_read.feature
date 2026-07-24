# language: en
Feature: UART Read

  Scenario: UART read returns zero-length response for invalid ring number
    When control write:
      """
      UsbControlRequest: {
        request: -32y            # 0xe0
        param1: 99
        param2: 0
      }
      """
    Then control data should be:
      """
      : {
        respBuffer: {
          len: 0
        }
      }
      """

  Scenario: UART read returns zero-length response for empty ring
    When control write:
      """
      UartRead: {
        param1: 0
      }
      """
    Then control data should be:
      """
      : {
        respBuffer: {
          len: 0
        }
      }
      """

  Scenario: UART read returns buffered data when ring has characters
    Given exists data:
      """
      ControlSetup: {
        uartData: "HELLO"
      }
      """
    When control write:
      """
      UartRead: {
        param1: 0
        length: 5
      }
      """
    Then control data should be:
      """
      : {
        respBuffer= {
          len: 5
          bytes[0]: 72y    # 'H'
          bytes[1]: 69y    # 'E'
          bytes[2]: 76y    # 'L'
          bytes[3]: 76y    # 'L'
          bytes[4]: 79y    # 'O'
        }
      }
      """
