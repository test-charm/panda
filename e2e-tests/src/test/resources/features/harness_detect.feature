# language: en
Feature: Harness orientation detection

  harness_detect_orientation() (production code from board/drivers/harness.h:52-88)
  reads SBU ADC voltages via adc_get_mV() (intercepted by e2e lladc.h stub)
  and classifies the harness orientation:
  - HARNESS_STATUS_NORMAL (1): SBU1 >= SBU2, at least one below threshold
  - HARNESS_STATUS_FLIPPED (2): SBU1 < SBU2, at least one below threshold
  - HARNESS_STATUS_NC (0): both voltages >= threshold (no harness connected)

  Detection threshold = avdd_mV / 2 = 900 mV (cuatro/tres) or 1650 mV (red).
  When relay_driven is true, detection is skipped and status is preserved.

  Scenario: Normal orientation — both SBU voltages below threshold, SBU1 > SBU2
    Given exists data:
      """
      ControlSetup: {
        sbu1VoltageMV: 700,
        sbu2VoltageMV: 200
      }
      """
    When detect harness orientation
    Then control data should be:
      """
      harnessStatus: 1
      """

  Scenario: Flipped orientation — both SBU voltages below threshold, SBU1 < SBU2
    Given exists data:
      """
      ControlSetup: {
        sbu1VoltageMV: 200,
        sbu2VoltageMV: 700
      }
      """
    When detect harness orientation
    Then control data should be:
      """
      harnessStatus: 2
      """

  Scenario: No harness — both SBU voltages above threshold
    Given exists data:
      """
      ControlSetup: {
        sbu1VoltageMV: 1500,
        sbu2VoltageMV: 1500
      }
      """
    When detect harness orientation
    Then control data should be:
      """
      harnessStatus: 0
      """

  Scenario: Single-side low voltage — SBU1 below threshold, SBU2 above (flipped)
    Given exists data:
      """
      ControlSetup: {
        sbu1VoltageMV: 200,
        sbu2VoltageMV: 1500
      }
      """
    When detect harness orientation
    Then control data should be:
      """
      harnessStatus: 2
      """

  Scenario: Single-side low voltage — SBU1 above threshold, SBU2 below (normal)
    Given exists data:
      """
      ControlSetup: {
        sbu1VoltageMV: 1500,
        sbu2VoltageMV: 200
      }
      """
    When detect harness orientation
    Then control data should be:
      """
      harnessStatus: 1
      """

  Scenario: Equal voltages below threshold defaults to normal
    Given exists data:
      """
      ControlSetup: {
        sbu1VoltageMV: 500,
        sbu2VoltageMV: 500
      }
      """
    When detect harness orientation
    Then control data should be:
      """
      harnessStatus: 1
      """

  Scenario: Relay driven — detection is skipped, status preserved as NC
    Given exists data:
      """
      ControlSetup: {
        harnessStatus: 0,
        sbu1VoltageMV: 200,
        sbu2VoltageMV: 700,
        relayDriven: 1
      }
      """
    When detect harness orientation
    Then control data should be:
      """
      harnessStatus: 0
      """

  Scenario: Relay released — detection resumes and detects flipped orientation
    Given exists data:
      """
      ControlSetup: {
        harnessStatus: 0,
        sbu1VoltageMV: 200,
        sbu2VoltageMV: 700,
        relayDriven: 1
      }
      """
    When detect harness orientation
    Given exists data:
      """
      ControlSetup: {
        sbu1VoltageMV: 200,
        sbu2VoltageMV: 700,
        relayDriven: 0
      }
      """
    When detect harness orientation
    Then control data should be:
      """
      harnessStatus: 2
      """
