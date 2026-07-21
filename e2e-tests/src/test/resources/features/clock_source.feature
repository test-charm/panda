# language: en
Feature: Custom Clock Source Configuration

  Scenario: Setting clock source writes correct TIM register values
    When control write:
      """
      UsbControlRequest: {
        request: -26y
        param1: 100
        param2: 50
      }
      """
    Then control data should be:
      """
      : {
        clockSource= {
          ccr1: 0        # ((100 & 0xFF00) >> 8) * 10
          ccr2: 1000     # (100 & 0xFF) * 10
          ccr3: 0        # ((50 & 0xFF00) >> 8) * 10
          arr: 499       # ((50 & 0xFF) * 10) - 1
          ccr4: 250      # (499 + 1) / 2
        }
      }
      """

  Scenario: Setting clock source to zero produces underflow for ARR
    When control write:
      """
      SetClockSource: {
        param1: 0
        param2: 0
      }
      """
    Then control data should be:
      """
      : {
        clockSource= {
          ccr1: 0
          ccr2: 0
          ccr3: 0
          arr: 65535     # ((0 & 0xFF) * 10) - 1, masked to 0xFFFF
          ccr4: 32768    # (65535 + 1) / 2
        }
      }
      """

  Scenario: Setting clock source with max values splits correctly
    When control write:
      """
      UsbControlRequest: {
        request: -26y
        param1: 32767
        param2: 32767
      }
      """
    Then control data should be:
      """
      : {
        clockSource= {
          ccr1: 1270     # ((0x7FFF & 0xFF00) >> 8) * 10 = 127 * 10
          ccr2: 2550     # (0x7FFF & 0xFF) * 10 = 255 * 10
          ccr3: 1270     # same as ccr1
          arr: 2549      # (255 * 10) - 1
          ccr4: 1275     # (2549 + 1) / 2
        }
      }
      """