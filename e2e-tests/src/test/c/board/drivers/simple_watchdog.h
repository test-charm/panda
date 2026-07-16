// Stub: overrides board/drivers/simple_watchdog.h
// Signature must match real board/drivers/drivers.h
#include <stdint.h>
void simple_watchdog_init(uint32_t fault, uint32_t threshold);
void simple_watchdog_kick(void);
