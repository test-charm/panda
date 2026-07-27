# language: en
Feature: SPI Version Packet (spi_version_packet + crc_checksum)

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
