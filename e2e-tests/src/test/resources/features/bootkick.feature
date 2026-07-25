# language: en
Feature: Bootkick SOM Reset FSM

  BootState enum: BOOT_STANDBY=0, BOOT_BOOTKICK=1, BOOT_RESET=2.
  tick_handler() calls the real bootkick_tick() from board/drivers/bootkick.h.
  Each call increments heartbeat_counter and decrements siren_countdown.
  Control via: ignitionLine (harness_check_ignition), harnessStatus (harness.status),
  somUartWptr (serial activity).

  Scenario: Ignition rising edge triggers BOOT_BOOTKICK
    Given exists data:
      """
      ControlSetup: {
        ignitionLine: 1
      }
      """
    When tick handler:
    Then control data should be:
      """
      bootkick: {
        state: 1
        resetTriggered: 0
        waitingCountdown: 0
        resetCountdown: 0
      }
      """

  Scenario: Recent heartbeat transitions to BOOT_STANDBY
    When tick handler:
    Then control data should be:
      """
      bootkick: {
        state: 0
        resetTriggered: 0
        waitingCountdown: 0
      }
      """

  Scenario: STANDBY to BOOTKICK edge starts 20-tick waiting countdown
    # First tick with no ignition → STANDBY (recent_heartbeat=1 on first call)
    When tick handler:
    # Set ignition → rising edge on next tick
    Given exists data:
      """
      ControlSetup: {
        ignitionLine: 1
      }
      """
    When tick handler:
    Then control data should be:
      """
      bootkick: {
        state: 1
        resetTriggered: 0
        waitingCountdown: 19
        resetCountdown: 0
      }
      """

  Scenario: Full countdown triggers BOOT_RESET after 22 ticks
    When tick handler:
    Given exists data:
      """
      ControlSetup: {
        ignitionLine: 1
      }
      """
    # 21 more tick_handler calls: 1 rising edge tick + 20 countdown ticks
    When tick handler 21 times
    Then control data should be:
      """
      bootkick: {
        state: 2
        resetTriggered: 1
        resetCountdown: 3
      }
      """

  Scenario: BOOT_RESET expires after 5 more ticks, returns to BOOT_BOOTKICK
    When tick handler:
    Given exists data:
      """
      ControlSetup: {
        ignitionLine: 1
      }
      """
    When tick handler 25 times
    Then control data should be:
      """
      bootkick: {
        state: 1
        resetTriggered: 1
        resetCountdown: 0
      }
      """

  Scenario: Serial activity aborts waiting countdown
    Given exists data:
      """
      ControlSetup: {
        ignitionLine: 1
        somUartWptr: 42
      }
      """
    When tick handler:
    Then control data should be:
      """
      bootkick: {
        state: 1
        waitingCountdown: 0
        resetTriggered: 0
      }
      """

  Scenario: reset_triggered prevents second reset cycle
    When tick handler:
    Given exists data:
      """
      ControlSetup: {
        ignitionLine: 1
      }
      """
    When tick handler 23 times
    # Toggle ignition to create STANDBY→BOOTKICK edge
    Given exists data:
      """
      ControlSetup: {
        ignitionLine: 0
      }
      """
    When tick handler:
    Given exists data:
      """
      ControlSetup: {
        ignitionLine: 1
      }
      """
    When tick handler:
    Then control data should be:
      """
      bootkick: {
        state: 1
        resetTriggered: 1
        waitingCountdown: 0
      }
      """

  Scenario: Harness insertion triggers BOOT_BOOTKICK
    Given exists data:
      """
      ControlSetup: {
        harnessStatus: 1
      }
      """
    # First tick: heartbeat=0 (recent), ignition=0, harness_inserted=true → BOOTKICK
    When tick handler:
    Then control data should be:
      """
      bootkick: {
        state: 1
        resetTriggered: 0
      }
      """

  @cuatro
  Scenario: BOOT_BOOTKICK drives bootkick GPIO low
    # PA0=0, PC11=0 (state == BOOT_BOOTKICK)
    Given exists data:
      """
      ControlSetup: {
        ignitionLine: 1
      }
      """
    When tick handler:
    Then control data should be:
      """
      stopModeRegs: {
        gpioAOdr: 0L
        gpioCOdr: 0L
      }
      """

  @cuatro
  Scenario: BOOT_STANDBY drives bootkick GPIO high
    # PA0=1, PC11=1 (state != BOOT_BOOTKICK)
    When tick handler:
    Then control data should be:
      """
      stopModeRegs: {
        gpioAOdr: 1L
        gpioCOdr: 2048L
      }
      """

  @cuatro
  Scenario: BOOT_RESET drives bootkick GPIO high
    # PA0=1, PC11=1 (state != BOOT_BOOTKICK)
    When tick handler:
    Given exists data:
      """
      ControlSetup: {
        ignitionLine: 1
      }
      """
    When tick handler 22 times
    Then control data should be:
      """
      stopModeRegs: {
        gpioAOdr: 1L
        gpioCOdr: 2048L
      }
      """

  @tres
  Scenario: BOOT_BOOTKICK drives bootkick GPIO low (tres)
    # PA0=0, PC12=1 (state == BOOT_BOOTKICK, state != BOOT_RESET)
    Given exists data:
      """
      ControlSetup: {
        ignitionLine: 1
      }
      """
    When tick handler:
    Then control data should be:
      """
      stopModeRegs: {
        gpioAOdr: 0L
        gpioCOdr: 4096L
      }
      """

  @tres
  Scenario: BOOT_STANDBY drives bootkick GPIO high (tres)
    # PA0=1, PC12=1 (state != BOOT_BOOTKICK, state != BOOT_RESET)
    When tick handler:
    Then control data should be:
      """
      stopModeRegs: {
        gpioAOdr: 1L
        gpioCOdr: 4096L
      }
      """

  @tres
  Scenario: BOOT_RESET drives PC12 low (tres)
    # PA0=1, PC12=0 (state != BOOT_BOOTKICK, state == BOOT_RESET)
    When tick handler:
    Given exists data:
      """
      ControlSetup: {
        ignitionLine: 1
      }
      """
    When tick handler 22 times
    Then control data should be:
      """
      stopModeRegs: {
        gpioAOdr: 1L
        gpioCOdr: 0L
      }
      """
