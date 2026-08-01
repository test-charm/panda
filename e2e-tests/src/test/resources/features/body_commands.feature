# language: en
@body
Feature: Body Firmware Motor Commands

  Scenario: Setting left motor speed to 100 rpm and right motor speed to 200 rpm
    When body control write:
      """
      BodyUsbControlRequest: {
        request: -77
        param1: 100
        param2: 200
      }
      """
    Then body control data should be:
      """
      : {
        rpmLeft: 100
        rpmRight: 200
      }
      """

  Scenario: Motors are disabled at start
    Then body control data should be:
      """
      : {
        motorEnabled: false
      }
      """

  Scenario: Enabling motors via command 0xb4
    When body control write:
      """
      BodyUsbControlRequest: {
        request: -76
        param1: 1
      }
      """
    Then body control data should be:
      """
      : {
        motorEnabled: true
      }
      """

  Scenario: Disabling motors via command 0xb4
    When body control write:
      """
      SetMotorEnable: {
        param1: 1
      }
      """
    And body control write:
      """
      SetMotorEnable: {
        param1: 0
      }
      """
    Then body control data should be:
      """
      : {
        motorEnabled: false
      }
      """

  Scenario: Disabling motors resets speeds to zero
    When body control write:
      """
      SetMotorEnable: {
        param1: 1
      }
      """
    And body control write:
      """
      SetMotorSpeed: {
        param1: 50
        param2: -30
      }
      """
    And body control write:
      """
      SetMotorEnable: {
        param1: 0
      }
      """
    Then body control data should be:
      """
      : {
        rpmLeft: 0
        rpmRight: 0
        motorEnabled: false
      }
      """
