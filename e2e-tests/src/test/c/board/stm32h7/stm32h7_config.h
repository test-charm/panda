// Stub: Minimal CMSIS definitions for host compilation.
#pragma once
#include <stdint.h>
#include "board/comms_definitions.h"   // ControlPacket_t needed by main_comms.h

typedef struct {
    uint32_t RESERVED0[0x0C / 4];
    uint32_t AR[0x0C/4];  // placeholder
    uint32_t AIRCR;
    uint32_t SCR;
    uint32_t RESERVED1[(0x88 - 0x14) / 4];
    uint32_t CPACR;
} SCB_TypeDef;

#define SCB ((SCB_TypeDef *) 0xE000ED00UL)
extern TIM_TypeDef *TICK_TIMER;
