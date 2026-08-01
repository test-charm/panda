# language: en
@body
Feature: Body Firmware Shared USB Commands

  These commands are shared with the panda firmware but exercise
  board/body/main_comms.h code paths.

  Scenario: Getting hardware type via 0xc1 returns body type 0xB1
    When body control write:
      """
      BodyUsbControlRequest: {
        request: -63
        param1: 0
        param2: 0
      }
      """
    Then body control data should be:
      """
      : {
        hwType: 177
      }
      """

  Scenario: Getting firmware version via 0xd6 returns git commit hash
    When body control write:
      """
      BodyUsbControlRequest: {
        request: -42
        param1: 0
        param2: 0
      }
      """
    Then body control data should be:
      """
      : {
        respBuffer= {
          len: 18
          bytes[0]: 101y    # 'e'
          bytes[1]: 50y     # '2'
          bytes[2]: 101y    # 'e'
          bytes[3]: 45y     # '-'
          bytes[4]: 116y    # 't'
          bytes[5]: 101y    # 'e'
          bytes[6]: 115y    # 's'
          bytes[7]: 116y    # 't'
          bytes[8]: 45y     # '-'
          bytes[9]: 48y     # '0'
          bytes[16]: 48y    # '0'
        }
      }
      """

  Scenario: Getting packet versions via 0xdd returns both version numbers
    When body control write:
      """
      BodyUsbControlRequest: {
        request: -35
        param1: 0
        param2: 0
      }
      """
    Then body control data should be:
      """
      : {
        respBuffer= {
          len: 8
          bytes[0]: -10y    # HEALTH_PACKET_VERSION byte 0 (LE)
          bytes[1]: 63y     # HEALTH_PACKET_VERSION byte 1
          bytes[2]: -99y    # HEALTH_PACKET_VERSION byte 2
          bytes[3]: -30y    # HEALTH_PACKET_VERSION byte 3
          bytes[4]: 117y    # CAN_PACKET_VERSION_HASH byte 0 (LE)
          bytes[5]: -85y    # CAN_PACKET_VERSION_HASH byte 1
          bytes[6]: -14y    # CAN_PACKET_VERSION_HASH byte 2
          bytes[7]: 118y    # CAN_PACKET_VERSION_HASH byte 3
        }
      }
      """

  Scenario: Reset ST via 0xd8 triggers NVIC system reset
    When body control write:
      """
      BodyUsbControlRequest: {
        request: -40
        param1: 0
        param2: 0
      }
      """
    Then body control data should be:
      """
      : {
        nvicResetCount: 1
      }
      """

  Scenario: Getting first 64 bytes of firmware signature via 0xd3
    Given exists data:
      """
      BodyControlSetup: {
        codeLen: 16
        signatureChunk0: "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB"
      }
      """
    When body control write:
      """
      BodyUsbControlRequest: {
        request: -45
        param1: 0
        param2: 0
      }
      """
    Then body control data should be:
      """
      : {
        respBuffer= {
          len: 64
          bytes[0]: -86y    # 0xAA
          bytes[31]: -86y   # 0xAA
          bytes[32]: -69y   # 0xBB
          bytes[63]: -69y   # 0xBB
        }
      }
      """

  Scenario: Getting second 64 bytes of firmware signature via 0xd4
    Given exists data:
      """
      BodyControlSetup: {
        codeLen: 16
        signatureChunk1: "CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDD"
      }
      """
    When body control write:
      """
      BodyUsbControlRequest: {
        request: -44
        param1: 0
        param2: 0
      }
      """
    Then body control data should be:
      """
      : {
        respBuffer= {
          len: 64
          bytes[0]: -52y    # 0xCC
          bytes[31]: -52y   # 0xCC
          bytes[32]: -35y   # 0xDD
          bytes[63]: -35y   # 0xDD
        }
      }
      """

  Scenario: Enter bootloader mode via 0xd1 with param1=0
    When body control write:
      """
      BodyUsbControlRequest: {
        request: -47
        param1: 0
        param2: 0
      }
      """
    Then body control data should be:
      """
      : {
        nvicResetCount: 1
        enterBootloaderMode: 1
      }
      """

  Scenario: Enter softloader mode via 0xd1 with param1=1
    When body control write:
      """
      BodyUsbControlRequest: {
        request: -47
        param1: 1
        param2: 0
      }
      """
    Then body control data should be:
      """
      : {
        nvicResetCount: 1
        enterBootloaderMode: 2
      }
      """
