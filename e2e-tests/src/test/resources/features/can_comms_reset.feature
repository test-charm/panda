# language: en
Feature: CAN Communications Reset

  Scenario: Resetting from clean state zeros all comms buffers
    When control write:
      """
      UsbControlRequest: {
        request: -64y
        param1: 0
        param2: 0
      }
      """
    Then control data should be:
      """
      : {
        canCommsBuffers= {
          readBufferPtr: 0
          readBufferTail: 0
          writeBufferPtr: 0
          writeBufferTail: 0
        }
      }
      """

  Scenario: Reset does not affect safety mode or relay state
    Given exists data:
      """
      SetSafetyMode: {
        param1: 0
      }
      """
    When control write:
      """
      ResetCanComms: {
        param1: 0
      }
      """
    Then control data should be:
      """
      : {
        safetyTxBlocked: 0
        stopModeRegs: {
          gpioAOdr: 520L
        }
        rxQueue: []
        txQueue[0]: []
      }
      """

  Scenario: Reset preserves ALLOUTPUT safety mode relay state
    Given exists data:
      """
      SetSafetyMode: {
        param1: 17
      }
      """
    When control write:
      """
      ResetCanComms: {
        param1: 0
      }
      """
    Then control data should be:
      """
      : {
        stopModeRegs: {
          gpioAOdr: 512L
        }
      }
      """
