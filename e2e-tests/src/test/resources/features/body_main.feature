# language: en
@body
Feature: Body Firmware Main Interrupt Paths

  Scenario: B18 — tick_handler resets CAN0 core on transmit error and advances heartbeat state
    When body set CAN0 ILE to 0
    And body set CAN0 transmit error count to 128
    And body tick handler
    Then body control data should be:
      """
      : {
        tickCount: 1
        can0Ile: 3
        redLedOn: true
      }
      """

  Scenario: B19 — EXTI15_10 updates charging state and debounces ignition presses
    When body set charging detect to true
    And body trigger charging EXTI
    Then body control data should be:
      """
      : {
        plugCharging: true
      }
      """
    When body set microsecond timer to 250001
    And body set ignition pressed to true
    And body trigger ignition EXTI
    Then body control data should be:
      """
      : {
        ignition: true
        ignitionPressTimestampUs: 250001
        ignitionOutputOn: true
      }
      """
    When body set microsecond timer to 300000
    And body trigger ignition EXTI
    Then body control data should be:
      """
      : {
        ignition: true
        ignitionPressTimestampUs: 250001
        ignitionOutputOn: true
      }
      """

  Scenario: B20 — TIM8 update IRQ clears UIF and runs bldc_step
    When bldc skip calibration
    And set motor speeds: left = 100 rpm, right = 200 rpm, enable = true
    Then body control data should be:
      """
      : {
        leftPwmActive: false
        leftDcPhaA: 0
      }
      """
    When body trigger TIM8 update interrupt
    Then body control data should be:
      """
      : {
        leftPwmActive: true
        tim8Sr: -2
      }
      """
