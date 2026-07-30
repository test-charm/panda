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

  # ---- interrupt rate retrieval (merged from interrupt_rate.feature) ----
  # get_interrupt_rate(uint16_t interrupt_index) returns the call rate
  # for a registered interrupt handler as a 4-byte little-endian value.

  Scenario: Get interrupt rate returns zero-length response for out-of-range index
    When control write:
      """
      UsbControlRequest: {
        request: -60y            # 0xc4
        param1: 200
        param2: 0
      }
      """
    Then control data should be:
      """
      : {
        respBuffer: {
          len: 0
        }
      }
      """

  Scenario: Get interrupt rate returns 4-byte LE value for valid index with preset rate
    Given exists data:
      """
      ControlSetup: {
        interruptIndex: 7
        interruptCallRate: 0x12345678
      }
      """
    When control write:
      """
      GetInterruptRate: {
        param1: 7
      }
      """
    Then control data should be:
      """
      : {
        respBuffer= {
          len: 4
          bytes[0]: 0x78
          bytes[1]: 0x56
          bytes[2]: 0x34
          bytes[3]: 0x12
        }
      }
      """

  Scenario: Get interrupt rate returns all zero bytes for zero call rate
    When control write:
      """
      GetInterruptRate: {
        param1: 0
      }
      """
    Then control data should be:
      """
      : {
        respBuffer= {
          len: 4
          bytes[0]: 0y
          bytes[1]: 0y
          bytes[2]: 0y
          bytes[3]: 0y
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

  # ---- Phase J3: can_send with bad checksum ----
  # total_tx_checksum_error_cnt (fdcan.h:109-110) was never covered.
  # can_push_direct() pushes to queue WITHOUT calling can_set_checksum,
  # so the checksum field stays 0 (bad). process_can() then discovers
  # the bad checksum and increments the error counter.
  # Queue mapping: 0=RX, 1=TX bus0, 2=TX bus1, 3=TX bus2.

  Scenario: can_send with bad checksum increments error counter
    Given exists data:
      """
      SetSafetyMode: { param1: 17 }
      """
    # Push CAN packet with zero checksum to TX queue for bus 0 (queue 1)
    When can push raw to queue 1 addr 256 bus 0 data "testdata"
    # process_can(0) pops from can_queues[0], can_check_checksum fails → +1
    When process can 0
    Then control data should be:
      """
      : {
        canHealth0.totalTxChecksumErrorCnt: 1
      }
      """

  # ---- Phase J4: FDCAN interrupt handler wrappers ----
  # Static wrappers at fdcan.h:227-234 were never triggered via IRQ dispatch.
  # Existing tests call can_rx()/process_can() directly, bypassing the wrappers.
  # IRQ mapping: FDCAN1=19/21, FDCAN2=20/22, FDCAN3=159/160.

  Scenario: All FDCAN interrupt handler wrappers are callable via IRQ dispatch
    # FDCAN1 IT0(19)→can_rx(0), IT1(21)→process_can(0)
    When handle interrupt 19
    When handle interrupt 21
    # FDCAN2 IT0(20)→can_rx(1), IT1(22)→process_can(1)
    When handle interrupt 20
    When handle interrupt 22
    # FDCAN3 IT0(159)→can_rx(2), IT1(160)→process_can(2)
    When handle interrupt 159
    When handle interrupt 160
    Then FDCAN interrupt handlers:
      """
      : {
        isInterruptHandlerRegistered: {
          <<19,21,20,22,159,160>>: true
        }
      }
      """
