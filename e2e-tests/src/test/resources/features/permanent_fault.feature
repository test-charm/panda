# language: en
Feature: Permanent Fault Handling

  fault_occurred() on a permanent fault sets fault_status = FAULT_STATUS_PERMANENT.
  fault_recovered() on a permanent fault prints "Cannot recover" and does NOT clear
  the fault bit. The e2e build overrides PERMANENT_FAULTS to include
  FAULT_UNUSED_INTERRUPT_HANDLED (bit 1 = 2) for testing.

  Background:
    Given exists data:
      """
      ControlSetup: {
        safetyMode: 2
      }
      """

  Scenario: Permanent fault sets fault_status to PERMANENT and cannot be recovered
    When trigger fault 2
    Then control data should be:
      """
      : {
        faultStatus: 2
        readFaults: 2
      }
      """
    When recover fault 2
    Then control data should be:
      """
      : {
        readFaults: 2
      }
      """

  Scenario: Triggering the same permanent fault again is idempotent
    When trigger fault 2
    When trigger fault 2
    Then control data should be:
      """
      : {
        faultStatus: 2
        readFaults: 2
      }
      """
