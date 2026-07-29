# language: en
Feature: CAN FD Configuration (Data Bitrate, Non-ISO Mode, Auto Switching)

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
        canFdConfig: {
          canfdEnabled0: true
          brsEnabled0: true
          canDataSpeed0: 20000
        }
        fdcanRegs[0]: {
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
        canFdConfig: {
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
        fdcanRegs[0]: {
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
        canFdConfig: {
          canfdEnabled0: false
          brsEnabled0: false
          canDataSpeed0: 20000
        }
        fdcanRegs[0]: {
          cccr: [ 0b0010_0000y, 0b0101_0011y ]
          ie: [ 0b0000_1001y, 0b0000_1000y, -128y, 0b0001_1010y ]
          nbtp: [ 0b0000_1111y, 0b0011_1110y, 0b0000_0001y, 0b0001_1110y ]
          dbtp: [ 0b0011_0011y, 0b0000_1110y, 0b0000_0001y, 0b0000_0000y ]
        }
      }
      """

  # ——— CAN FD Non-ISO Mode (merged from can_fd_non_iso.feature) ———

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
       canFdConfig: {
         canfdNonIso0: false
       }
       fdcanRegs[0]: {
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
    Then FDCAN interrupt handlers:
      """
      : {
       isInterruptHandlerRegistered: {
         <<19,21,20,22,159,160>>: true
       }
       getInterruptMaxCallRate: {
         <<19,21,20,22,159,160>>: 16000
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
       canFdConfig: {
         canfdNonIso0: true
       }
       fdcanRegs[0]: {
         cccr: [ 0b0010_0000y, -45y ]
       }
      }
      """

  Scenario: Invalid bus number for non-ISO is no-op — can_init not called
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
       canFdConfig: {
         canfdNonIso0: false
         canfdNonIso1: false
         canfdNonIso2: false
       }
       fdcanRegs[0]: {
         cccr: [ 0b0010_0000y, 0b0101_0011y ]
         ie: [ 0b0000_1001y, 0b0000_1000y, -128y, 0b0001_1010y ]
         nbtp: [ 0b0000_1111y, 0b0011_1110y, 0b0000_0001y, 0b0001_1110y ]
         dbtp: [ 0b0011_0011y, 0b0000_1110y, 0b0000_0001y, 0b0000_0000y ]
       }
      }
      """

  # ——— CAN FD Auto Switching (merged from can_fd_auto.feature) ———

  Scenario: Disabling CAN FD auto switching
    When control write:
      """
      UsbControlRequest: {
       request: -24y
       param1: 0
       param2: 0
      }
      """
    Then control data should be:
      """
      : {
       canFdConfig: {
         canfdAuto0: false
         canfdAuto1: false
         canfdAuto2: false
       }
      }
      """

  Scenario: Enabling CAN FD auto switching on bus 0
    When control write:
      """
      SetCanFdAuto: {
       param1: 0
       param2: 1
      }
      """
    Then control data should be:
      """
      : {
       canFdConfig: {
         canfdAuto0: true
         canfdAuto1: false
         canfdAuto2: false
       }
      }
      """

  Scenario: Any non-zero param2 enables CAN FD auto switching
    When control write:
      """
      SetCanFdAuto: {
       param1: 1
       param2: 255
      }
      """
    Then control data should be:
      """
      : {
       canFdConfig: {
         canfdAuto1: true
       }
      }
      """