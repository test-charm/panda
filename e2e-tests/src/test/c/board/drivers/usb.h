// Stub: overrides board/drivers/usb.h for host compilation
#pragma once
#include <stdint.h>
#include <stdbool.h>
void usb_irqhandler(void) {}
void usb_init(void) {}
#define USBPACKET_MAX_SIZE 0x40U
