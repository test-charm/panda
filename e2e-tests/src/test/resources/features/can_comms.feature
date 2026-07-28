# language: en
Feature: CAN Communications Serialization/Deserialization

  comms_can_write() deserializes wire-format CAN frames → can_send → process_can → rxQueue.
  comms_can_read() serializes can_rx_q packets → wire-format bytes.

  Wire format (STM32 LE):
  byte 0:  [data_len_code:4][bus:3][fd:1]
  bytes 1-4: LE32 (addr << 3) | (extended << 2) | (returned << 1) | rejected
  byte 5:  XOR checksum of header[0..4] + payload
  bytes 6+: payload (up to 8 classic, 64 CAN FD)

  Scenario: Classic CAN 8-byte frame — deserialize to rxQueue via process_can
    Given exists data:
      """
      SetSafetyMode: { param1: 17 }
      """
    When comms can write with hex:
      """
      80 00 08 00 00 80 01 02 03 04 05 06 07 08
      """
    Then control data should be:
      """
      rxQueue[0]: {
        address: 256
        data: [0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08]
        returned: true
        rejected: false
      }
      """

  Scenario: CAN FD 64-byte frame — deserialize to rxQueue via process_can
    Given exists data:
      """
      SetSafetyMode: { param1: 17 }
      """
    When comms can write with hex:
      """
      f3 00 10 00 00 e3 00 01 02 03 04 05 06 07 08 09 0a 0b 0c 0d 0e 0f 10 11 12 13 14 15 16 17 18 19 1a 1b 1c 1d 1e 1f 20 21 22 23 24 25 26 27 28 29 2a 2b 2c 2d 2e 2f 30 31 32 33 34 35 36 37 38 39 3a 3b 3c 3d 3e 3f
      """
    Then control data should be:
      """
      rxQueue[0]: {
        address: 512
        data: [0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0A, 0x0B, 0x0C, 0x0D, 0x0E]
        returned: true
        rejected: false
      }
      """

  Scenario: Multi-frame batch — two classic CAN frames deserialized in sequence
    Given exists data:
      """
      SetSafetyMode: { param1: 17 }
      """
    When comms can write with hex:
      """
      80 00 08 00 00 80 01 02 03 04 05 06 07 08
      """
    Then control data should be:
      """
      rxQueue[0]: {
        address: 256
        data: [0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08]
        returned: true
        rejected: false
      }
      """
    When comms can write with hex:
      """
      80 00 10 00 00 88 09 0a 0b 0c 0d 0e 0f 10
      """
    Then control data should be:
      """
      rxQueue[0]: {
        address: 512
        data: [0x09, 0x0A, 0x0B, 0x0C, 0x0D, 0x0E, 0x0F, 0x10]
        returned: true
        rejected: false
      }
      """

  Scenario: Rejected frame — blocked in SILENT mode, serialized with rejected flag in wire format
    Given exists data:
      """
      SetSafetyMode: { param1: 0 }
      """
    When can send with result 1:
      """
      PowerTrainBusRequest: {
        address: 256
        data: "abcdefgh"
        bus: 0
      }
      """
    When comms can read with max len 64
    Then control data should be:
      """
      commsReadBytes: [-128, 1, 8, 0, 0, -127, 97, 98, 99, 100, 101, 102, 103, 104]
      """
