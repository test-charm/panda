// Stub: overrides board/drivers/fdcan.h
#include <stdint.h>
#include <stdbool.h>
void can_clear_send(FDCAN_GlobalTypeDef *FDCANx, uint8_t can_number);
bool can_init(uint8_t can_number);
void can_rx(uint8_t can_number);
void process_can(uint8_t can_number);
void update_can_health_pkt(uint8_t can_number, uint32_t ir_reg);
