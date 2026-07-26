# language: en
Feature: CAN Communications Serialization/Deserialization

  comms_can_write() deserializes wire-format CAN frames → can_send → queue.
  comms_can_read() serializes can_rx_q packets → wire-format bytes.

  Wire format (STM32 LE):
  byte 0:  [data_len_code:4][bus:3][fd:1]
  bytes 1-4: LE32 (addr << 3) | (extended << 2) | (returned << 1) | rejected
  byte 5:  XOR checksum of header[0..4] + payload
  bytes 6+: payload (up to 8 classic, 64 CAN FD)

  Scenario: Classic CAN 8-byte frame — deserialize wire format to tx queue
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
      txQueue[0]: [{
        address: 256,
        data: [1, 2, 3, 4, 5, 6, 7, 8],
        rejected: false
      }]
      """

  Scenario: CAN FD 64-byte frame — deserialize wire format with FD flag and 64-byte payload
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
      txQueue[1]: [{
        address: 512,
        data: [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14],
        rejected: false
      }]
      """

  Scenario: Cross-chunk write — partial frame fills buffer, tail fits in next write
    Given exists data:
      """
      SetSafetyMode: { param1: 17 }
      """
    When comms can write with hex:
      """
      80 00 08 00 00 80 01 02 03 04
      """
    Then control data should be:
      """
      : {
        canCommsBuffers: {
          writeBufferPtr: 10,
          writeBufferTail: 4
        }
        txQueue[0]: []
      }
      """
    When comms can write with hex:
      """
      05 06 07 08
      """
    Then control data should be:
      """
      : {
        canCommsBuffers: {
          writeBufferPtr: 0,
          writeBufferTail: 0
        }
        txQueue[0]: [{
          address: 256,
          data: [1, 2, 3, 4, 5, 6, 7, 8],
          rejected: false
        }]
      }
      """

  Scenario: Cross-chunk write — second chunk still incomplete, third chunk completes
    Given exists data:
      """
      SetSafetyMode: { param1: 17 }
      """
    When comms can write with hex:
      """
      80 00 08 00 00 80 01 02 03 04
      """
    Then control data should be:
      """
      : {
        canCommsBuffers: {
          writeBufferPtr: 10,
          writeBufferTail: 4
        }
        txQueue[0]: []
      }
      """
    When comms can write with hex:
      """
      05 06
      """
    Then control data should be:
      """
      : {
        canCommsBuffers: {
          writeBufferPtr: 12,
          writeBufferTail: 2
        }
        txQueue[0]: []
      }
      """
    When comms can write with hex:
      """
      07 08
      """
    Then control data should be:
      """
      : {
        canCommsBuffers: {
          writeBufferPtr: 0,
          writeBufferTail: 0
        }
        txQueue[0]: [{
          address: 256,
          data: [1, 2, 3, 4, 5, 6, 7, 8],
          rejected: false
        }]
      }
      """

  Scenario: Cross-chunk read — small max_len forces overflow, second read drains remainder
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
    When comms can read with max len 8
    Then control data should be:
      """
      commsReadBytes: [-128, 1, 8, 0, 0, -127, 97, 98]
      """
    When comms can read with max len 64
    Then control data should be:
      """
      commsReadBytes: [99, 100, 101, 102, 103, 104]
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
      txQueue[0]: [{
        address: 256,
        data: [1, 2, 3, 4, 5, 6, 7, 8],
        rejected: false
      }]
      """
    When comms can write with hex:
      """
      80 00 10 00 00 88 09 0a 0b 0c 0d 0e 0f 10
      """
    Then control data should be:
      """
      txQueue[0]: [{
        address: 512,
        data: [9, 10, 11, 12, 13, 14, 15, 16],
        rejected: false
      }]
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

  Scenario: Checksum validation — valid checksum passes, corrupted checksum fails
    When check can checksum with hex:
      """
      80 00 08 00 00 80 01 02 03 04 05 06 07 08 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
      """
    Then control data should be:
      """
      checksumCheckPassed: true
      """
    When check can checksum with hex:
      """
      80 00 08 00 00 7f 01 02 03 04 05 06 07 08 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
      """
    Then control data should be:
      """
      checksumCheckPassed: false
      """
