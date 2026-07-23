# language: en
Feature: Health Packet Retrieval

  Scenario: SILENT mode health packet shows default values
    When control write:
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
    Given exists data:
      """
      SetSafetyMode: {
        param1: 2
      }
      """
    When control write:
      """
      GetHealth: {
        param1: 0
      }
      """
    Then control data should be:
      """
      : {
        healthPacket: {
          safetyMode: 2
          safetyParam: 0
          heartbeatLost: 0
        }
      }
      """

  Scenario: Health packet reflects blocked CAN TX count
    Given exists data:
      """
      GetHealth: {
        param1: 0
      }
      PowerTrainBusBlockedRequest: {
        data: blocked
      }
      """
    When control write:
      """
      GetHealth: {
        param1: 0
      }
      """
    Then control data should be:
      """
      : {
        healthPacket: {
          safetyMode: 0
          safetyTxBlocked: 1
          safetyRxInvalid: 0
          heartbeatLost: 0
        }
      }
      """

  Scenario: Health packet voltage reflects settable e2e value
    Given exists data:
      """
      ControlSetup: {
        voltageMV: 13500
      }
      """
    When control write:
      """
      GetHealth: {
        param1: 0
      }
      """
    Then control data should be:
      """
      : {
        healthPacket: {
          voltage: 13500
        }
      }
      """

  Scenario: Health packet current reflects settable e2e value
    Given exists data:
      """
      ControlSetup: {
        currentMA: 500
      }
      """
    When control write:
      """
      GetHealth: {
        param1: 0
      }
      """
    Then control data should be:
      """
      : {
        healthPacket: {
          current: 500
        }
      }
      """
