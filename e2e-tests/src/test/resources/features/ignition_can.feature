# language: en
Feature: ignition_can auto-reset

  When CAN traffic stops for more than 2 seconds, the firmware sets ignition_can
  to false. Each 1Hz tick increments ignition_can_cnt; when it exceeds 2,
  ignition_can is cleared.

  The full tick_handler() runs at 8Hz; the 1Hz block fires every 8th call.
  Use 8 × N calls to advance N seconds.

  Background:
    Given exists data:
      """
      ControlSetup: {
        ignitionCan: 1
      }
      """

  Scenario: ignition_can auto-resets after 4 seconds without CAN traffic
    # ignition_can_cnt check happens before increment. cnt=0 → 1st tick: 0>2? no, cnt=1
    # 2nd tick: 1>2? no, cnt=2. 3rd tick: 2>2? no, cnt=3. 4th tick: 3>2? yes, ignition_can=false.
    When call tick handler 32 times
    Then control data should be:
      """
      ignitionCan: 0
      """

  Scenario: ignition_can stays true within 3 seconds of CAN traffic stop
    # After 3 1Hz ticks (24 calls): ignition_can_cnt = 3, but check 2>2 failed on 3rd tick
    When call tick handler 24 times
    Then control data should be:
      """
      ignitionCan: 1
      """
