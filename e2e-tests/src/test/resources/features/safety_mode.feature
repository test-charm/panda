# language: en
Feature: Safety Mode Switching

  Scenario: Set SILENT mode and verify health reflects it
    When I set safety mode to "SILENT"
    Then the safety_mode in health should be 0

  Scenario: Set NOOUTPUT mode and verify health reflects it
    When I set safety mode to "NOOUTPUT"
    Then the safety_mode in health should be 19

  Scenario: Set ELM327 mode with default param and verify health
    When I set safety mode to "ELM327"
    Then the safety_mode in health should be 3

  Scenario: Set ALLOUTPUT mode and verify health reflects it
    When I set safety mode to "ALLOUTPUT"
    Then the safety_mode in health should be 17

  Scenario: Set ELM327 mode with param=1 and verify health
    When I set safety mode to "ELM327" with param 1
    Then the safety_mode in health should be 3

  Scenario: SILENT mode blocks CAN transmission
    When I set safety mode to "SILENT"
    And I enable CAN loopback
    And I send a CAN message with address 426 and data "message" on bus 0
    And I wait 50 milliseconds
    When I receive CAN messages
    Then no CAN message should appear on bus 0
    And exactly 1 CAN message should appear on bus 192

  Scenario: Invalid mode falls back to SILENT
    When I set an invalid safety mode 65535
    Then the safety_mode in health should be 0
