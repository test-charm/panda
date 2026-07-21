# language: en
Feature: Firmware Version Retrieval

# language: en
Feature: Firmware Version Retrieval

  Scenario: Get version returns git commit hash in resp buffer
    Given exists data:
      """
      ControlSetup: {
        gitversion: abcdef01
      }
      """
    When control write:
      """
      UsbControlRequest: {
        request: -42y
        param1: 0
        param2: 0
      }
      """
    Then control data should be:
      """
      : {
        respBuffer= {
          len: 63    # sizeof(gitversion) - 1
          bytes[0]: 97y    # 'a'
          bytes[1]: 98y    # 'b'
          bytes[2]: 99y    # 'c'
          bytes[3]: 100y   # 'd'
          bytes[4]: 101y   # 'e'
          bytes[5]: 102y   # 'f'
          bytes[6]: 48y    # '0'
          bytes[7]: 49y    # '1'
        }
      }
      """