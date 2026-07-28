# language: en
Feature: CAN Communications Serialization/Deserialization

  USB ep3 out() → usb_sim_ep3_out() → comms_can_write() → can_send → process_can → rxQueue.
  USB ep1 in()  → usb_sim_ep1_in()  → comms_can_read()  → serializes can_rx_q → wire bytes.

  Wire format (STM32 LE):
  byte 0:  [data_len_code:4][bus:3][fd:1]
  bytes 1-4: LE32 (addr << 3) | (extended << 2) | (returned << 1) | rejected
  byte 5:  XOR checksum of header[0..4] + payload
  bytes 6+: payload (up to 8 classic, 64 CAN FD)

  Scenario: Classic CAN 8-byte frame — USB ep3 out deserializes to rxQueue via process_can
    Given exists data:
      """
      SetSafetyMode: { param1: 17 }
      """
    When USB ep3 out with hex:
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

  Scenario: CAN FD 64-byte frame — USB ep3 out deserializes to rxQueue via process_can
    Given exists data:
      """
      SetSafetyMode: { param1: 17 }
      """
    When USB ep3 out with hex:
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

  Scenario: Multi-frame batch — two classic CAN frames via USB ep3 out in sequence
    Given exists data:
      """
      SetSafetyMode: { param1: 17 }
      """
    When USB ep3 out with hex:
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
    When USB ep3 out with hex:
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

  Scenario: Rejected frame — blocked in SILENT mode, read back via USB ep1 in with rejected flag
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
    When USB ep1 in with max len 64
    Then control data should be:
      """
      usbEp1InBytes: [-128, 1, 8, 0, 0, -127, 97, 98, 99, 100, 101, 102, 103, 104]
      """

  # -- USB endpoint overflow buffer paths --
  # USB ep3 out → comms_can_write(), USB ep1 in → comms_can_read()

  Scenario: Read overflow — single CAN frame split across two USB reads
    Given exists data:
      """
      SetSafetyMode: { param1: 17 }
      """
    When USB ep3 out with hex:
      """
      80 02 08 00 00 82 01 02 03 04 05 06 07 08
      """
    When USB ep1 in with max len 5
    Then control data should be:
      """
      canCommsBuffers.readBufferPtr: 9
      """
    When USB ep1 in with max len 64
    Then control data should be:
      """
      canCommsBuffers.readBufferPtr: 0
      """
    Then control data should be:
      """
      usbEp1InBytes: [-126, 1, 2, 3, 4, 5, 6, 7, 8]
      """

  Scenario: Read overflow — two frames, first USB read gets frame1 + partial frame2 tail
    Given exists data:
      """
      SetSafetyMode: { param1: 17 }
      """
    When USB ep3 out with hex:
      """
      80 02 08 00 00 82 01 02 03 04 05 06 07 08
      80 02 10 00 00 8a 09 0a 0b 0c 0d 0e 0f 10
      """
    When USB ep1 in with max len 17
    Then control data should be:
      """
      canCommsBuffers.readBufferPtr: 11
      """
    When USB ep1 in with max len 64
    Then control data should be:
      """
      canCommsBuffers.readBufferPtr: 0
      """
    Then control data should be:
      """
      usbEp1InBytes: [0, 0, -118, 9, 10, 11, 12, 13, 14, 15, 16]
      """

  Scenario: Write overflow — partial frame completed in second USB write call
    Given exists data:
      """
      SetSafetyMode: { param1: 17 }
      """
    When USB ep3 out with hex:
      """
      80 02 08 00 00
      """
    Then control data should be:
      """
      canCommsBuffers.writeBufferPtr: 5
      """
    Then control data should be:
      """
      canCommsBuffers.writeBufferTail: 9
      """
    Then control data should be:
      """
      rxQueue: []
      """
    When USB ep3 out with hex:
      """
      82 01 02 03 04 05 06 07 08
      """
    Then control data should be:
      """
      canCommsBuffers.writeBufferPtr: 0
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

  Scenario: Write overflow — partial frame not completed in second USB write, completed in third
    Given exists data:
      """
      SetSafetyMode: { param1: 17 }
      """
    When USB ep3 out with hex:
      """
      80 02 08 00 00
      """
    Then control data should be:
      """
      canCommsBuffers.writeBufferPtr: 5
      """
    Then control data should be:
      """
      canCommsBuffers.writeBufferTail: 9
      """
    When USB ep3 out with hex:
      """
      82 01 02
      """
    Then control data should be:
      """
      canCommsBuffers.writeBufferPtr: 8
      """
    Then control data should be:
      """
      canCommsBuffers.writeBufferTail: 6
      """
    Then control data should be:
      """
      rxQueue: []
      """
    When USB ep3 out with hex:
      """
      03 04 05 06 07 08
      """
    Then control data should be:
      """
      canCommsBuffers.writeBufferPtr: 0
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

  Scenario: Write overflow — multi-frame USB write with trailing partial frame
    Given exists data:
      """
      SetSafetyMode: { param1: 17 }
      """
    When USB ep3 out with hex:
      """
      80 02 08 00 00 82 01 02 03 04 05 06 07 08
      80 02 10 00 00 8a 09 0a 0b 0c 0d 0e 0f 10
      80 02 08 00 00
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
    Then control data should be:
      """
      canCommsBuffers.writeBufferPtr: 5
      """
    Then control data should be:
      """
      canCommsBuffers.writeBufferTail: 9
      """
    When USB ep3 out with hex:
      """
      82 01 02 03 04 05 06 07 08
      """
    Then control data should be:
      """
      canCommsBuffers.writeBufferPtr: 0
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
