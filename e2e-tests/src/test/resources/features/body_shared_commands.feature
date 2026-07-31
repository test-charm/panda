Feature: Body firmware shared USB commands

  The body firmware shares several USB control commands with the panda firmware.
  These commands are implemented in board/body/main_comms.h and exercise
  body-specific code paths.

  Background:
    Given the body firmware is initialized

  @body
  Scenario: Get hardware type via command 0xc1
    When I send control command 193 to body
    Then the response length should be 1
    And response byte 0 should be 177

  @body
  Scenario: Get firmware version via command 0xd6
    When I send control command 214 to body
    Then the response should be a non-empty string

  @body
  Scenario: Get packet version hashes via command 0xdd
    When I send control command 221 to body
    Then the response length should be 8
    And the health packet version hash should be 3801956342
    And the CAN packet version hash should be 1995615093
