# language: en
Feature: CAN FD Auto Switching

  Scenario: Disabling CAN FD auto switching
    When control write:
      """
      UsbControlRequest: {
        request: -24y
        param1: 0
        param2: 0
      }
      """
    Then control data should be:
      """
      : {
        canFdConfig= {
          canfdAuto0: false
          canfdAuto1: false
          canfdAuto2: false
        }
      }
      """

  Scenario: Enabling CAN FD auto switching on bus 0
    When control write:
      """
      SetCanFdAuto: {
        param1: 0
        param2: 1
      }
      """
    Then control data should be:
      """
      : {
        canFdConfig= {
          canfdAuto0: true
          canfdAuto1: false
          canfdAuto2: false
        }
      }
      """

  Scenario: Any non-zero param2 enables CAN FD auto switching
    When control write:
      """
      SetCanFdAuto: {
        param1: 1
        param2: 255
      }
      """
    Then control data should be:
      """
      : {
        canFdConfig= {
          canfdAuto1: true
        }
      }
      """