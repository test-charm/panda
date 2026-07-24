# language: en
Feature: Serial Number and Provision Retrieval

  Scenario: Get serial number returns 16-byte device serial for param1 equals 1
    Given exists data:
      """
      ControlSetup: {
        serialBytes: "DEADC0DE12345678BEEFCAFE0000FEED"
      }
      """
    When control write:
      """
      UsbControlRequest: {
        request: -48y            # 0xd0
        param1: 1
        param2: 0
      }
      """
    Then control data should be:
      """
      : {
        respBuffer= {
          len: 16
          bytes[0]: -34y    # 0xDE
          bytes[1]: -83y    # 0xAD
          bytes[2]: -64y    # 0xC0
          bytes[3]: -34y    # 0xDE
          bytes[4]: 18y     # 0x12
          bytes[5]: 52y     # 0x34
          bytes[6]: 86y     # 0x56
          bytes[7]: 120y    # 0x78
          bytes[8]: -66y    # 0xBE
          bytes[9]: -17y    # 0xEF
          bytes[10]: -54y   # 0xCA
          bytes[11]: -2y    # 0xFE
          bytes[12]: 0y     # 0x00
          bytes[13]: 0y     # 0x00
          bytes[14]: -2y    # 0xFE
          bytes[15]: -19y   # 0xED
        }
      }
      """

  Scenario: Get provision chunk returns 32 bytes for param1 not equal to 1
    Given exists data:
      """
      ControlSetup: {
        provisionBytes: "0102030405060708090A0B0C0D0E0F101112131415161718191A1B1C1D1E1F20"
      }
      """
    When control write:
      """
      GetSerial: {
        param1: 0
      }
      """
    Then control data should be:
      """
      : {
        respBuffer: {
          len: 32
          bytes[0]: 1y
          bytes[15]: 16y    # 0x10
          bytes[31]: 32y    # 0x20
        }
      }
      """
