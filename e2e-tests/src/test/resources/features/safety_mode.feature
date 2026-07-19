# language: en
Feature: Safety Mode Switching (via USB control handler)

  Scenario: Set SILENT mode and verify health reflects it
    When control write:
      """
      {
          request: -36y
          param1: 0     # SILENT
          param2: 0
      }
      """
    Then control read "request: -36y, param1: 0, param2: 0" should:
      """
      getResponseByte[36]: 0
      """

  Scenario: Set NOOUTPUT mode and verify health reflects it
    When control write "SetSafetyMode":
      """
      param1: 19     # NOOUTPUT
      """
    Then the safety_mode in health should be 19

  Scenario: Set ELM327 mode with default param and verify health
    When control write "SetSafetyMode":
      """
      param1: 3     # ELM327
      """
    Then the safety_mode in health should be 3

  Scenario: Set ALLOUTPUT mode and verify health reflects it
    When control write "SetSafetyMode":
      """
      param1: 17     # ALLOUTPUT
      """
    Then the safety_mode in health should be 17

  Scenario: Set ELM327 mode with param=1 and verify health
    When control write "SetSafetyMode":
      """
      param1: 3     # ELM327
      param2: 1
      """
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

  # ---- CAN pipeline verification: real can_send → safety_tx_hook → can_push ----

  Scenario: NOOUTPUT mode blocks CAN TX through safety pipeline
    When I set safety mode to "NOOUTPUT"
    And I send CAN through safety pipeline with address 256 and data "blocked" on bus 0
    Then the CAN pipeline message should be blocked
    And safety_tx_blocked counter should increase by 1
    And the rejected CAN message should appear in rx queue with address 256 and bus 0
    And the tx queue for bus 0 should be empty

  Scenario: ALLOUTPUT mode allows all CAN TX through safety pipeline
    When I set safety mode to "ALLOUTPUT"
    And I send CAN through safety pipeline with address 256 and data "allowed" on bus 0
    Then the CAN pipeline message should be allowed
    And the tx queue for bus 0 should contain a message with address 256
    And the rx queue should be empty

  Scenario: ELM327 mode allows valid OBD-II CAN TX through safety pipeline
    When I set safety mode to "ELM327"
    And I send CAN through safety pipeline with address 2015 and data "12345678" on bus 0
    Then the CAN pipeline message should be allowed
    And the tx queue for bus 0 should contain a message with address 2015
