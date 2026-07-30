# language: en
Feature: Interrupt handling, rate limiting, and timer ticks

  init_interrupts(true) is called during jna_panda_init (mirrors board/main.c:272).
  This initializes the 163-entry interrupt table with unused_interrupt_handler,
  enables rate checking, and starts INTERRUPT_TIMER via interrupt_timer_init().

  Background:
    # jna_panda_init() runs in @Before setUp() → clearAll()

  Scenario: fault state is clean after init
    # Verify that faults is reset to 0 during jna_panda_init.
    Then control data should be:
      """
      : {
        readFaults: 0
      }
      """

  Scenario: Exceeding max_call_rate triggers rate-limit fault
    # TICK_TIMER_IRQ (0) = tick_handler, max_call_rate = 10.
    # 11 calls: counter 11 > 10 → FAULT_INTERRUPT_RATE_TICK = 1<<21 = 2097152.
    When handle interrupt 0 11 times
    Then control data should be:
      """
      : {
        readFaults: 2097152
      }
      """

  Scenario: Unused interrupt handler triggers FAULT_UNUSED_INTERRUPT_HANDLED
    # IRQ 1 is never registered. After init_interrupts sets all handlers to
    # unused_interrupt_handler, firing IRQ 1 triggers fault_occurred with bit 1 (=2).
    # Note: unregistered IRQs have max_call_rate=0, so rate check also fires
    # fault_occurred(0). fault_status gets overwritten to TEMPORARY.
    # Use readFaults to see the actual bitmask: faults |= 0x2, faults |= 0x0 = 2.
    When handle interrupt 1
    Then control data should be:
      """
      : {
        readFaults: 2
      }
      """

  Scenario: interrupt_timer_handler saves call_counter to call_rate and resets
    # Build up counter[0] to 5, then trigger the 1-second timer handler.
    # interrupt_timer_handler copies call_counter→call_rate and zeros call_counter.
    # Verify via USB 0xc4 (get interrupt rate) that call_rate[0] == 5.
    When handle interrupt 0 5 times
    When interrupt timer tick
    When control write:
      """
      UsbControlRequest: {
        request: -60y
        param1: 0y
        length: 4y
      }
      """
    Then control data should be:
      """
      : {
        respBuffer: {
          len: 4
          bytes[0]: 0x05
          bytes[1]: 0x00
          bytes[2]: 0x00
          bytes[3]: 0x00
        }
      }
      """

  # Phase J6: interrupt_timer_handler prints rate warning when counter > max_call_rate
  # Lines 53-54 in interrupts.h: print("Interrupt 0x... fired too often...").
  # Exceed max_call_rate (10 for IRQ 0), then call interrupt_timer_tick to trigger print.
  Scenario: interrupt_timer_handler prints when rate exceeded
    When handle interrupt 0 11 times
    When interrupt timer tick
    # Verify call_rate was saved (11) and no crash occurred
    When control write:
      """
      UsbControlRequest: {
        request: -60y
        param1: 0y
        length: 4y
      }
      """
    Then control data should be:
      """
      : {
        respBuffer: {
          len: 4
          bytes[0]: 0x0B
          bytes[1]: 0x00
          bytes[2]: 0x00
          bytes[3]: 0x00
        }
      }
      """
