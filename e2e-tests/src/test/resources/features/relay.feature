# language: en
Feature: Intercept Relay Control

  Scenario: Both relays off with param1=0
    When control write:
      """
      UsbControlRequest: {
        request: -59y
        param1: 0
        param2: 0
      }
      """
    Then control data should be:
      """
      : {
        stopModeRegs: {
          gpioAOdr: 520L    # PA3+PA9 both high (active-low, so relays OFF)
        }
      }
      """

  Scenario: Relay A on with param1=1
    When control write:
      """
      DriveRelay: {
        param1: 1
      }
      """
    Then control data should be:
      """
      : {
        stopModeRegs: {
          gpioAOdr: 512L    # PA3=low(A on), PA9=high(B off)
        }
      }
      """

  Scenario: Relay B on with param1=2
    When control write:
      """
      DriveRelay: {
        param1: 2
      }
      """
    Then control data should be:
      """
      : {
        stopModeRegs: {
          gpioAOdr: 8L      # PA3=high(A off), PA9=low(B on)
        }
      }
      """

  Scenario: Both relays on with param1=3
    When control write:
      """
      DriveRelay: {
        param1: 3
      }
      """
    Then control data should be:
      """
      : {
        stopModeRegs: {
          gpioAOdr: 0L      # PA3+PA9 both low (both ON)
        }
      }
      """

  Scenario: Higher bits ignored — param1=0xFF behaves as both on
    When control write:
      """
      DriveRelay: {
        param1: 255
      }
      """
    Then control data should be:
      """
      : {
        stopModeRegs: {
          gpioAOdr: 0L
        }
      }
      """

  Scenario: Higher bits ignored — param1=4 behaves as both off
    When control write:
      """
      DriveRelay: {
        param1: 4
      }
      """
    Then control data should be:
      """
      : {
        stopModeRegs: {
          gpioAOdr: 520L
        }
      }
      """
