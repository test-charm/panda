# language: en
Feature: Interrupt Call Rate Retrieval

  Scenario: Get interrupt rate returns zero-length response for out-of-range index
    When control write:
      """
      UsbControlRequest: {
        request: -60y            # 0xc4
        param1: 16
        param2: 0
      }
      """
    Then control data should be:
      """
      : {
        respBuffer: {
          len: 0
        }
      }
      """

  Scenario: Get interrupt rate returns 4-byte LE value for valid index with preset rate
    Given exists data:
      """
      ControlSetup: {
        interruptIndex: 7
        interruptCallRate: 0x12345678
      }
      """
    When control write:
      """
      GetInterruptRate: {
        param1: 7
      }
      """
    Then control data should be:
      """
      : {
        respBuffer= {
          len: 4
          bytes[0]: 0x78
          bytes[1]: 0x56
          bytes[2]: 0x34
          bytes[3]: 0x12
        }
      }
      """

  Scenario: Get interrupt rate returns all zero bytes for zero call rate
    Given exists data:
      """
      ControlSetup: {
        interruptIndex: 0
        interruptCallRate: 0
      }
      """
    When control write:
      """
      GetInterruptRate: {
        param1: 0
      }
      """
    Then control data should be:
      """
      : {
        respBuffer= {
          len: 4
          bytes[0]: 0y
          bytes[1]: 0y
          bytes[2]: 0y
          bytes[3]: 0y
        }
      }
      """
