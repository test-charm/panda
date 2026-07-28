// Include real registers.h for check_registers() testing, but include sys.h first for deps.
// After jna_panda_init(), init_registers() clears tracked entries to avoid false positives
// from init-time register_set calls.
// Stub: Minimal CMSIS definitions for host compilation.
#pragma once
#include <stdint.h>
#include "board/comms_definitions.h"   // ControlPacket_t needed by main_comms.h
#include "board/sys/sys.h"             // FAULT_REGISTER_DIVERGENT, fault_occurred decl
#include "board/drivers/registers.h"   // real register_set / check_registers
#include "board/drivers/spi.h"         // real spi.h via e2e wrapper (llspi stubs)

#define CAN_INTERRUPT_RATE 16000U

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
