# language: en
Feature: CAN FD Data Bitrate Configuration

  Scenario: Valid bus and data speed sets canfd_enabled and brs_enabled
    When control write:
      """
      UsbControlRequest: {
        request: -7y
        param1: 0
        param2: 20000
      }
      """
    Then control data should be:
      """
      : {
        canFdConfig= {
          canfdEnabled0: true
          brsEnabled0: true
          canDataSpeed0: 20000
        }
        fdcanRegs[0]= {
          cccr: [ 0b0010_0000y, 0b0101_0011y ]
          ie: [ 0b0000_1001y, 0b0000_1000y, -128y, 0b0001_1010y ]
          nbtp: [ 0b0000_1111y, 0b0011_1110y, 0b0000_0001y, 0b0001_1110y ]
          dbtp: [ 0b0011_0011y, 0b0000_1110y, 0b0000_0001y, 0b0000_0000y ]
          txbc: [ -16y, 0b0000_1100y, 0b0000_0000y, 0b0000_0001y ]
          rxf0c: [ 0b0000_0000y, 0b0000_0000y, 0b0010_1110y, -128y ]
          txesc: [ 0b0000_0111y ]
          rxesc: [ 0b0000_0111y ]
          gfc: [ 0b0000_0000y ]
          ile: [ 0b0000_0011y ]
        }
      }
      """

  Scenario: Invalid bus number is no-op
    When control write:
      """
      SetCanFdDataBitrate: {
        param1: 3
        param2: 20000
      }
      """
    Then control data should be:
      """
      : {
        canFdConfig= {
          canfdEnabled0: false
          canfdEnabled1: false
          canfdEnabled2: false
          brsEnabled0: false
          brsEnabled1: false
          brsEnabled2: false
          canDataSpeed0: 20000
          canDataSpeed1: 20000
          canDataSpeed2: 20000
        }
        fdcanRegs[0]= {
          cccr: [ 0b0010_0000y, 0b0101_0011y ]
          ie: [ 0b0000_1001y, 0b0000_1000y, -128y, 0b0001_1010y ]
          nbtp: [ 0b0000_1111y, 0b0011_1110y, 0b0000_0001y, 0b0001_1110y ]
          dbtp: [ 0b0011_0011y, 0b0000_1110y, 0b0000_0001y, 0b0000_0000y ]
        }
      }
      """

  Scenario: Invalid data speed is no-op
    When control write:
      """
      SetCanFdDataBitrate: {
        param1: 0
        param2: 1
      }
      """
    Then control data should be:
      """
      : {
        canFdConfig= {
          canfdEnabled0: false
          brsEnabled0: false
          canDataSpeed0: 20000
        }
        fdcanRegs[0]= {
          cccr: [ 0b0010_0000y, 0b0101_0011y ]
          ie: [ 0b0000_1001y, 0b0000_1000y, -128y, 0b0001_1010y ]
          nbtp: [ 0b0000_1111y, 0b0011_1110y, 0b0000_0001y, 0b0001_1110y ]
          dbtp: [ 0b0011_0011y, 0b0000_1110y, 0b0000_0001y, 0b0000_0000y ]
        }
      }
      """