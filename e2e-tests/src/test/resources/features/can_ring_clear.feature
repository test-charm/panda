# language: en
Feature: CAN Ring Buffer Clear

  Scenario: Clearing RX queue with param1=0xFFFF (-1 as short)
    Given exists data:
      """
      PowerTrainBusBlockedRequest: {
        data: rx-clear-test
      }
      """
    When control write:
      """
      UsbControlRequest: {
        request: -15y
        param1: -1
        param2: 0
      }
      """
    Then control data should be:
      """
      : {
        rxQueue: []
      }
      """

  Scenario: Clearing TX bus 0 queue with param1=0
    Given exists data:
      """
      SetSafetyMode: {
        param1: 17
      }
      PowerTrainBusBlockedRequest: {
        data: tx-clear-test
      }
      """
    When control write:
      """
      ClearCanRing: {
        param1: 0
      }
      """
    Then control data should be:
      """
      : {
        txQueue[0]: []
      }
      """

  Scenario: Clearing TX bus 1 queue with param1=1
    Given exists data:
      """
      SetSafetyMode: {
        param1: 17
      }
      CanSendRequest: {
        address: 256
        bus: 1y
        data: tx-clear-bus1
      }
      """
    When control write:
      """
      ClearCanRing: {
        param1: 1
      }
      """
    Then control data should be:
      """
      : {
        txQueue[1]: []
      }
      """

  Scenario: Invalid bus number param1=3 is no-op, queue not cleared
    Given exists data:
      """
      SetSafetyMode: {
        param1: 17
      }
      PowerTrainBusBlockedRequest: {
        data: no-clear
      }
      """
    When control write:
      """
      ClearCanRing: {
        param1: 3
      }
      """
    Then control data should be:
      """
      : {
        txQueue[0]= {
          rejected: false
          data.string: no-clear
        }
      }
      """