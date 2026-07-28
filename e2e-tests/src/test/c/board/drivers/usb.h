// E2E USB endpoint simulation for CAN data path testing.
//
// Real hardware paths:
//   host USB OUT ep3 → usb_irqhandler() → USB_ReadPacket → comms_can_write()
//   host USB IN  ep1 ← usb_irqhandler() ← USB_WritePacket ← comms_can_read()
//
// This module provides usb_sim_ep3_out() / usb_sim_ep1_in() that invoke
// the same comms_can_write() / comms_can_read() code paths through USB
// endpoint simulation, without the full STM32 USB OTG HAL.

#pragma once
#include <stdint.h>

#define USBPACKET_MAX_SIZE 0x40U

// usb_init, usb_irqhandler are declared in drivers.h and stubbed in libpanda.c.
// can_tx_comms_resume_usb is in drivers.h and stubbed in libpanda.c.

// ---- USB endpoint simulation API (for JNA) ----

// Simulate host sending CAN data to endpoint 3 OUT.
void usb_sim_ep3_out(const uint8_t *data, uint32_t len) {
    if ((data != ((void *)0)) && (len > 0U) && (len <= 0x100U)) {
        comms_can_write(data, len);
    }
}

static uint8_t _usb_sim_ep1_buf[0x40];
static int _usb_sim_ep1_len;

// Simulate host reading CAN data from endpoint 1 IN.
int usb_sim_ep1_in(uint8_t *out_data, uint32_t max_len) {
    _usb_sim_ep1_len = comms_can_read(_usb_sim_ep1_buf,
        (max_len < 0x40U) ? max_len : 0x40U);
    if ((out_data != ((void *)0)) && (_usb_sim_ep1_len > 0)) {
        for (int i = 0; i < _usb_sim_ep1_len; i++) {
            out_data[i] = _usb_sim_ep1_buf[i];
        }
    }
    return _usb_sim_ep1_len;
}

int usb_sim_ep1_in_get_len(void) { return _usb_sim_ep1_len; }

int usb_sim_ep1_in_get_byte(int index) {
    if ((index < 0) || (index >= _usb_sim_ep1_len)) return 0;
    return (int)_usb_sim_ep1_buf[index];
}
