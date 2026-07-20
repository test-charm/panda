# language: en
Feature: CAN Loopback Mode

  Scenario: Enabling loopback sets FDCAN TEST and MON bits
    Given control write:
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
        fdcanRegs[0]= {
          cccr: [ -96y, * ]
        }
      }
      """

  Scenario: Disabling loopback clears FDCAN TEST bit but keeps MON from silent mode
    Given control write:
      """
      UsbControlRequest: {
        request: -27y       # 0xe5
        param1: 0
        param2: 0
      }
      """
    Then control data should be:
      """
      : {
        fdcanRegs[0]= {
          cccr: [ 0x20y, * ]
        }
      }
      """

  Scenario: Re-enabling loopback clears existing CAN TX queues
    Given control write:
      """
      UsbControlRequest: {
        request: -36y       # 0xdc, SAFETY_ALLOUTPUT
        param1: 17
        param2: 0
      }
      """
    When can send with result 0:
      """
      PowerTrainBusBlockedRequest: {
        data: queued
      }
      """
    When control write "UsbControlRequest":
      """
      {
        request: -27y       # 0xe5
        param1: 1
        param2: 0
      }
      """
    Then control data should be:
      """
      : {
        txQueue[0]: []
        rxQueue: []
        fdcanRegs[0]= {
          cccr: [ -96y, * ]
        }
      }
      """

  Scenario: CAN send still works after loopback is enabled
    Given control write:
      """
      UsbControlRequest: {
        request: -36y       # 0xdc, SAFETY_ALLOUTPUT
        param1: 17
        param2: 0
      }
      """
    Given control write:
      """
      UsbControlRequest: {
        request: -27y       # 0xe5
        param1: 1
        param2: 0
      }
      """
    When can send with result 0:
      """
      CanSendRequest: {
        address: 512
        bus: 0y
        data: loopback-msg
      }
      """
    Then control data should be:
      """
      : {
        txQueue[0]= {
          address: 512
          rejected: false
          data.string: loopback-msg
        }
      }
      """
