# language: en
Feature: Microsecond Timer and Fan RPM

  Scenario: Get microsecond timer returns timer value in resp buffer
    Given exists data:
      """
      TimerSetup: {
        timerValue: 0x12345678
      }
      """
    When control write:
      """
      UsbControlRequest: {
        request: -88y
        param1: 0
        param2: 0
      }
      """
    Then control data should be:
      """
      : {
        respBuffer= {
          len: 4
          bytes: [ 0b0111_1000, 0b0101_0110, 0b0011_0100, 0b0001_0010 ]   # little-endian: 0x78, 0x56, 0x34, 0x12
        }
      }
      """

  Scenario: Get fan RPM returns fan_state.rpm in resp buffer
    Given exists data:
      """
      TimerSetup: {
        fanRpm: 4660   # 0x1234
      }
      """
    When control write:
      """
      UsbControlRequest: {
        request: -78y
        param1: 0
        param2: 0
      }
      """
    Then control data should be:
      """
      : {
        respBuffer= {
          len: 2
          bytes: [ 0b0011_0100, 0b0001_0010 ]   # little-endian: 0x34, 0x12
        }
      }
      """