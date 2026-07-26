// Stub: overrides board/stm32h7/lladc.h for host (e2e) compilation.
// Intercepts adc_get_mV() calls for harness SBU signals, returning pre-set
// voltage values from harness.sbu*_voltage_mV instead of reading real ADC registers.
#pragma once

#include <stdint.h>
#include <stdbool.h>

#ifndef ADC_SIGNAL_T_DEFINED
#define ADC_SIGNAL_T_DEFINED

// adc_signal_t must match production lladc_declarations.h
typedef enum {
  SAMPLETIME_1_CYCLE = 0,
  SAMPLETIME_2_CYCLES = 1,
  SAMPLETIME_8_CYCLES = 2,
  SAMPLETIME_16_CYCLES = 3,
  SAMPLETIME_32_CYCLES = 4,
  SAMPLETIME_64_CYCLES = 5,
  SAMPLETIME_387_CYCLES = 6,
  SAMPLETIME_810_CYCLES = 7
} adc_sample_time_t;

typedef enum {
  OVERSAMPLING_1 = 0,
  OVERSAMPLING_2 = 1,
  OVERSAMPLING_4 = 2,
  OVERSAMPLING_8 = 3,
  OVERSAMPLING_16 = 4,
  OVERSAMPLING_32 = 5,
  OVERSAMPLING_64 = 6,
  OVERSAMPLING_128 = 7,
  OVERSAMPLING_256 = 8,
  OVERSAMPLING_512 = 9,
  OVERSAMPLING_1024 = 10
} adc_oversampling_t;

typedef struct {
  void *adc;                // ADC_TypeDef* — opaque in e2e
  uint8_t channel;
  adc_sample_time_t sample_time;
  adc_oversampling_t oversampling;
} adc_signal_t;

#define ADC_CHANNEL_DEFAULT(a, c) {.adc = (a), .channel = (c), .sample_time = SAMPLETIME_32_CYCLES, .oversampling = OVERSAMPLING_64}

#endif // ADC_SIGNAL_T_DEFINED

// ADC registers — stubbed for host compilation
// (ADC1 is defined in libpanda.c, no need to redefine here)

// ---- Stubbed ADC functions ----
// adc_get_mV intercepts harness SBU reads and returns pre-set voltages.
// All other ADC reads return 0 (which is fine — only harness orientation uses ADC in e2e).
extern struct harness_t harness;

static uint16_t adc_get_mV(const adc_signal_t *signal) {
  // Intercept harness SBU1 / SBU2 reads by channel number
  if (signal->channel == 4U) {
    return harness.sbu1_voltage_mV;
  }
  if (signal->channel == 17U) {
    return harness.sbu2_voltage_mV;
  }
  return 0U;
}
