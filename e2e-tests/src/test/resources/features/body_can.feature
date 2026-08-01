# language: en
@body
Feature: Body Firmware CAN

  Scenario: B14 — body CAN send helpers queue expected frames on bus 0
    When body can send motor speeds: left = 300, right = 150
    And body can send var values: ignition = true, enable = true, fault = 5, left err = 7, right err = 9
    And body can send body data: temp = 42, voltage = 4660, percentage = 80, charging = true
    Then body control data should be:
      """
      rxQueue: | address | bus | returned | data |
               | 513     | 0   | true     | [0x01, 0x2C, -1, 0x6A, 0x00, 0x00, 0x00, 0x00] |
               | 514     | 0   | true     | [0x17, 0x07, 0x09] |
               | 515     | 0   | true     | [0x2A, 0x12, 0x34, -95] |
      """

  Scenario: B15 — body_can_rx parses motor targets from CAN frame
    When body can set microsecond timer: 54321
    And body can receive target: left = 123 rpm, right = -45 rpm
    Then body control data should be:
      """
      : {
        rpmLeft: 123
        rpmRight: -45
        bodyCan.lastCanCmdTimestampUs: 54321
      }
      """

  Scenario: B16 — body_can_periodic resets stale motor targets after timeout
    When body can set microsecond timer: 1000
    And body can receive target: left = 100 rpm, right = 50 rpm
    And body can periodic: now_us = 101000, ignition = true, charging = false
    Then body control data should be:
      """
      : {
        rpmLeft: 0
        rpmRight: 0
        bodyCan.lastCanCmdTimestampUs: 0
      }
      """

  Scenario: B17 — body_can_periodic sends at most once every 10 ms
    When body can periodic: now_us = 10000, ignition = true, charging = true
    Then body control data should be:
      """
      rxQueue: | address | returned | data |
               | 513     | true     | [0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00] |
               | 514     | true     | [0x01, 0x00, 0x00] |
               | 515     | true     | [0x00, 0x00, 0x00, 0x01] |
               | 546     | true     | [0x01] |
      """
    When body can periodic: now_us = 15000, ignition = true, charging = true
    Then body control data should be:
      """
      rxQueue: []
      """
    When body can periodic: now_us = 20000, ignition = true, charging = true
    Then body control data should be:
      """
      rxQueue: | address | returned | data |
             0 | 513     | true     | [0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00] |
             3 | 546     | true     | [0x01] |
      """
