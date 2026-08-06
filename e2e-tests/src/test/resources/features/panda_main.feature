# language: en
@cuatro
Feature: Panda Firmware Main Init Coverage

  # setUp → jna_panda_init, then panda_main() runs real init + do-while(false) loop

  Scenario: B22-PANDA-INIT — main() verifies fault free, FPU enabled, harness IDLE
    When panda main is executed
    Then control data should be:
      """
      : {
        faultStatus: 0
        fpuEnabled: 15728640
        harnessStatus: 0
      }
      """

  Scenario: B22-PANDA-FADE — main() with power_save=false exercises LED fade loop
    When set power save enabled to false
    And panda main is executed
    Then control data should be:
      """
      : {
        faultStatus: 0
      }
      """

  Scenario: B22-PANDA-WFI — main() with power_save=true + SOM online runs __WFI path
    When set power save enabled to true
    And set SOM GPIO to true
    And panda main is executed
    Then control data should be:
      """
      : {
        stopModeRegs: {
          wfiEntered: true
        }
      }
      """

  Scenario: B22-PANDA-STOP — stop_mode_requested=true enters stop mode, NVIC resets
    When set stop mode requested to true
    And panda main is executed
    Then control data should be:
      """
      : {
        nvicResetCount: 1
      }
      """

  Scenario: B22-PANDA-DEEPSLEEP — SOM offline enters deep sleep: assert passes + stop mode
    When set power save enabled to true
    And set SOM GPIO to false
    And panda main is executed
    Then control data should be:
      """
      : {
        nvicResetCount: 1
      }
      """
