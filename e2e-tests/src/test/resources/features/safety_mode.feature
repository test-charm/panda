# language: en
Feature: Safety Mode Switching

  Scenario: SILENT mode blocks CAN TX through safety pipeline
    Given control write:
      """
      UsbControlRequest: {
        request: -36y
        param1: 0     # SAFETY_SILENT
        param2: 0
      }
      """
    When can send with result 1:
      """
      CanSendRequest: {
        address: 256
        bus: 0y
        data: blocked
      }
      """
    Then control data should be:
      """
      : {
        safetyTxBlocked: 1
        relayCall= {
          a: false
          b: false
        }
        canClearSendCall: null
        canModeCall= {
          value: 0
        }
        rxQueue= {
          address: 256
          bus: 0y
          rejected: true
          data.string: blocked
        }
        txQueue[0]: []
      }
      """

  Scenario: NOOUTPUT mode blocks CAN TX through safety pipeline
    Given control write:
      """
      SetSafetyMode: {
        param1: 19     # SAFETY_NOOUTPUT
      }
      """
    When can send with result 1:
      """
      PowerTrainBusBlockedRequest: {
        data: blocked
      }
      """
    Then control data should be:
      """
      : {
        safetyTxBlocked: 1
        relayCall= {
          a: false
          b: false
        }
        canClearSendCall: null
        canModeCall= {
          value: 0
        }
        rxQueue= {
          rejected: true
          data.string: blocked
        }
        txQueue[0]: []
      }
      """

  Scenario: ALLOUTPUT mode allows all CAN TX through safety pipeline
    Given control write:
      """
      SetSafetyMode: {
        param1: 17     # SAFETY_ALLOUTPUT
      }
      """
    When can send with result 0:
      """
      PowerTrainBusBlockedRequest: {
        data: allowed
      }
      """
    Then control data should be:
      """
      : {
        safetyTxBlocked: 0
        relayCall= {
          a: true
          b: false
        }
        canClearSendCall: null
        canModeCall= {
          value: 0
        }
        rxQueue: []
        txQueue[0]= {
          rejected: false
          data.string: allowed
        }
      }
      """

  Scenario: ELM327 OBD_CAN2 mode allows valid OBD-II CAN TX
    Given control write:
      """
      SetSafetyMode: {
        param1: 3     # SAFETY_ELM327
        param2: 0     # OBD_CAN2 sub-mode
      }
      """
    When can send with result 0:
      """
      PowerTrainBusRequest: {
        address: 2015
        data: '12345678'
      }
      """
    Then control data should be:
      """
      : {
        safetyTxBlocked: 0
        relayCall= {
          a: false
          b: false
        }
        canClearSendCall= {
          x: 1
          y: 1
        }
        canModeCall= {
          value: 1
        }
        rxQueue: []
        txQueue[0]= {
          address: 2015
          rejected: false
          data.string: '12345678'
        }
      }
      """

  Scenario: ELM327 NORMAL mode allows valid OBD-II CAN TX
    Given control write:
      """
      SetSafetyMode: {
        param1: 3     # SAFETY_ELM327
        param2: 1     # NORMAL sub-mode
      }
      """
    When can send with result 0:
      """
      PowerTrainBusRequest: {
        address: 2015
        data: '12345678'
      }
      """
    Then control data should be:
      """
      : {
        safetyTxBlocked: 0
        relayCall= {
          a: false
          b: false
        }
        canClearSendCall= {
          x: 1
          y: 1
        }
        canModeCall= {
          value: 0
        }
        rxQueue: []
        txQueue[0]= {
          address: 2015
          rejected: false
          data.string: '12345678'
        }
      }
      """

  Scenario: TOYOTA car-safety mode blocks non-TOYOTA CAN TX
    Given control write:
      """
      SetSafetyMode: {
        param1: 2     # SAFETY_TOYOTA
      }
      """
    When can send with result 1:
      """
      PowerTrainBusBlockedRequest: {
        data: blocked
      }
      """
    Then control data should be:
      """
      : {
        safetyTxBlocked: 1
        relayCall= {
          a: true
          b: false
        }
        canClearSendCall: null
        canModeCall= {
          value: 0
        }
        rxQueue= {
          rejected: true
          data.string: blocked
        }
        txQueue[0]: []
      }
      """

  Scenario: Invalid safety mode falls back to SILENT
    Given control write:
      """
      SetSafetyMode: {
        param1: 7     # not in safety_hook_registry → fallback to SAFETY_SILENT
      }
      """
    When can send with result 1:
      """
      PowerTrainBusBlockedRequest: {
        data: blocked
      }
      """
    Then control data should be:
      """
      : {
        safetyTxBlocked: 1
        relayCall= {
          a: false
          b: false
        }
        canClearSendCall: null
        canModeCall= {
          value: 0
        }
        rxQueue= {
          rejected: true
          data.string: blocked
        }
        txQueue[0]: []
      }
      """

