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
        relayCall= {
          a: false
          b: false
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
        relayCall= {
          a: true
          b: false
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
        relayCall= {
          a: false
          b: true
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
        relayCall= {
          a: true
          b: true
        }
      }
      """

  Scenario: Higher bits ignored — param1=0xFF behaves as both on (bitmasked to 0b11)
    When control write:
      """
      DriveRelay: {
        param1: 255
      }
      """
    Then control data should be:
      """
      : {
        relayCall= {
          a: true
          b: true
        }
      }
      """

  Scenario: Higher bits ignored — param1=4 behaves as both off (bitmasked to 0b00)
    When control write:
      """
      DriveRelay: {
        param1: 4
      }
      """
    Then control data should be:
      """
      : {
        relayCall= {
          a: false
          b: false
        }
      }
      """
