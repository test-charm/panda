// Stub: overrides board/drivers/interrupts.h
#pragma once
#include <stdint.h>

#include <stdbool.h>

void init_interrupts(bool enable);
#define REGISTER_INTERRUPT(irq, fn, rate, fault) \
    do { (void)(irq); (void)(fn); (void)(rate); (void)(fault); } while(0);
#define TICK_TIMER_IRQ 0
