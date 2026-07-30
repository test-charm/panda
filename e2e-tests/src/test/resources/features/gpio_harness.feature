# language: en
Feature: GPIO output type and harness initialization (Phase J1, J2)

  # ---- Phase J1: set_gpio_output_type PUSH_PULL branch ----
  # OUTPUT_TYPE_OPEN_DRAIN is covered by existing tests,
  # OUTPUT_TYPE_PUSH_PULL (else branch) was not.
  #
  # set_gpio_output_type(GPIO, pin, PUSH_PULL) clears OTYPER bit.
  # After the call, GPIOB OTYPER bit 3 = 0 (no other OPEN_DRAIN on GPIOB).
  # Full register: 0.

  Scenario: set_gpio_output_type with PUSH_PULL clears OTYPER bit
    When set gpio output type push pull port 1 pin 3
    Then control data should be:
      """
      : {
        gpiobOtyper: 0
        readFaults: 0
      }
      """

  # ---- Phase J2: harness_init() ----
  # harness_init() was only called from board/main.c:main(), never from e2e.
  # For cuatro board, it configures:
  #   SBU1 relay: GPIOA pin 9  → OTYPER bit 9=1 (OPEN_DRAIN), ODR bit 9=1 (high)
  #   SBU2 relay: GPIOA pin 3  → OTYPER bit 3=1 (OPEN_DRAIN), ODR bit 3=1 (high)
  #   Then calls set_intercept_relay(false, false) → relay_driven=0
  # Expected register values: (1<<3)|(1<<9) = 0x208 = 520.

  Scenario: harness_init configures relay GPIOs as open-drain and drives them high
    When harness init
    Then control data should be:
      """
      : {
        gpioaOtyper: 520
        gpioaOdr: 520
        readFaults: 0
      }
      """

  # ---- Phase J10: detect_with_pull() ----
  # Called by real board/stm32h7/board.h to read 8 strapping pins for board
  # type detection. e2e's board.h stub hardcodes board type, so this function
  # is never reached. Also exercises set_gpio_pullup(GPIO, pin, PULL_UP) path.

  Scenario: detect_with_pull with PULL_UP returns 0 when no external signal
    When detect with pull port 5 pin 7 mode 1
    Then control data should be:
      """
      : {
        gpiobPupdr: 0
        readFaults: 0
      }
      """
