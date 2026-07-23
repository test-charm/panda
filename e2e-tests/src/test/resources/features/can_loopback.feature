# language: en
Feature: CAN Loopback Mode

  Scenario: Enabling loopback sets FDCAN TEST and MON bits
    When control write:
      """
      UsbControlRequest: {
        request: -27y       # 0xe5
        param1: 1
        param2: 0
      }
      """
    Then control data should be:
      """
      : {
        rxQueue: []
        txQueue[0]: []
        fdcanRegs<<0,1,2>>: {
          cccr: [ -96y, 0b0101_0011y ]
          ie: [ 0b0000_1001y, 0b0000_1000y, -128y, 0b0001_1010y ]        # -128y 不能写成 0b1000_0000y
          nbtp: [ 0b0000_1111y, 0b0011_1110y, 0b0000_0001y, 0b0001_1110y ]
          dbtp: [ 0b0011_0011y, 0b0000_1110y, 0b0000_0001y, 0b0000_0000y ]
          txbc: [ *, *, 0b0000_0000y, 0b0000_0001y ]
          rxf0c: [ *, *, 0b0010_1110y, -128y ]                           # -128y 不能写成 0b1000_0000y
          txesc: [ 0b0000_0111y ]
          rxesc: [ 0b0000_0111y ]
          gfc: [ 0b0000_0000y ]
          ile: [ 0b0000_0011y ]
        }
        fdcanRegs: | txbc[0]      | txbc[1]      | rxf0c[0]     | rxf0c[1]     |
                   | -16y         | 0b0000_1100y | 0b0000_0000y | 0b0000_0000y |
                   | 0b0010_1000y | 0b0001_1010y | 0b0011_1000y | 0b0000_1101y |
                   | 0b0110_0000y | 0b0010_0111y | 0b0111_0000y | 0b0001_1010y |
      }
      """

  Scenario: Disabling loopback clears FDCAN TEST bit but keeps MON from silent mode
    When control write:
      """
      CanLoopback: {
        param1: 0
      }
      """
    Then control data should be:
      """
      : {
        fdcanRegs<<0,1,2>>: {
          cccr: [ 0x20y, 0b0101_0011y ]
        }
      }
      """

  Scenario: Re-enabling loopback clears existing CAN TX queues
    Given exists data:
      """
      SetSafetyMode: {
        param1: 17       # SAFETY_ALLOUTPUT
      }
      PowerTrainBusBlockedRequest: {
        data: queued
      }
      """
    When control write:
      """
      CanLoopback: {
        param1: 1
      }
      """
    Then control data should be:
      """
      : {
        txQueue[0]: []
        rxQueue: []
        fdcanRegs[0]: {
          cccr: [ -96y, 0b0101_0011y ]
        }
      }
      """

  Scenario: CAN send still works after loopback is enabled
    Given exists data:
      """
      SetSafetyMode: {
        param1: 17       # SAFETY_ALLOUTPUT
      }
      CanLoopback: {
        param1: 1
      }
      """
    When can send with result 0:
      """
      PowerTrainBusRequest: {
        address: 512
        data: loopback-msg
      }
      """
    Then control data should be:
      """
      : {
        txQueue[0]: {
          address: 512
          rejected: false
          data.string: loopback-msg
        }
      }
      """
