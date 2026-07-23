# language: en
Feature: Deep Sleep Request

  Scenario: Requesting deep sleep sets SILENT mode, power save, and stop mode
    When control write:
      """
      UsbControlRequest: {
        request: -75y
        param1: 0
        param2: 0
      }
      """
    Then control data should be:
      """
      : {
        relayCall= {
          a: false
          b: false
        }                      # set_safety_mode(SILENT) sets relay off
        powerSaveEnabled: true # set_power_save_state(true)
        stopModeRequested: true
        powerSaveTracking: {
          irqDisableCount: 2   # disable bus 2 + bus 1
        }
      }
      """