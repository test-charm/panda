# language: en
Feature: Heartbeat Loop Watchdog (simple_watchdog_kick)

  The tick_handler (8Hz) calls simple_watchdog_kick() on every invocation.
  The watchdog fires FAULT_HEARTBEAT_LOOP_WATCHDOG (bit 26) if the
  interval between kicks exceeds 375ms (threshold = 3,000,000 / 8).

  In the e2e environment, the microsecond timer is controlled via `timerValue`
  in ControlSetup. Each scenario starts with a fresh dylib load,
  so all static state (wd_state, faults) is zeroed.

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
