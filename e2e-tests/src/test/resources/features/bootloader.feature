# language: en
Feature: Bootloader Mode Entry

  Scenario: Enter bootloader mode with param1 equals 0 triggers NVIC reset and sets bootloader magic
    When control write:
      """
      UsbControlRequest: {
        request: -47y            # 0xd1
        param1: 0
        param2: 0
      }
      """
    Then control data should be:
      """
      : {
        nvicResetCount: 1
        enterBootloaderMode: 1
      }
      """

  Scenario: Enter softloader mode with param1 equals 1 triggers NVIC reset and sets softloader magic
    When control write:
      """
      EnterBootloader: {
        param1: 1
      }
      """
    Then control data should be:
      """
      : {
        nvicResetCount: 1
        enterBootloaderMode: 2
      }
      """

  Scenario: Invalid param1 value does not trigger reset or change bootloader mode
    When control write:
      """
      EnterBootloader: {
        param1: 2
      }
      """
    Then control data should be:
      """
      : {
        nvicResetCount: 0
        enterBootloaderMode: 0
      }
      """
