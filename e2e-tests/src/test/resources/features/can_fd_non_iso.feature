# language: en
Feature: CAN FD Non-ISO Mode

  Scenario: Disabling CAN FD non-ISO mode and re-initializing FDCAN
    When control write:
      """
      UsbControlRequest: {
        request: -4y
        param1: 0
        param2: 0
      }
      """
    Then control data should be:
      """
      : {
        canFdConfig= {
          canfdNonIso0: false
        }
        fdcanRegs[0]= {
          cccr: [ 0b0010_0000y, 0b0101_0011y ]
          ie: [ 0b0000_1001y, 0b0000_1000y, -128y, 0b0001_1010y ]        # -128y 不能写成 0b1000_0000y
          nbtp: [ 0b0000_1111y, 0b0011_1110y, 0b0000_0001y, 0b0001_1110y ]
          dbtp: [ 0b0011_0011y, 0b0000_1110y, 0b0000_0001y, 0b0000_0000y ]
          txbc: [ -16y, 0b0000_1100y, 0b0000_0000y, 0b0000_0001y ]
          rxf0c: [ 0b0000_0000y, 0b0000_0000y, 0b0010_1110y, -128y ]                           # -128y 不能写成 0b1000_0000y
          txesc: [ 0b0000_0111y ]
          rxesc: [ 0b0000_0111y ]
          gfc: [ 0b0000_0000y ]
          ile: [ 0b0000_0011y ]
        }
      }
      """

  Scenario: Enabling CAN FD non-ISO mode on bus 0
    When control write:
      """
      SetCanFdNonIso: {
        param1: 0
        param2: 1
      }
      """
    Then control data should be:
      """
      : {
        canFdConfig= {
          canfdNonIso0: true
        }
        fdcanRegs[0]= {
          cccr: [ 0b0010_0000y, -45y ]
        }
      }
      """

  Scenario: Invalid bus number is no-op
    When control write:
      """
      SetCanFdNonIso: {
        param1: 3
        param2: 1
      }
      """
    Then control data should be:
      """
      : {
        canFdConfig= {
          canfdNonIso0: false
          canfdNonIso1: false
          canfdNonIso2: false
        }
        fdcanRegs[0]= {
          cccr: [ 0b0010_0000y, 0b0101_0011y ]
        }
      }
      """