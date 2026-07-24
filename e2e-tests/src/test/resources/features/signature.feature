# language: en
Feature: Firmware Signature Retrieval

  Scenario: Get first 64 bytes of signature via 0xd3
    Given exists data:
      """
      ControlSetup: {
        codeLen: 256
        signatureChunk0: "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAADDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDD"
      }
      """
    When control write:
      """
      UsbControlRequest: {
        request: -45y            # 0xd3
        param1: 0
        param2: 0
      }
      """
    Then control data should be:
      """
      : {
        respBuffer: {
          len: 64
          bytes[0]: -86y    # 0xAA
          bytes[31]: -86y   # 0xAA
          bytes[32]: -35y   # 0xDD
          bytes[63]: -35y   # 0xDD
        }
      }
      """

  Scenario: Get second 64 bytes of signature via 0xd4
    Given exists data:
      """
      ControlSetup: {
        codeLen: 256
        signatureChunk1: "01010101010101010101010101010101010101010101010101010101010101010404040404040404040404040404040404040404040404040404040404040404"
      }
      """
    When control write:
      """
      UsbControlRequest: {
        request: -44y            # 0xd4
        param1: 0
        param2: 0
      }
      """
    Then control data should be:
      """
      : {
        respBuffer: {
          len: 64
          bytes[0]: 1y       # 0x01
          bytes[31]: 1y      # 0x01
          bytes[32]: 4y      # 0x04
          bytes[63]: 4y      # 0x04
        }
      }
      """
