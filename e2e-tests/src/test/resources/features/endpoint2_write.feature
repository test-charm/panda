# language: en
Feature: SPI Endpoint 2 Bulk Write (comms_endpoint2_write)

  Scenario: Endpoint 2 write with ring 0 stores data in debug UART buffer
    When endpoint2 write with hex:
      """
      00 48 45 4C 4C 4F
      """
    Then control data should be:
      """
      : {
        endpoint2WriteResult: {
          len: 5
          bytes[0]: 0x48    # 'H'
          bytes[1]: 0x45    # 'E'
          bytes[2]: 0x4C    # 'L'
          bytes[3]: 0x4C    # 'L'
          bytes[4]: 0x4F    # 'O'
        }
      }
      """

  Scenario: Endpoint 2 write with only ring selector writes nothing
    When endpoint2 write with hex:
      """
      00
      """
    Then control data should be:
      """
      : {
        endpoint2WriteResult: {
          len: 0
        }
      }
      """

  Scenario: Endpoint 2 write with invalid ring 1 writes nothing
    When endpoint2 write with hex:
      """
      01 41 42 43
      """
    Then control data should be:
      """
      : {
        endpoint2WriteResult: {
          len: 0
        }
      }
      """

  Scenario: Endpoint 2 write with ring 2 filtered by get_ring_by_number writes nothing
    When endpoint2 write with hex:
      """
      02 58 59 5A
      """
    Then control data should be:
      """
      : {
        endpoint2WriteResult: {
          len: 0
        }
      }
      """

  Scenario: Endpoint 2 write with ring 3 filtered by get_ring_by_number writes nothing
    When endpoint2 write with hex:
      """
      03 50 51 52
      """
    Then control data should be:
      """
      : {
        endpoint2WriteResult: {
          len: 0
        }
      }
      """

  Scenario: Endpoint 2 write with ring 4 stores data in SOM debug UART buffer
    When endpoint2 write with hex:
      """
      04 53 4F 4D
      """
    Then control data should be:
      """
      : {
        endpoint2WriteResult: {
          len: 3
          bytes[0]: 0x53    # 'S'
          bytes[1]: 0x4F    # 'O'
          bytes[2]: 0x4D    # 'M'
        }
      }
      """
