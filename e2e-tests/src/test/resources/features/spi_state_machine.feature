# language: en
Feature: SPI State Machine (Phase F.5)

  # State enum: HEADER=0, HEADER_ACK=1, HEADER_NACK=2, DATA_RX=3, DATA_RX_ACK=4, DATA_TX=5

  # ============================================================
  # spi_rx_done: Header processing
  # ============================================================

  Scenario: Valid sync byte and valid checksum → ACK (HEADER_ACK)
    # checksum = 0xAB ^ 0x5A ^ 0xAB ^ 0x00 ^ 0x00 ^ 0x04 ^ 0x00 = 0x5E
    When spi operates:
      """
      SpiControlRequest: {
        state: 0
        rxBufOffset: 0
        rxBufHex: '5A AB 00 00 04 00 5E'
        txDone: false
      }
      """
    Then control data should be:
      """
      : {
        spiStateResult: {
          state: 1
          rx: {
            ack: true
            txLen: 1
          }
          errorCount: 0
        }
      }
      """

  Scenario: Invalid sync byte → NACK (HEADER_NACK)
    When spi operates:
      """
      SpiProcessHeader: {
        rxBufHex: '00 01 00 00 00 00 00'
      }
      """
    Then control data should be:
      """
      : {
        spiStateResult: {
          state: 2
          rx.ack: false
          errorCount: 1
        }
      }
      """

  Scenario: Valid sync but invalid checksum → NACK (HEADER_NACK)
    When spi operates:
      """
      SpiProcessHeader: {
        rxBufHex: '5A 01 00 00 00 00 00'
      }
      """
    Then control data should be:
      """
      : {
        spiStateResult: {
          state: 2
          rx.ack: false
          errorCount: 1
        }
      }
      """

  # ============================================================
  # spi_rx_done: Data processing
  # ============================================================

  Scenario: DATA_RX with invalid checksum → NACK
    When spi operates:
      """
      SpiProcessData: {
        rxDataBufOffset: 7
        rxDataBufHex: '00'
      }
      """
    Then control data should be:
      """
      : {
        spiStateResult: {
          state: 2
          rx.ack: false
          errorCount: 1
        }
      }
      """

  Scenario: DATA_RX endpoint 0xAB — test endpoint (device→panda) → DACK
    When spi operates:
      """
      SpiProcessData: {
        rxDataBufHex: AB
      }
      """
    Then control data should be:
      """
      : {
        spiStateResult: {
          state: 5
          rx: {
            ack: true
            txLen: 8
          }
        }
      }
      """

  Scenario: DATA_RX endpoint 0xAC — test NACK endpoint → NACK
    When spi operates:
      """
      SpiProcessData: {
        rxBufHex: '5A AC 00 00 00 00 5D'
        rxDataBufHex: AB
      }
      """
    Then control data should be:
      """
      : {
        spiStateResult: {
          state: 2
          rx.ack: false
        }
      }
      """

  Scenario: DATA_RX endpoint 2 — endpoint2 write → DACK
    When spi operates:
      """
      SpiProcessData: {
        rxBufHex: '5A 02 04 00 00 00 F7'
        rxDataBufHex: '41 42 43 44 AF'
      }
      """
    Then control data should be:
      """
      : {
        spiStateResult: {
          state: 5
          rx.ack: true
        }
      }
      """

  Scenario: DATA_RX endpoint 1 — CAN read → DACK
    When spi operates:
      """
      SpiProcessData: {
        rxBufHex: '5A 01 00 00 08 00 F8'
        rxDataBufHex: AB
      }
      """
    Then control data should be:
      """
      : {
        spiStateResult: {
          state: 5
          rx.ack: true
        }
      }
      """

  Scenario: DATA_RX endpoint 0x81 — CAN read → DACK
    When spi operates:
      """
      SpiProcessData: {
        rxBufHex: '5A 81 00 00 08 00 78'
        rxDataBufHex: AB
      }
      """
    Then control data should be:
      """
      : {
        spiStateResult: {
          state: 5
          rx.ack: true
        }
      }
      """

  Scenario: DATA_RX endpoint 3 — CAN write with can_tx_ready → DACK
    When spi operates:
      """
      SpiProcessData: {
        rxBufHex: '5A 03 04 00 00 00 F6'
        rxDataBufHex: '01 02 03 04 AF'
        txReady: true
      }
      """
    Then control data should be:
      """
      : {
        spiStateResult: {
          state: 5
          rx.ack: true
        }
      }
      """

  Scenario: DATA_RX endpoint 3 — CAN write with can_tx_ready=false → NACK
    When spi operates:
      """
      SpiProcessData: {
        rxBufHex: '5A 03 04 00 00 00 F6'
        rxDataBufHex: '01 02 03 04 AF'
        txReady: false
      }
      """
    Then control data should be:
      """
      : {
        spiStateResult.state: 2
        spiStateResult.rx.ack: false
      }
      """

  # ---- 额外覆盖: VERSION / Endpoint 0 / Unexpected endpoint / Unexpected state ----

  Scenario: HEADER with VERSION match — triggers spi_version_packet directly
    # Write "VERSION" (0x56 0x45 0x52 0x53 0x49 0x4F 0x4E) to rx_buf
    When spi operates:
      """
      SpiProcessHeader: {
        rxBufHex: '56 45 52 53 49 4F 4E'
      }
      """
    Then control data should be:
      """
      : {
        spiStateResult: {
          state: 2
          rx.ack: true
        }
      }
      """

  Scenario: DATA_RX endpoint 0 — valid control transfer (0xc1 get hw_type)
    # Header: sync=5A, endpoint=00, len_mosi=7(sizeof ControlPacket_t), len_miso=0
    # checksum = 0xAB ^ 0x5A ^ 0x00 ^ 0x07 ^ 0x00 ^ 0x00 ^ 0x00 = 0xF6
    # ControlPacket_t: request=0xc1, param1=0, param2=0, length=0  (7 bytes)
    # data checksum = 0xAB ^ 0xC1 ^ 0x00 ^ 0x00 ^ 0x00 ^ 0x00 ^ 0x00 ^ 0x00 = 0x6A
    When spi operates:
      """
      SpiProcessData: {
        rxBufHex: '5A 00 07 00 00 00 F6'
        rxDataBufHex: 'C1 00 00 00 00 00 00 6A'
      }
      """
    Then control data should be:
      """
      : {
        spiStateResult: {
          state: 5
          rx: {
            ack: true
            txLen: 5
          }
        }
      }
      """

  Scenario: DATA_RX endpoint 0 — insufficient data for control handler
    # Header: endpoint=00, len_mosi=3 (< sizeof(ControlPacket_t)=7)
    # checksum = 0xAB ^ 0x5A ^ 0x00 ^ 0x03 ^ 0x00 ^ 0x00 ^ 0x00 = 0xF2
    # data=AA BB CC + checksum = 0xAB ^ 0xAA ^ 0xBB ^ 0xCC = 0x76
    When spi operates:
      """
      SpiProcessData: {
        rxBufHex: '5A 00 03 00 00 00 F2'
        rxDataBufHex: 'AA BB CC 76'
      }
      """
    Then control data should be:
      """
      : {
        spiStateResult: {
          state: 2
          rx.ack: false
        }
      }
      """

  Scenario: DATA_RX unexpected endpoint → print + NACK
    # Header: endpoint=0xFF, len_mosi=0, len_miso=0
    # checksum = 0xAB ^ 0x5A ^ 0xFF = 0x0E
    # 1 checksum byte: 0xAB
    When spi operates:
      """
      SpiProcessData: {
        rxBufHex: '5A FF 00 00 00 00 0E'
        rxDataBufHex: AB
      }
      """
    Then control data should be:
      """
      : {
        spiStateResult.state: 2
        spiStateResult.rx.ack: false
      }
      """

  Scenario: spi_rx_done unexpected state → print + no response fallback
    # Set state to HEADER_ACK(1), don't write VERSION → falls into else (unexpected)
    # Write some non-VERSION data so memcmp fails
    When spi operates:
      """
      SpiProcessHeader: {
        state: 1
        rxBufHex: '00 00 00 00 00 00 00'
      }
      """
    Then control data should be:
      """
      : {
        spiStateResult: {
          state: 2
          rx: {
            ack: false
            txLen: 1
          }
        }
      }
      """

  # ============================================================
  # spi_tx_done: State transitions
  # ============================================================

  Scenario: spi_tx_done from HEADER_NACK → HEADER
    When spi operates:
      """
      SpiProcessHeader: {
        rxBufHex: '00 01 00 00 00 00 00'
      }
      """
    When spi tx done
    Then control data should be:
      """
      : {
        spiStateResult.state: 0
      }
      """

  Scenario: spi_tx_done from HEADER_ACK → DATA_RX
    When spi operates:
      """
      SpiProcessHeader: {
        rxBufHex: '5A AB 00 00 04 00 5E'
      }
      """
    When spi tx done
    Then control data should be:
      """
      : {
        spiStateResult.state: 3
      }
      """

  Scenario: spi_tx_done from DATA_TX → HEADER
    When spi operates:
      """
      SpiProcessData: {
        rxBufHex: '5A AB 00 00 04 00 5E'
        rxDataBufHex: AB
      }
      """
    When spi tx done
    Then control data should be:
      """
      : {
        spiStateResult.state: 0
      }
      """

  Scenario: spi_tx_done from unexpected state → HEADER
    When spi set state 4
    When spi tx done
    Then control data should be:
      """
      : {
        spiStateResult.state: 0
      }
      """

  Scenario: spi_tx_done with reset=true from any state → HEADER
    When spi set state 5
    When spi tx done with reset
    Then control data should be:
      """
      : {
        spiStateResult.state: 0
      }
      """

  # ---- endpoint2 write ring dispatch (merged from endpoint2_write.feature) ----
  # comms_endpoint2_write() dispatches data to debug/buffer rings based on
  # the first byte (ring selector). Ring 0 → debug UART, ring 4 → SOM debug.

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

  # ---- UART read (control write 0xe0) (merged from uart_read.feature) ----
  # Tests comms_control_handler case 0xe0: reads from UART ring via
  # get_ring_by_number(param1) → get_char loop. Combined with endpoint2
  # write to form round-trip validation: write → ring buffer → read back.

  Scenario: UART read returns zero-length response for invalid ring number
    When control write:
      """
      UsbControlRequest: {
        request: -32y            # 0xe0
        param1: 99
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

  Scenario: UART read returns zero-length response for empty ring
    When control write:
      """
      UartRead: {
        param1: 0
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

  Scenario: UART read returns buffered data when ring has characters
    Given exists data:
      """
      ControlSetup: {
        uartData: "HELLO"
      }
      """
    When control write:
      """
      UartRead: {
        param1: 0
        length: 5
      }
      """
    Then control data should be:
      """
      : {
        respBuffer= {
          len: 5
          bytes[0]: 72y    # 'H'
          bytes[1]: 69y    # 'E'
          bytes[2]: 76y    # 'L'
          bytes[3]: 76y    # 'L'
          bytes[4]: 79y    # 'O'
        }
      }
      """
