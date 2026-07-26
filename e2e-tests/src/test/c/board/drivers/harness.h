// Stub: overrides board/drivers/harness.h
#pragma once
#include <stdint.h>
#include <stdbool.h>

// Forward-declare harness_t for lladc.h
struct harness_t {
    uint8_t status;
    bool sbu_adc_lock;
    bool relay_driven;
    bool ignition_triggered;
    uint16_t sbu1_voltage_mV;
    uint16_t sbu2_voltage_mV;
};

#include "board/stm32h7/lladc.h"        // adc_signal_t, ADC_CHANNEL_DEFAULT

#define HARNESS_STATUS_NC 0
#define HARNESS_STATUS_NORMAL 1
#define HARNESS_STATUS_FLIPPED 2



struct harness_configuration {
    GPIO_TypeDef *GPIO_SBU1;
    GPIO_TypeDef *GPIO_SBU2;
    GPIO_TypeDef *GPIO_relay_SBU1;
    GPIO_TypeDef *GPIO_relay_SBU2;
    uint8_t pin_SBU1;
    uint8_t pin_SBU2;
    uint8_t pin_relay_SBU1;
    uint8_t pin_relay_SBU2;
    const adc_signal_t adc_signal_SBU1;
    const adc_signal_t adc_signal_SBU2;
};
typedef struct harness_configuration harness_configuration;

extern struct harness_t harness;

void set_intercept_relay(bool intercept, bool ignition_relay);
void harness_init(void);
void harness_tick(void);
bool harness_check_ignition(void);
// harness_detect_orientation() is defined as static in harness_detect_e2e.gen.c
// (extracted verbatim from production board/drivers/harness.h:52-88)
