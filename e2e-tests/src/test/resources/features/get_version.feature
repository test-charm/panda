# language: en
Feature: Firmware Version Retrieval

  Scenario: Get version returns git commit hash
    When control write:
      """
      UsbControlRequest: {
        request: -42y
        param1: 0
        param2: 0
      }
      """
    Then control data should be:
      """
      : {
        gitversion: '00000000'
      }
      """