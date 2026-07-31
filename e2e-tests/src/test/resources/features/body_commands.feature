Feature: Body firmware USB commands

  The body firmware (board/body/main.c) exposes USB control commands for
  motor control. This feature tests the two uncovered commands: 0xb3 (set
  motor speeds) and 0xb4 (enable/disable motors).

  Background:
    Given the body firmware is initialized

  @body
  Scenario: Set motor speed via command 0xb3
    When I set left motor speed to 100 rpm and right motor speed to 200 rpm
    Then the left motor target rpm should be 100
    And the right motor target rpm should be 200

  @body
  Scenario: Motors are disabled by default
    Then the motors should be disabled

  @body
  Scenario: Enable motors via command 0xb4
    When I enable the motors
    Then the motors should be enabled

  @body
  Scenario: Disable motors via command 0xb4
    Given the motors are enabled
    When I disable the motors
    Then the motors should be disabled

  @body
  Scenario: Disabling motors resets speeds to zero
    Given the motors are enabled
    And the left motor speed is set to 50 rpm and right motor speed is set to -30 rpm
    When I disable the motors
    Then the left motor target rpm should be 0
    And the right motor target rpm should be 0
