# language: en
Feature: Microsecond Timer Retrieval

  Scenario: Get microsecond timer returns 4-byte little-endian value for non-zero timer
    Given exists data:
      """
      ControlSetup: {
        timerValue: 0x12345678
      }
      """
    When control write:
      """
      UsbControlRequest: {
        request: -88y            # 0xa8
        param1: 0
        param2: 0
      }
      """
    Then control data should be:
      """
      : {
        respBuffer= {
          len: 4
          bytes[0]: 120y    # 0x78, LSB
          bytes[1]: 86y     # 0x56
          bytes[2]: 52y     # 0x34
          bytes[3]: 18y     # 0x12, MSB
        }
      }
      """

  Scenario: Get microsecond timer returns all zero bytes for zero timer value
    When control write:
      """
      MicrosecondTimmer: { ... }
      """
    Then control data should be:
      """
      : {
        respBuffer= {
          len: 4
          bytes[0]: 0y
          bytes[1]: 0y
          bytes[2]: 0y
          bytes[3]: 0y
        }
      }
      """
