# language: en
Feature: CAN Bitrate Configuration

  Scenario: Valid bus and speed initializes FDCAN
    When control write:
      """
      UsbControlRequest: {
        request: -34y
        param1: 0
        param2: 0
      }
      """
    Then control data should be:
      """
      : {
        fdcanRegs[0]: {
          cccr: [ 0b0010_0000y, 0b0101_0011y ]
          ie: [ 0b0000_1001y, 0b0000_1000y, -128y, 0b0001_1010y ]
          nbtp: *
          dbtp: *
          txbc: [ -16y, 0b0000_1100y, 0b0000_0000y, 0b0000_0001y ]
          rxf0c: [ 0b0000_0000y, 0b0000_0000y, 0b0010_1110y, -128y ]
          txesc: [ 0b0000_0111y ]
          rxesc: [ 0b0000_0111y ]
          gfc: [ 0b0000_0000y ]
          ile: [ 0b0000_0011y ]
        }
      }
      """

  Scenario: Invalid bus number is no-op — can_init not called
    When control write:
      """
      SetCanBitrate: {
        param1: 3
        param2: 0
      }
      """
    Then control data should be:
      """
      : {
        fdcanRegs[0]: {
          cccr: [ 0b0010_0000y, 0b0101_0011y ]
          ie: [ 0b0000_1001y, 0b0000_1000y, -128y, 0b0001_1010y ]
          nbtp: [ 0b0000_1111y, 0b0011_1110y, 0b0000_0001y, 0b0001_1110y ]
          dbtp: [ 0b0011_0011y, 0b0000_1110y, 0b0000_0001y, 0b0000_0000y ]
        }
      }
      """

  Scenario: Invalid speed is no-op — can_init not called
    When control write:
      """
      SetCanBitrate: {
        param1: 0
        param2: 1
      }
      """
    Then control data should be:
      """
      : {
        fdcanRegs[0]: {
          cccr: [ 0b0010_0000y, 0b0101_0011y ]
          ie: [ 0b0000_1001y, 0b0000_1000y, -128y, 0b0001_1010y ]
          nbtp: [ 0b0000_1111y, 0b0011_1110y, 0b0000_0001y, 0b0001_1110y ]
          dbtp: [ 0b0011_0011y, 0b0000_1110y, 0b0000_0001y, 0b0000_0000y ]
        }
      }
      """