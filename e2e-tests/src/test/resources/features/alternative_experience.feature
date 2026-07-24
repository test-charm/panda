# language: en
Feature: Alternative Experience Mode

  Scenario: Setting alternative experience in non-car safety mode (SILENT)
    When control write:
      """
      UsbControlRequest: {
        request: -33y
        param1: 1
        param2: 0
      }
      """
    Then control data should be:
      """
      : {
        alternativeExperience: 1
      }
      """

  Scenario: Setting alternative experience is blocked in car safety mode (TOYOTA)
    Given exists data:
      """
      SetSafetyMode: {
        param1: 2
      }
      """
    When control write:
      """
      SetAlternativeExperience: {
        param1: 99
      }
      """
    Then control data should be:
      """
      : {
        alternativeExperience: 0
      }
      """

  Scenario: Previous value preserved when blocked in car safety mode
    Given exists data:
      """
      ControlSetup: {
        alternativeExperience: 42
        safetyMode: 2
      }
      """
    When control write:
      """
      SetAlternativeExperience: {
        param1: 99
      }
      """
    Then control data should be:
      """
      : {
        alternativeExperience: 42
      }
      """

  Scenario: Boundary value param1=0 in non-car safety mode
    When control write:
      """
      SetAlternativeExperience: {
        param1: 0
      }
      """
    Then control data should be:
      """
      : {
        alternativeExperience: 0
      }
      """

  Scenario: Boundary value param1=32767 (max positive short) in non-car safety mode
    When control write:
      """
      SetAlternativeExperience: {
        param1: 32767
      }
      """
    Then control data should be:
      """
      : {
        alternativeExperience: 32767
      }
      """
