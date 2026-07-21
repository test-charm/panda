# language: en
Feature: CAN Health Statistics

  Scenario: Valid bus 0 returns CAN health data
    When control write:
      """
      UsbControlRequest: {
        request: -62y
        param1: 0
        param2: 0
      }
      """
    Then control data should be:
      """
      : {
        canHealth0= {
          canSpeed: 500       # 5000 / 10
          canDataSpeed: 2000  # 20000 / 10
          canfdEnabled: false
          brsEnabled: false
          canfdNonIso: false
        }
      }
      """

  Scenario: Preset PSR/ECR extracts error counts correctly
    Given exists data:
      """
      ControlSetup: {
        fdcanPsr: 2     # LEC=2 (CAN_ACK_ERROR)
        fdcanEcr: 32768 # TEC=128 (0x80 << 8), REC=0
      }
      """
    When control write:
      """
      GetCanHealth: {
        param1: 0
      }
      """
    Then control data should be:
      """
      : {
        canHealth0= {
          lastError: 2               # PSR LEC = CAN_ACK_ERROR
          receiveErrorCnt: 0         # ECR REC = 0
          transmitErrorCnt: 128      # ECR TEC = 128
          canCoreResetCnt: 1         # from safety init path (set_safety_mode → ...)
        }
      }
      """

  Scenario: Invalid bus number is no-op — canHealth fields remain zero
    When control write:
      """
      GetCanHealth: {
        param1: 3
      }
      """
    Then control data should be:
      """
      : {
        canHealth0= {
          canSpeed: 0
          canDataSpeed: 0
          canfdEnabled: false
          brsEnabled: false
          canfdNonIso: false
        }
      }
      """

  Scenario: PSR status bits BO, EW, EP are extracted
    Given exists data:
      """
      ControlSetup: {
        fdcanPsr: 224   # BO=1 (bit7), EW=1 (bit6), EP=1 (bit5), LEC=0
        irReg: 0
      }
      """
    Then control data should be:
      """
      : {
        canHealth0= {
          busOffCnt: 1        # bus_off=1 → bus_off_cnt incremented
          errorWarning: 1     # PSR bit 6
          errorPassive: 1     # PSR bit 5
          lastError: 0        # LEC=0 → not stored
          lastDataError: 0    # DLEC=0
        }
      }
      """

  Scenario: ir_reg triggers total_error_cnt and can_clear_send condition
    Given exists data:
      """
      ControlSetup: {
        fdcanPsr: 2     # LEC=2 (CAN_ACK_ERROR)
        fdcanEcr: 32768 # TEC=128
        irReg: 128      # BO bit set → triggers can_clear_send path
      }
      """
    Then control data should be:
      """
      : {
        canHealth0= {
          lastError: 2               # LEC extraction
          transmitErrorCnt: 128      # ECR TEC
          totalErrorCnt: 1           # ir_reg≠0 → incremented
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

  Scenario: ir_reg with RF0L increments total_rx_lost_cnt
    Given exists data:
      """
      ControlSetup: {
        irReg: 16   # RF0L bit set
      }
      """
    Then control data should be:
      """
      : {
        canHealth0= {
          totalErrorCnt: 1
          totalRxLostCnt: 1   # ir_reg has RF0L
        }
      }
      """