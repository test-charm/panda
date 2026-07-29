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

  # ---- Phase E.4: can_rx() RX FIFO path coverage ----

  Scenario: can_rx processes a standard CAN frame from RX FIFO
    Given exists data:
      """
      SetSafetyMode: { param1: 17 }
      StandardRxFrame: {
        address: 256
        bus: 0
        data: testdata
      }
      """
    When can rx send:
      """
      CanRxSendRequest: {
        rxf0sBus: 0
        f0gi: 0
        f0fl: 1
        full: 0
        irBus: 0
        rf0n: 1
        canNumber: 0
      }
      """
    Then control data should be:
      """
      : {
        rxQueue[0]: {
          address: 256
          returned: false
          rejected: false
          data.string: testdata
          bus: 0
        }
        canHealth0: {
          totalRxCnt: 1
          totalFwdCnt: 0
        }
      }
      """

  Scenario: can_rx processes an extended CAN frame from RX FIFO
    Given exists data:
      """
      SetSafetyMode: { param1: 17 }
      ExtendedRxFrame: {
        address: 305419896
        bus: 0
        data: extended
      }
      """
    When can rx send:
      """
      NormalCanRxSendRequest: { ... }
      """
    Then control data should be:
      """
      : {
        rxQueue[0]: {
          address: 305419896
          returned: false
          rejected: false
          extended: true
          data.string: extended
          bus: 0
        }
        canHealth0.totalRxCnt: 1
      }
      """

  Scenario: can_rx auto-enables canfd_enabled on CAN-FD frame
    Given exists data:
      """
      CanFdRxFrame: {
        address: 256
        bus: 0
        data: fdtest!!
      }
      """
    When can rx send:
      """
      NormalCanRxSendRequest: { ... }
      """
    Then control data should be:
      """
      : {
        rxQueue[0]: {
          address: 256
          returned: false
          fd: true
          data.string: fdtest!!
        }
        canfdEnabled0: true
        brsEnabled0: false
      }
      """

  Scenario: can_rx auto-enables brs_enabled on BRS frame
    Given exists data:
      """
      BrsRxFrame: {
        address: 256
        bus: 0
        data: brstest!
      }
      """
    When can rx send:
      """
      NormalCanRxSendRequest: { ... }
      """
    Then control data should be:
      """
      : {
        rxQueue[0]: {
          address: 256
          returned: false
          fd: true
          data.string: brstest!
        }
        canfdEnabled0: true
        brsEnabled0: true
      }
      """

  Scenario: can_rx handles FIFO full overwrite mode — offset index and lost count
    Given exists data:
      """
      SetSafetyMode: { param1: 17 }
      StandardRxFrame: {
        address: 512
        bus: 0
        data: fulltest
        elementIndex: 1
      }
      """
    # F0F=1 means FIFO is full and in overwrite mode; F0GI=0 → reads from index 1
    When can rx send:
      """
      NormalCanRxSendRequest: {
        full: 1
      }
      """
    Then control data should be:
      """
      : {
        rxQueue[0]: {
          address: 512
          data.string: fulltest
        }
        canHealth0: {
          totalRxCnt: 1
          totalRxLostCnt: 1
        }
        fdcanRxf0aBus0: 1
      }
      """

  Scenario: can_rx forwards CAN message to another bus
    Given exists data:
      """
      SetSafetyMode: { param1: 17 }
      StandardRxFrame: {
        address: 256
        bus: 0
        data: forward8
      }
      """
    When set forwarding bus 0 to bus 1
    And can rx send:
      """
      NormalCanRxSendRequest: { ... }
      """
    Then control data should be:
      """
      : {
        rxQueue[0]: {
          address: 256
          data.string: forward8
        }
        canHealth0: {
          totalFwdCnt: 1
          totalRxCnt: 1
        }
      }
      """

  Scenario: can_rx handles IRQ error flags (PED + PEA → update_can_health_pkt)
    When set fdcan ir bus 0 errors ped 1 pea 1 ep 0 bo 0 rf0l 0
    When can rx 0
    Then control data should be:
      """
      : {
        canHealth0: {
          lastError: 0
          errorPassive: 0
          canCoreResetCnt: 0
        }
      }
      """

  Scenario: can_rx increments safety_rx_invalid when safety_rx_hook rejects frame
    # TOYOTA mode has rx_checks for 0x260; panda XOR checksum ≠ Toyota sum checksum → rejected
    Given exists data:
      """
      SetSafetyMode: { param1: 2 }
      StandardRxFrame: {
        address: 608
        bus: 0
        data: toyota!!
      }
      """
    And can rx send:
      """
      NormalCanRxSendRequest: { ... }
      """
    Then control data should be:
      """
      : {
        directSafetyRxInvalid: 1
        canHealth0.totalRxCnt: 1
      }
      """
