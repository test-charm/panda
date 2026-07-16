// Stub: overrides board/drivers/fdcan.h
// Only provides declarations needed by main.c that don't depend on STM32 HAL.
#include <stdint.h>
#include <stdbool.h>
#define CANIF_FROM_CAN_NUM(n) (n)
void can_clear_send(uint32_t can_if, uint8_t bus);
bool can_init(uint8_t can_number);
void can_rx(uint8_t can_number);
void process_can(uint8_t can_number);
void update_can_health_pkt(uint8_t can_number);
