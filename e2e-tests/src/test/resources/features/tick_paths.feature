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
