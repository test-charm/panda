# language: en
Feature: SPI Version Packet and Device Identity (spi_version_packet + serial + provision)

  Scenario: SPI version packet returns VERSION header with UID, hw_type, PID and CRC-8
    When SPI version packet
    Then control data should be:
      """
      : {
        spiVersionResult: {
          len: 25
          crc8: 0x57
          bytes[0]: 0x56     # 'V'
          bytes[1]: 0x45     # 'E'
          bytes[2]: 0x52     # 'R'
          bytes[3]: 0x53     # 'S'
          bytes[4]: 0x49     # 'I'
          bytes[5]: 0x4F     # 'O'
          bytes[6]: 0x4E     # 'N'
          bytes[7]: 0x0F     # data_len lo (15)
          bytes[8]: 0x00     # data_len hi
          bytes[21]: 0x0A    # hw_type = CUATRO
          bytes[22]: -52y    # USB_PID low byte (0xDDCC)
          bytes[23]: 0x02    # SPI protocol version
        }
      }
      """

  Scenario: SPI version packet CRC-8 changes when UID bytes are non-zero
    Given exists data:
      """
      ControlSetup: {
        mcuUidBytes: "00112233445566778899AABB"
      }
      """
    When SPI version packet
    Then control data should be:
      """
      : {
        spiVersionResult: {
          len: 25
          bytes[9]: 0x00
          bytes[10]: 0x11
          bytes[11]: 0x22
          bytes[12]: 0x33
          bytes[13]: 0x44
          bytes[14]: 0x55
          bytes[15]: 0x66
          bytes[16]: 0x77
          bytes[17]: -120y   # 0x88
          bytes[18]: -103y   # 0x99
          bytes[19]: -86y    # 0xAA
          bytes[20]: -69y    # 0xBB
        }
      }
      """

  # —— Device Serial & Provision (merged from serial.feature, 第十三节 B5) ——

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

  Scenario: Get provision chunk for unprovisioned device returns unprovisioned magic string
    Given exists data:
      """
      ControlSetup: {
        provisionBytes: "FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF"
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
          bytes[0]: 117y     # 'u'
          bytes[12]: 100y    # 'd'
          bytes[13]: 0y
          bytes[25]: 51y     # '3'
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
