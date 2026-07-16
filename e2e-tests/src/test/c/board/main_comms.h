// Stub: overrides board/main_comms.h for host compilation
#pragma once
#include <stdint.h>
void comms_control_handler(void) {}
void get_health_pkt(uint8_t *dat) { (void)dat; }
