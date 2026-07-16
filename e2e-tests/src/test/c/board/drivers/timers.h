// Stub: overrides board/drivers/timers.h
#pragma once
#include <stdint.h>

void tick_timer_init(void);
void microsecond_timer_init(void);
uint32_t microsecond_timer_get(void);
void interrupt_timer_init(void);
