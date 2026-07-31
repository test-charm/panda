# language: en
Feature: Body Firmware Shared USB Commands

  These commands are shared with the panda firmware but exercise
  board/body/main_comms.h code paths.

  @body
  Scenario: Getting hardware type via 0xc1 returns body type 0xB1
    When body control write:
      """
      GetHwType
      """
    Then body control data should be:
      """
      : {
        hwType: 177
      }
      """
