# language: en
Feature: Heartbeat Loss Automatic Behavior

When openpilot stops sending heartbeats, the firmware revokes controls_allowed
after 3 mismatches, then after a grace period of 2–5 seconds enters SILENT
safety mode with power save, siren, IR off, and fan control.

The full tick_handler() runs at 8Hz; the 1Hz block fires every 8th call.
Use 8 × N calls to advance N seconds of heartbeat timeout.

  Background:
    Given exists data:
      """
      ControlSetup: {
        safetyMode: 2
        controlsAllowed: 1
      }
      """

  Scenario: controls_allowed revoked after 3 heartbeat_engaged mismatches
    When call tick handler 24 times
    Then control data should be:
      """
      safetyState: {
        controlsAllowed: 0
      }
      """

  Scenario: Heartbeat timeout triggers SILENT mode and power save (ignition off, 2s)
    When call tick handler 16 times
    Then control data should be:
      """
      : {
        safetyState: {
          safetyMode: 0
        }
        powerSaveEnabled: true
        heartbeat: {
          lost: 1
        }
      }
      """

  Scenario: Heartbeat timeout triggers SILENT mode and power save (ignition on, 5s)
    Given exists data:
      """
      ControlSetup: {
        ignitionLine: 1
      }
      """
    When call tick handler 40 times
    Then control data should be:
      """
      : {
        safetyState: {
          safetyMode: 0
        }
        powerSaveEnabled: true
        heartbeat: {
          lost: 1
        }
      }
      """

  Scenario: Siren triggers on heartbeat timeout when controls_allowed was recently active
    Given exists data:
      """
      ControlSetup: {
        ignitionLine: 1
      }
      """
    When call tick handler 40 times
    Then control data should be:
      """
      safetyState: {
        sirenWasActive: 1
      }
      """

  Scenario: Siren does not trigger after controls_allowed_countdown expires
    # Without controls_allowed, countdown is not reset and expires after 5 ticks.
    # Then heartbeat timeout fires with countdown == 0 → no siren.
    Given exists data:
      """
      ControlSetup: {
        controlsAllowed: 0
        ignitionLine: 1
      }
      """
    When call tick handler 80 times
    Then control data should be:
      """
      : {
        safetyState: {
          sirenWasActive: 0
          safetyMode: 0
        }
      }
      """

  Scenario: IR power set to 0 on heartbeat loss
    Given exists data:
      """
      ControlSetup: {
        ignitionLine: 1
      }
      """
    When call tick handler 40 times
    Then control data should be:
      """
      powerSaveTracking: {
        irPowerValue: 0
      }
      """

  Scenario: Fan power reflects SOM GPIO high on heartbeat loss
    Given exists data:
      """
      ControlSetup: {
        ignitionLine: 1
        somGpio: 1
      }
      """
    When call tick handler 40 times
    Then control data should be:
      """
      fanPower: 30
      """

  Scenario: Fan power is 0 when SOM GPIO low on heartbeat loss
    Given exists data:
      """
      ControlSetup: {
        ignitionLine: 1
      }
      """
    When call tick handler 40 times
    Then control data should be:
      """
      fanPower: 0
      """

  Scenario: heartbeat_disabled prevents timeout transition to SILENT
    Given exists data:
      """
      ControlSetup: {
        safetyMode: 17
        heartbeatDisabled: 1
        ignitionLine: 1
      }
      """
    When call tick handler 48 times
    Then control data should be:
      """
      : {
        safetyState: {
          safetyMode: 17
        }
        powerSaveEnabled: false
        heartbeat: {
          lost: 0
        }
      }
      """
