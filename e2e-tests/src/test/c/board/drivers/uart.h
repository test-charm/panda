// Stub: overrides board/drivers/uart.h — provides uart_ring type
// Matching board/drivers/drivers.h definition for host compilation.
#pragma once
#include <stdint.h>
#include <stdbool.h>

typedef struct uart_ring {
    volatile uint32_t w_ptr_tx;
    volatile uint32_t r_ptr_tx;
    uint32_t tx_fifo_size;
    volatile uint32_t w_ptr_rx;
    volatile uint32_t r_ptr_rx;
    uint32_t rx_fifo_size;
    uint8_t *elems_tx;
    uint8_t *elems_rx;
    void *uart;
    void (*callback)(struct uart_ring *);
    bool overwrite;
} uart_ring;

bool get_char(uart_ring *q, char *elem);
int put_char(uart_ring *q, char elem);
