# language: en
Feature: UART ring buffer overwrite mode (Phase J5)

  # put_char (TX, uart.h:84) and injectc (RX, uart.h:62) with overwrite=true
  # when next_w_ptr collides with r_ptr, overwrite mode drops
  # the oldest byte by advancing r_ptr (uart.h:71-72, 93-94).
  #
  # With fifo_size=4 and 5 bytes pushed:
  #   Bytes 1-3: w_ptr advances, no collision
  #   Byte 4:    next_w=0 wraps back to r=0 → overwrite → r_ptr=1
  #   Byte 5:    next_w=1 catches r=1 → overwrite → r_ptr=2
  #
  # Expected: r_ptr = 2 (two overwrites consumed two oldest bytes).

  Background:
    When uart overwrite init with fifo size 4

  Scenario: put_char overwrite advances r_ptr_tx when buffer full
    # Push 5 bytes (one more than fifo_size): "ABCDE"
    When uart put char overwrite with "4142434445"
    Then control data should be:
      """
      : {
        uartTxRPtr: 2
        readFaults: 0
      }
      """

  Scenario: injectc overwrite advances r_ptr_rx when buffer full
    # Push 5 bytes (one more than fifo_size): "XYZ[\"
    When uart injectc overwrite with "58595A5B5C"
    Then control data should be:
      """
      : {
        uartRxRPtr: 2
        readFaults: 0
      }
      """
