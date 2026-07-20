# language: en
Feature: Health Packet Retrieval

  Scenario: SILENT mode health packet shows default values
    Given control write:
      """
      UsbControlRequest: {
        request: -46y
        param1: 0
        param2: 0
      }
      """
    Then control data should be:
      """
      : {
        healthPacket= {
          safetyMode: 0
          safetyTxBlocked: 0
          safetyRxInvalid: 0
          heartbeatLost: 0
          safetyParam: 0
          voltage: 12000
          current: 0
          uptime: 0
        }
      }
      """

  Scenario: Health packet reflects safety mode change to TOYOTA
    Given control write:
      """
      SetSafetyMode: {
        param1: 2
      }
      """
    When control write "GetHealth":
      """
      {
        param1: 0
      }
      """
    Then control data should be:
      """
      : {
        healthPacket= {
          safetyMode: 2
          safetyParam: 0
          heartbeatLost: 0
        }
      }
      """

  Scenario: Health packet reflects blocked CAN TX count
    Given control write:
      """
      GetHealth: {
        param1: 0
      }
      """
    When can send with result 1:
      """
      PowerTrainBusBlockedRequest: {
        data: blocked
      }
      """
    When control write "GetHealth":
      """
      {
        param1: 0
      }
      """
    Then control data should be:
      """
      : {
        healthPacket= {
          safetyMode: 0
          safetyTxBlocked: 1
          safetyRxInvalid: 0
          heartbeatLost: 0
        }
      }
      """
