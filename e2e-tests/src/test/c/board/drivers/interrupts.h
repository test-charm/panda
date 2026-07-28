// Real REGISTER_INTERRUPT macro (C3: matches board/drivers/drivers.h)
// Now populates interrupts[] array so e2e tests can verify registered handlers.
#pragma once
#include <stdint.h>

#include <stdbool.h>

typedef int IRQn_Type;

typedef struct interrupt {
  IRQn_Type irq_type;
  void (*handler)(void);
  uint32_t call_counter;
  uint32_t call_rate;
  uint32_t max_call_rate;
  uint32_t call_rate_fault;
} interrupt;

void init_interrupts(bool enable);

#define REGISTER_INTERRUPT(irq_num, func_ptr, call_rate_max, rate_fault) \
  interrupts[irq_num].irq_type = (irq_num); \
  interrupts[irq_num].handler = (func_ptr);  \
  interrupts[irq_num].call_counter = 0U;   \
  interrupts[irq_num].call_rate = 0U;   \
  interrupts[irq_num].max_call_rate = (call_rate_max); \
  interrupts[irq_num].call_rate_fault = (rate_fault);

#define TICK_TIMER_IRQ 0
