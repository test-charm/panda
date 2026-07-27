# language: en
Feature: CAN Queue Pointer Wrap-around

  Test can_common.h queue pointer wrap-around logic (r_ptr wrap in can_pop,
  w_ptr wrap in can_push, push-full rejection, can_slots_empty with w_ptr < r_ptr).
  Uses direct queue state manipulation via JNA to reach edge conditions without
  pushing/poping thousands of messages.

  Background:
    Given exists data:
      """
      ControlSetup: {
        hwType: 3
        safetyMode: 17
        heartbeatDisabled: 1
      }
      """

  Scenario: r_ptr wraps to 0 when can_pop reads last element
    Given exists data:
      """
      CanQueue: | queueNum | w_ptr | r_ptr |
                | 1        | 1     | 415   |
      """
    When can push direct to queue 1
    And can pop direct from queue 1
    Then control data should be:
      """
      : {
        lastQueueWPtr: 2
        lastQueueRPtr: 0
      }
      """

  Scenario: w_ptr wraps to 0 (next_w_ptr) when can_push at end of queue
    Given exists data:
      """
      CanQueue: | queueNum | w_ptr | r_ptr |
                | 1        | 415   | 1     |
      """
    When can push direct to queue 1
    Then control data should be:
      """
      : {
        lastQueueWPtr: 0
        lastQueueRPtr: 1
      }
      """

  Scenario: can_push fails when queue is full (w_ptr at end, r_ptr at 0)
    Given exists data:
      """
      CanQueue: | queueNum | w_ptr | r_ptr |
                | 1        | 415   | 0     |
      """
    When can push direct to queue 1
    Then control data should be:
      """
      : {
        lastQueueWPtr: 415
        lastQueueRPtr: 0
        canPushResult: false
      }
      """

  Scenario: can_slots_empty returns correct count when w_ptr < r_ptr (wrap)
    Given exists data:
      """
      CanQueue: | queueNum | w_ptr | r_ptr |
                | 1        | 100   | 200   |
      """
    When refresh can slots empty for queue 1
    Then control data should be:
      """
      : {
        lastCanSlotsEmptyVal: 99
      }
      """

  Scenario: can_slots_empty with w_ptr >= r_ptr (non-wrap) for regression
    Given exists data:
      """
      CanQueue: | queueNum | w_ptr | r_ptr |
                | 1        | 200   | 100   |
      """
    When refresh can slots empty for queue 1
    Then control data should be:
      """
      : {
        lastCanSlotsEmptyVal: 315
      }
      """
