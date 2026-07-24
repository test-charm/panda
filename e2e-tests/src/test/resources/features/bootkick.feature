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
      : {
        bootkickState: 1
        bootkickResetTriggered: 0
        bootkickWaitingCountdown: 0
        bootkickResetCountdown: 0
      }
      """

  Scenario: Recent heartbeat transitions to BOOT_STANDBY
    Given exists data:
      """
      ControlSetup: { ... }
      """
    When tick handler:
    Then control data should be:
      """
      : {
        bootkickState: 0
        bootkickResetTriggered: 0
        bootkickWaitingCountdown: 0
      }
      """

  Scenario: STANDBY to BOOTKICK edge starts 20-tick waiting countdown
    Given exists data:
      """
      ControlSetup: { ... }
      """
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
      : {
        bootkickState: 1
        bootkickResetTriggered: 0
        bootkickWaitingCountdown: 19
        bootkickResetCountdown: 0
      }
      """

  Scenario: Full countdown triggers BOOT_RESET after 22 ticks
    Given exists data:
      """
      ControlSetup: { ... }
      """
    When tick handler:
    Given exists data:
      """
      ControlSetup: {
        ignitionLine: 1
      }
      """
    # 21 more tick_handler calls: 1 rising edge tick + 20 countdown ticks
    When tick handler:
    When tick handler:
    When tick handler:
    When tick handler:
    When tick handler:
    When tick handler:
    When tick handler:
    When tick handler:
    When tick handler:
    When tick handler:
    When tick handler:
    When tick handler:
    When tick handler:
    When tick handler:
    When tick handler:
    When tick handler:
    When tick handler:
    When tick handler:
    When tick handler:
    When tick handler:
    When tick handler:
    Then control data should be:
      """
      : {
        bootkickState: 2
        bootkickResetTriggered: 1
        bootkickResetCountdown: 3
      }
      """

  Scenario: BOOT_RESET expires after 5 more ticks, returns to BOOT_BOOTKICK
    Given exists data:
      """
      ControlSetup: { ... }
      """
    When tick handler:
    Given exists data:
      """
      ControlSetup: {
        ignitionLine: 1
      }
      """
    When tick handler:
    When tick handler:
    When tick handler:
    When tick handler:
    When tick handler:
    When tick handler:
    When tick handler:
    When tick handler:
    When tick handler:
    When tick handler:
    When tick handler:
    When tick handler:
    When tick handler:
    When tick handler:
    When tick handler:
    When tick handler:
    When tick handler:
    When tick handler:
    When tick handler:
    When tick handler:
    When tick handler:
    When tick handler:
    When tick handler:
    When tick handler:
    When tick handler:
    When tick handler:
    When tick handler:
    Then control data should be:
      """
      : {
        bootkickState: 1
        bootkickResetTriggered: 1
        bootkickResetCountdown: 0
      }
      """

  Scenario: Serial activity aborts waiting countdown
    Given exists data:
      """
      ControlSetup: {
        somUartWptr: 0
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
    When tick handler:
    When tick handler:
    When tick handler:
    When tick handler:
    When tick handler:
    When tick handler:
    When tick handler:
    When tick handler:
    # Simulate UART activity
    Given exists data:
      """
      ControlSetup: {
        somUartWptr: 42
      }
      """
    When tick handler:
    Then control data should be:
      """
      : {
        bootkickState: 1
        bootkickWaitingCountdown: 0
        bootkickResetTriggered: 0
      }
      """

  Scenario: reset_triggered prevents second reset cycle
    Given exists data:
      """
      ControlSetup: { ... }
      """
    When tick handler:
    Given exists data:
      """
      ControlSetup: {
        ignitionLine: 1
      }
      """
    When tick handler:
    When tick handler:
    When tick handler:
    When tick handler:
    When tick handler:
    When tick handler:
    When tick handler:
    When tick handler:
    When tick handler:
    When tick handler:
    When tick handler:
    When tick handler:
    When tick handler:
    When tick handler:
    When tick handler:
    When tick handler:
    When tick handler:
    When tick handler:
    When tick handler:
    When tick handler:
    When tick handler:
    When tick handler:
    When tick handler:
    When tick handler:
    When tick handler:
    When tick handler:
    When tick handler:
    When tick handler:
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
      : {
        bootkickState: 1
        bootkickResetTriggered: 1
        bootkickWaitingCountdown: 0
      }
      """

  Scenario: Harness insertion triggers BOOT_BOOTKICK
    Given exists data:
      """
      ControlSetup: {
        harnessStatus: 0
      }
      """
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
      : {
        bootkickState: 1
        bootkickResetTriggered: 0
      }
      """
