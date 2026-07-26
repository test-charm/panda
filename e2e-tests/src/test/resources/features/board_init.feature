# language: en
Feature: Board initialization

  Board xxx_init() functions configure GPIO modes, output types, and pull-up/pull-down
  resistors for each hardware variant. These functions are called by panda_main() on
  real hardware but have never been exercised in e2e tests.

  Note: common_init_gpio() is currently stubbed in e2e. These scenarios test the
  board-specific portions of the init functions.

  @cuatro
  Scenario: Cuatro init configures GPIO MODER for bootkick, analog, CAN transceiver pins
    When board init
    Then control data should be:
      """
      : {
        boardInit: {
          gpioAModer: 143393L
          gpioBModer: 2684370945L
          gpioCModer: 4328450L
          gpioDModer: 176226304L
          gpioEModer: 533120L
          gpioFModer: 0L
          gpioGModer: 0L
        }
      }
      """

  @cuatro
  Scenario: Cuatro init configures OTYPER open drain for fan and DC_IN pins
    When board init
    Then control data should be:
      """
      : {
        boardInit: {
          gpioCOtyper: 2304L
          gpioDOtyper: 8L
        }
      }
      """

  @cuatro
  Scenario: Cuatro init configures GPIO PUPDR for CAN transceiver and SOM GPIO
    When board init
    Then control data should be:
      """
      : {
        boardInit: {
          gpioCPupdr: 32L
          gpioBPupdr: 0L
        }
      }
      """

  @tres
  Scenario: Tres init configures USB LDO and board-specific GPIO
    When board init
    Then control data should be:
      """
      : {
        boardInit: {
          pwrCr3: 117440512L
          gpioCModer: 27918336L
          gpioCPupdr: 32L
          gpioCOtyper: 3072L
          gpioCOdr: 4096L
        }
      }
      """

  @red
  Scenario: Red init configures CAN transceiver enable and voltage sense pins
    When board init
    Then control data should be:
      """
      : {
        boardInit: {
          gpioBModer: 268435788L
          gpioBOtyper: 16384L
          gpioBPupdr: 268435456L
          gpioBOdr: 16384L
          gpioDModer: 16384L
          gpioGModer: 4194304L
        }
      }
      """

