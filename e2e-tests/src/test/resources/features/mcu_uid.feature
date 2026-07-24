# language: en
Feature: MCU UID Retrieval

  Scenario: Get MCU UID returns 12-byte unique identifier for non-zero UID
    Given exists data:
      """
      ControlSetup: {
        mcuUidBytes: "DEADBEEF0102030405060708"
      }
      """
    When control write:
      """
      UsbControlRequest: {
        request: -61y            # 0xc3
        param1: 0
        param2: 0
      }
      """
    Then control data should be:
      """
      : {
        respBuffer= {
          len: 12
          bytes[0]: -34y    # 0xDE
          bytes[1]: -83y    # 0xAD
          bytes[2]: -66y    # 0xBE
          bytes[3]: -17y    # 0xEF
          bytes[4]: 1y      # 0x01
          bytes[5]: 2y      # 0x02
          bytes[6]: 3y      # 0x03
          bytes[7]: 4y      # 0x04
          bytes[8]: 5y      # 0x05
          bytes[9]: 6y      # 0x06
          bytes[10]: 7y     # 0x07
          bytes[11]: 8y     # 0x08
        }
      }
      """

  Scenario: Get MCU UID returns all zero bytes for zero UID
    Given exists data:
      """
      ControlSetup: {
        mcuUidBytes: "000000000000000000000000"
      }
      """
    When control write:
      """
      GetMcuUid: {
        request: -61y            # 0xc3
        param1: 0
        param2: 0
      }
      """
    Then control data should be:
      """
      : {
        respBuffer= {
          len: 12
          bytes[0]: 0y
          bytes[1]: 0y
          bytes[2]: 0y
          bytes[3]: 0y
          bytes[4]: 0y
          bytes[5]: 0y
          bytes[6]: 0y
          bytes[7]: 0y
          bytes[8]: 0y
          bytes[9]: 0y
          bytes[10]: 0y
          bytes[11]: 0y
        }
      }
      """
