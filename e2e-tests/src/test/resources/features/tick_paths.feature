# language: en
Feature: Tick handler edge paths

  The tick_handler() runs at 8 Hz. The 1 Hz block fires every 8th call.
  Use 8 × N calls to advance N seconds.

  Background:
    Given exists data:
      """
      ControlSetup: {
        safetyMode: 2
      }
      """

  # ---- has_fan = false ----
  # On red panda, has_fan = false, so fan_tick() body is entirely skipped.
  # fan_state should remain unchanged across tick calls.

  @red
  Scenario: Fan state unchanged when has_fan is false
    When call tick handler 24 times
    Then control data should be:
      """
      : {
        fanPower: 0
        fanCooldownCounter: 0
      }
      """

  # ---- heartbeat_counter overflow ----
  # heartbeat_counter is capped at UINT32_MAX (lines 179-181).
  # When set to UINT32_MAX, further 1 Hz ticks must not increment.

  Scenario: Heartbeat counter capped at UINT32_MAX
    Given exists data:
      """
      ControlSetup: {
        heartbeatCounter: -1
        heartbeatDisabled: 1
      }
      """
    When call tick handler 8 times
    Then control data should be:
      """
      heartbeat: {
        counter: -1
      }
      """

  Scenario: Heartbeat counter increments when below UINT32_MAX
    Given exists data:
      """
      ControlSetup: {
        heartbeatCounter: -2
        heartbeatDisabled: 1
      }
      """
    When call tick handler 8 times
    Then control data should be:
      """
      heartbeat: {
        counter: -1
      }
      """

  # ---- safety_mode_cnt overflow ----
  # safety_mode_cnt is a uint32_t incremented in the 1 Hz block.
  # It wraps naturally on overflow.

  Scenario: Safety mode counter wraps on overflow
    Given exists data:
      """
      ControlSetup: {
        safetyModeCnt: -1
      }
      """
    When call tick handler 8 times
    Then control data should be:
      """
      safetyModeCnt: 0
      """

  # ---- power_save_enabled + controls_allowed across harness reinit ----
  # When harness status changes, tick_handler re-calls
  #   set_safety_mode(current_safety_mode, current_safety_param)
  #   set_power_save_state(power_save_enabled)
  # The safety mode reset clears heartbeat_counter; set_power_save_state is
  # idempotent when the state hasn't changed.

  Scenario: Harness reinit resets heartbeat counter
    Given exists data:
      """
      ControlSetup: {
        safetyMode: 2
        sbu1VoltageMV: 200,
        sbu2VoltageMV: 700
      }
      """
    When control write:
      """
      SetPowerSaveState: {
        param1: 1
      }
      """
    And detect harness orientation
    And call tick handler 1 times
    Then control data should be:
      """
      : {
        powerSaveEnabled: true
        heartbeat: {
          counter: 1
        }
      }
      """

  Scenario: Harness reinit calls set_safety_mode and set_power_save_state
    Given exists data:
      """
      ControlSetup: {
        sbu1VoltageMV: 700,
        sbu2VoltageMV: 200
      }
      """
    When detect harness orientation
    And call tick handler 1 times
    Then control data should be:
      """
      : {
        powerSaveEnabled: false
        heartbeat: {
          counter: 1
        }
      }
      """

  # ---- register divergence (check_registers) ----
  # check_registers() runs at 1Hz (every 8 tick_handler calls). It compares
  # shadow register values against actual hardware register reads.
  # If any masked bit differs, FAULT_REGISTER_DIVERGENT (bit 18 = 262144)
  # is raised. The e2e test injects divergence via jna_set_register_divergent().

  Scenario: Non-divergent registers do not trigger a fault
    Given exists data:
      """
      ControlSetup: {
        registerDivergent: 0
      }
      """
    When call tick handler 8 times
    Then control data should be:
      """
      : {
        readFaults: 0
      }
      """

  Scenario: Divergent register triggers FAULT_REGISTER_DIVERGENT
    Given exists data:
      """
      ControlSetup: {
        registerDivergent: 1
      }
      """
    When call tick handler 8 times
    Then control data should be:
      """
      : {
        readFaults: 262144
      }
      """

  Scenario: Register divergence fault persists after register is fixed
    Given exists data:
      """
      ControlSetup: {
        registerDivergent: 1
      }
      """
    When call tick handler 8 times
    Given exists data:
      """
      ControlSetup: {
        registerDivergent: 0
      }
      """
    When call tick handler 8 times
    Then control data should be:
      """
      : {
        readFaults: 262144
      }
      """

  # ---- heartbeat loop watchdog (simple_watchdog_kick) ----
  # tick_handler (8Hz) calls simple_watchdog_kick() on every invocation.
  # The watchdog fires FAULT_HEARTBEAT_LOOP_WATCHDOG (bit 26 = 67108864)
  # if the microsecond timer interval between kicks exceeds 375ms.
  # Each scenario gets a fresh dylib load so wd_state is zeroed.

  Scenario: Normal tick rate within threshold does not trigger watchdog
    When tick handler
    Given exists data:
      """
      ControlSetup: {
        timerValue: 200000
      }
      """
    When tick handler
    Then control data should be:
      """
      : {
        readFaults: 0
      }
      """

  Scenario: Slow tick rate exceeding threshold triggers watchdog fault
    When tick handler
    Given exists data:
      """
      ControlSetup: {
        timerValue: 400000
      }
      """
    When tick handler
    Then control data should be:
      """
      : {
        readFaults: 67108864
      }
      """

  Scenario: Watchdog fault persists after tick rate recovers
    When tick handler
    Given exists data:
      """
      ControlSetup: {
        timerValue: 400000
      }
      """
    When tick handler
    Given exists data:
      """
      ControlSetup: {
        timerValue: 500000
      }
      """
    When tick handler
    Then control data should be:
      """
      : {
        readFaults: 67108864
      }
      """
