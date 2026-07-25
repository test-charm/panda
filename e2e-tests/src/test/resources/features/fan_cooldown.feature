# language: en
@cuatro
Feature: Fan cooldown counter

  When the fan is turned off, the firmware does not cut power immediately.
  Instead, `fan_state.cooldown_counter` decrements each tick (8 Hz) from
  `fan_enable_cooldown_time * 8` down to 0. The fan stays enabled as long as
  `fan_power > 0 || cooldown_counter > 0`.

  Cuatro uses `fan_enable_cooldown_time = 3`, giving an initial
  cooldown of 24 ticks (3 seconds). Tres has the same value (3) — code paths
  are identical.

  Scenario: Fan cooldown counter resets to max when fan power is turned on
    When control write:
      """
      SetFanPower: {
        param1: 50
      }
      """
    And call tick handler 1 times
    Then control data should be:
      """
      : {
        fanCooldownCounter: 24
        fanPower: 50
      }
      """

  Scenario: Fan cooldown counter decrements each tick when fan power is off
    When control write:
      """
      SetFanPower: {
        param1: 0
      }
      """
    And call tick handler 10 times
    Then control data should be:
      """
      : {
        fanCooldownCounter: 14
        fanPower: 0
      }
      """

  Scenario: Fan cooldown counter reaches zero after full cooldown period
    When control write:
      """
      SetFanPower: {
        param1: 0
      }
      """
    And call tick handler 24 times
    Then control data should be:
      """
      : {
        fanCooldownCounter: 0
        fanPower: 0
      }
      """
