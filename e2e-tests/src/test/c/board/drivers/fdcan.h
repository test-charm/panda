// Stub: overrides board/drivers/fdcan.h
// update_can_health_pkt() now comes from real board/drivers/can_health_pkt.h (B4)
#include <stdint.h>
#include <stdbool.h>
void can_clear_send(FDCAN_GlobalTypeDef *FDCANx, uint8_t can_number);
#include "board/drivers/can_health_pkt.h"
bool can_init(uint8_t can_number);
void can_rx(uint8_t can_number);
void process_can(uint8_t can_number);
