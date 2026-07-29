# language: en
Feature: Health Packet, Version, and Packet Version Retrieval

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

  # ——— Firmware Version Retrieval (merged from get_version.feature) ———

  Scenario: Get version returns git commit hash in resp buffer
    Given exists data:
      """
      ControlSetup: {
        gitversion: abcdef01
      }
      """
    When control write:
      """
      UsbControlRequest: {
        request: -42y
        param1: 0
        param2: 0
      }
      """
    Then control data should be:
      """
      : {
        respBuffer= {
          len: 63    # sizeof(gitversion) - 1
          bytes[0]: 97y    # 'a'
          bytes[1]: 98y    # 'b'
          bytes[2]: 99y    # 'c'
          bytes[3]: 100y   # 'd'
          bytes[4]: 101y   # 'e'
          bytes[5]: 102y   # 'f'
          bytes[6]: 48y    # '0'
          bytes[7]: 49y    # '1'
        }
      }
      """

  # ——— Packet Version Retrieval (merged from packet_versions.feature) ———

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
        canInitTimeoutMs: 500
      }
      """

  Scenario: Health packet reflects safety mode change to TOYOTA
    Given exists data:
      """
      ControlSetup: {
        safetyMode: 2
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

  @red
  Scenario: GetHealth on red returns current=0 even when stub is set to non-zero
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
          current: 0
        }
      }
      """

  @tres
  Scenario: GetHealth on tres returns current=0 even when stub is set to non-zero
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
          current: 0
        }
      }
      """
