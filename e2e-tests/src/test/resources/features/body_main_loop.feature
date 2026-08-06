# language: en
@body
Feature: Body Firmware Main Loop Branch Coverage

  Background:
    # setUp → jna_panda_init() → body_main() runs one loop iteration at timer=0
    # (plug_charging=false, ignition=false → green breathe at scale=0)

  Scenario: B22-INIT — body_main() init verifies led_init, timer init, and default loop outputs
    # Verifies real production code replacing no-op stubs:
    # - tick_timer_init() → TICK_TIMER DIER/CR1 enabled, SR cleared
    # - interrupt_timer_init() → INTERRUPT_TIMER DIER/CR1 enabled, SR cleared
    # - disable/enable_interrupts() from board/sys/critical.h
    # - led_init() → GPIOA pin 10 configured as output
    # - microsecond_timer_init() → timer starts at 0
    # PSC register values depend on register_set hash table behavior;
    # verifying non-zero confirms real code ran (not no-op stub).
    Then body control data should be:
      """
      : {
        redLedMode: 1
        microsecondTimer: 0
        tickDier: 1
        tickCr1: 1
        tickSr: 0
        intTimerDier: 1
        intTimerCr1: 1
        intTimerSr: 0
        plugCharging: false
        ignition: false
        motorEnabled: false
        dotstar.initialized: true
      }
      """

  Scenario: B22-LOOP-01 — Default state: green breathe verified via pixel values
    # Set now_us to 375000 (quarter cycle of 1.5M) to get a non-zero breathe scale
    When body set plug charging state to false
    And body set ignition state to false
    And body main loop once at 375000 us
    Then body control data should be:
      """
      : {
        motorEnabled: false
        dotstar.pixel0R: 0
        dotstar.pixel0G: 127
        dotstar.pixel0B: 4
      }
      """

  Scenario: B22-LOOP-02 — Charging state: orange breathe verified via pixel values
    # Set now_us to 500000 (quarter cycle of 2M) to get non-zero orange
    When body set plug charging state to true
    And body set ignition state to false
    And body main loop once at 500000 us
    Then body control data should be:
      """
      : {
        plugCharging: true
        ignition: false
        motorEnabled: false
        dotstar.pixel0R: 127
        dotstar.pixel0G: 19
        dotstar.pixel0B: 0
      }
      """

  Scenario: B22-LOOP-03 — Ignition state: rainbow verified via pixel values
    # Set now_us to 0 for deterministic rainbow colors
    When body set plug charging state to false
    And body set ignition state to true
    And body main loop once at 0 us
    Then body control data should be:
      """
      : {
        plugCharging: false
        ignition: true
        motorEnabled: true
        dotstar.pixel0R: 255
        dotstar.pixel0G: 0
        dotstar.pixel0B: 0
        dotstar.pixel3R: 45
        dotstar.pixel3G: 210
        dotstar.pixel3B: 0
      }
      """

  Scenario: B22-LOOP-04 — Charging + Ignition: orange breathe + motor on
    # plug_charging takes priority over ignition for DotStar; both enable motor
    When body set plug charging state to true
    And body set ignition state to true
    And body main loop once at 500000 us
    Then body control data should be:
      """
      : {
        plugCharging: true
        ignition: true
        motorEnabled: true
        dotstar.pixel0R: 127
        dotstar.pixel0G: 19
        dotstar.pixel0B: 0
      }
      """
