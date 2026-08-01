# language: en
@body
Feature: Body Firmware Shared USB Commands

  These commands are shared with the panda firmware but exercise
  board/body/main_comms.h code paths.

  Scenario: Getting hardware type via 0xc1 returns body type 0xB1
    When body control write:
      """
      BodyUsbControlRequest: {
        request: -63
        param1: 0
        param2: 0
      }
      """
    Then body control data should be:
      """
      : {
        hwType: 177
      }
      """
