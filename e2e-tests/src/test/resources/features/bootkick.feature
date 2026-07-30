# language: en
Feature: Bootkick SOM Reset FSM

  BootState enum: BOOT_STANDBY=0, BOOT_BOOTKICK=1, BOOT_RESET=2.
  Uses callTickHandler() — the full production tick_handler() from board/main.c.
  The 1Hz block fires every 8th call, so 8 × N calls advances N ticks.
  heartbeatDisabled prevents the heartbeat timeout from interfering.
  Control via: ignitionLine + harnessStatus (both required for harness_check_ignition),
  somUartWptr (serial activity).

  Background:
    Given exists data:
      """
      ControlSetup: {
        heartbeatDisabled: 1
      }
      """

  Scenario: Ignition rising edge triggers BOOT_BOOTKICK
    Given exists data:
      """
      ControlSetup: {
        ignitionLine: 1
        harnessStatus: 1
      }
      """
    When call tick handler 8 times
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
    When call tick handler 8 times
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
    When call tick handler 8 times
    # Set ignition → rising edge on next tick
    Given exists data:
      """
      ControlSetup: {
        ignitionLine: 1
        harnessStatus: 1
      }
      """
    When call tick handler 8 times
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
    When call tick handler 8 times
    Given exists data:
      """
      ControlSetup: {
        ignitionLine: 1
        harnessStatus: 1
      }
      """
    # 21 more 1Hz ticks: 1 rising edge + 20 waiting countdown → BOOT_RESET
    When call tick handler 168 times
    Then control data should be:
      """
      bootkick: {
        state: 2
        resetTriggered: 1
        resetCountdown: 3
      }
      """

  Scenario: BOOT_RESET expires after 5 more ticks, returns to BOOT_BOOTKICK
    When call tick handler 8 times
    Given exists data:
      """
      ControlSetup: {
        ignitionLine: 1
        harnessStatus: 1
      }
      """
    When call tick handler 200 times
    Then control data should be:
      """
      bootkick: {
        state: 1
        resetTriggered: 1
        resetCountdown: 0
      }
      """

  Scenario: Serial activity aborts waiting countdown
    # First enter STANDBY via heartbeat
    When call tick handler 8 times
    # Trigger STANDBY→BOOTKICK edge, countdown starts at 20 → 19 after first decrement
    Given exists data:
      """
      ControlSetup: {
        ignitionLine: 1
        harnessStatus: 1
      }
      """
    When call tick handler 8 times
    Then control data should be:
      """
      bootkick: {
        state: 1
        waitingCountdown: 19
        resetTriggered: 0
      }
      """
    # Now inject serial activity → countdown must be aborted to 0
    Given exists data:
      """
      ControlSetup: {
        somUartWptr: 42
      }
      """
    When call tick handler 8 times
    Then control data should be:
      """
      bootkick: {
        state: 1
        waitingCountdown: 0
        resetTriggered: 0
      }
      """

  Scenario: reset_triggered prevents second reset cycle
    When call tick handler 8 times
    Given exists data:
      """
      ControlSetup: {
        ignitionLine: 1
        harnessStatus: 1
      }
      """
    When call tick handler 184 times
    # Toggle ignition to create STANDBY→BOOTKICK edge
    Given exists data:
      """
      ControlSetup: {
        ignitionLine: 0
        harnessStatus: 1
      }
      """
    When call tick handler 8 times
    Given exists data:
      """
      ControlSetup: {
        ignitionLine: 1
        harnessStatus: 1
      }
      """
    When call tick handler 8 times
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
    When call tick handler 8 times
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
        ignitionCan: 1
      }
      """
    When call tick handler 8 times
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
    When call tick handler 8 times
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
    When call tick handler 8 times
    Given exists data:
      """
      ControlSetup: {
        ignitionCan: 1
      }
      """
    When call tick handler 176 times
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
        ignitionCan: 1
      }
      """
    When call tick handler 8 times
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
    When call tick handler 8 times
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
    When call tick handler 8 times
    Given exists data:
      """
      ControlSetup: {
        ignitionCan: 1
      }
      """
    When call tick handler 176 times
    Then control data should be:
      """
      stopModeRegs: {
        gpioAOdr: 1L
        gpioCOdr: 0L
      }
      """
