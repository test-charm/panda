# language: en
Feature: Board initialization

  Board xxx_init() functions configure GPIO modes, output types, and pull-up/pull-down
  resistors for each hardware variant. These functions are called by panda_main() on
  real hardware but were previously never exercised in e2e tests.

  common_init_gpio() and gpio_uart7_init() have been un-stubbed — their real
  implementations from board/stm32h7/peripherals.h now run in e2e.
  uart_init(), sound_init(), and pwm_init() remain stubbed (no GPIO side effects).

  @cuatro
  Scenario: Cuatro init configures GPIO MODER for bootkick, analog, CAN transceiver pins
    When board init
    Then control data should be:
      """
      : {
        boardInit: {
          gpioAModer: 42086433L
          gpioBModer: 2685036545L
          gpioCModer: 4328450L
          gpioDModer: 176226304L
          gpioEModer: 696960L
          gpioFModer: 12582912L
          gpioGModer: 2621440L
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

  @cuatro
  Scenario: Cuatro init configures USB OSPEEDR via common_init_gpio
    When board init
    Then control data should be:
      """
      : {
        boardInit: {
          gpioAOspeedr: 62914560L
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
          gpioBModer: 269101388L
          gpioBOtyper: 16384L
          gpioBPupdr: 268435456L
          gpioBOdr: 16384L
          gpioDModer: 16384L
          gpioGModer: 6815744L
          gpioFModer: 12582912L
        }
      }
      """

  @red
  Scenario: Red init configures USB pins via common_init_gpio
    When board init
    Then control data should be:
      """
      : {
        boardInit: {
          gpioAModer: 41943040L
          gpioAOspeedr: 62914560L
        }
      }
      """

