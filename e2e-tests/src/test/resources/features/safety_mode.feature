# language: en
Feature: Safety Mode Switching (via USB control handler)

  Scenario: NOOUTPUT mode blocks CAN TX through safety pipeline
    Given control write:
      """
      {
        request: -36y
        param1: 0     # SILENT
        param2: 0
      }
      """
    When can send with result 1:
      """
      {
        address: 256
        bus: 0y
        data: blocked
      }
      """
    Then control data should be:
      """
      : {
        safetyTxBlocked: 1
        popRxQueue= {      # 这个好像有个test-charm的bug，就是写了=但是字段不完整的情况下，验证依然通过
          address: 256
          bus: 0y
          rejected: true
          data.string: blocked
        }
        popTxQueue[0]: null
      }
      """

  Scenario: ALLOUTPUT mode allows all CAN TX through safety pipeline
    Given control write "SetSafetyMode":
      """
      param1: 17     # ALLOUTPUT
      """
    When can send with result 0:
      """
      {
        address: 256
        bus: 0y
        data: allowed
      }
      """
    Then control data should be:
      """
      : {
        safetyTxBlocked: 0
        popRxQueue: null
        popTxQueue[0]= {
          address: 256
          bus: 0y
          rejected: false
          data.string: allowed
        }
      }
      """

  Scenario: ELM327 mode allows valid OBD-II CAN TX through safety pipeline
    Given control write "SetSafetyMode":
      """
      param1: 3     # ELM327
      param2: 1
      """
    When can send with result 0:
      """
      {
        address: 2015
        bus: 0y
        data: '12345678'
      }
      """
    Then control data should be:
      """
      : {
        safetyTxBlocked: 0
        popRxQueue: null
        popTxQueue[0]= {
          address: 2015
          bus: 0y
          rejected: false
          data.string: '12345678'
        }
      }
      """

