# language: en
Feature: Register Divergence Detection (check_registers)

  check_registers() runs at 1Hz (every 8 tick_handler calls). It compares
  shadow register values (written via register_set) against actual hardware
  register reads. If any bit in check_mask differs, FAULT_REGISTER_DIVERGENT
  (bit 18 = 262144) is raised.

  The e2e test injects directly into register_map via jna_set_register_divergent()
  because the e2e register_set stub bypasses the shadow map.

  Scenario: Non-divergent registers do not trigger a fault
    Given exists data:
      """
      ControlSetup: {
        registerDivergent: 0
      }
      """
    When call tick handler 8 times
    Then control data should be:
      """
      : {
        readFaults: 0
      }
      """

  Scenario: Divergent register triggers FAULT_REGISTER_DIVERGENT
    Given exists data:
      """
      ControlSetup: {
        registerDivergent: 1
      }
      """
    When call tick handler 8 times
    Then control data should be:
      """
      : {
        readFaults: 262144
      }
      """

  Scenario: Register divergence fault persists after register is fixed
    Given exists data:
      """
      ControlSetup: {
        registerDivergent: 1
      }
      """
    When call tick handler 8 times
    Given exists data:
      """
      ControlSetup: {
        registerDivergent: 0
      }
      """
    When call tick handler 8 times
    Then control data should be:
      """
      : {
        readFaults: 262144
      }
      """
