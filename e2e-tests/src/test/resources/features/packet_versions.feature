# language: en
Feature: Health and CAN Packet Version Retrieval

  Scenario: Get packet versions returns both version numbers
    When control write:
      """
      UsbControlRequest: {
        request: -35y
        param1: 0
        param2: 0
      }
      """
    Then control data should be:
      """
      : {
        packetVersions= {
          healthVersion: 0
          canVersionHash: 0
        }
      }
      """