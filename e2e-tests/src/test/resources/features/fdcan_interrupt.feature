# language: en
Feature: FDCAN Interrupt-Driven Processing (C3)

  Scenario: can_send triggers process_can — TXBAR writes and rxQueue echo
    # SAFETY_ALLOUTPUT allows all CAN messages
    Given exists data:
      """
      SetSafetyMode: { param1: 17 }
      """
    # jna_can_send → can_send → process_can (C3: full pipeline)
    When can send with result 0:
      """
      PowerTrainBusRequest: {
        address: 256
        bus: 0
        data: testdata
      }
      """
    # process_can ran internally: TXBAR[0]=1, IR.TFE=0x800, message echoed to rxQueue
    Then control data should be:
      """
      : {
        fdcanRegs[0]: {
          txbar: [1, 0, 0, 0]
          ir: [0, 8, 0, 0]
        }
        rxQueue[0]: {
          address: 256
          returned: true
          data.string: testdata
        }
      }
      """

  Scenario: process_can ignores invalid can_number (0xff guard)
    When process can 255
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
