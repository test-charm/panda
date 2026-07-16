// Stub: Minimal CMSIS definitions for host compilation.
#pragma once
#include <stdint.h>

typedef struct {
    uint32_t RESERVED[0x0C / 4];
    uint32_t RESERVED0[0x0C / 4];
    uint32_t AIRCR;
    uint32_t SCR;
    uint32_t RESERVED1[(0x88 - 0x14) / 4];
    uint32_t CPACR;
} SCB_TypeDef;

#define SCB ((SCB_TypeDef *) 0xE000ED00UL)

// Timer pointer — declared extern, initialized in panda_safety.c
extern TIM_TypeDef *TICK_TIMER;
