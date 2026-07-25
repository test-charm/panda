// Override for host e2e testing — extends board/fake_stm.h
// with extra TIM_TypeDef fields needed by board/main.c (SR for tick handler).
// Path priority: -I src/test/c is searched before -I board/
#pragma once

#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>

#include "utils.h"

#define ALLOW_DEBUG

#define ENTER_CRITICAL()
#define EXIT_CRITICAL()

void print(const char *a) { printf("%s", a); }
void puth(unsigned int i) { printf("%u", i); }

typedef struct {
  uint32_t CNT;
  uint32_t SR;  // needed by main.c tick_handler: TICK_TIMER->SR
} TIM_TypeDef;

TIM_TypeDef timer;
TIM_TypeDef *MICROSECOND_TIMER = &timer;
uint32_t microsecond_timer_get(void);

uint32_t microsecond_timer_get(void) {
  return MICROSECOND_TIMER->CNT;
}

// Real GPIO_TypeDef matching STM32H7 field offsets (for board/drivers/gpio.h)
typedef struct {
  volatile uint32_t MODER;      // 0x00
  volatile uint32_t OTYPER;     // 0x04
  volatile uint32_t OSPEEDR;    // 0x08
  volatile uint32_t PUPDR;      // 0x0C
  volatile uint32_t IDR;        // 0x10
  volatile uint32_t ODR;        // 0x14
  volatile uint32_t BSRR;       // 0x18
  volatile uint32_t LCKR;       // 0x1C
  volatile uint32_t AFR[2];     // 0x20-0x24
} GPIO_TypeDef;

// ---- STM32H7 timer register bit macros (needed by clock_source.h / fan.h) ----
#define TIM_CCER_CC1E       (1U << 0)
#define TIM_CCER_CC2NE      (1U << 2)
#define TIM_CCER_CC3NE      (1U << 4)
#define TIM_DIER_UIE        (1U << 0)
#define TIM_DIER_CC1IE      (1U << 1)
#define TIM_BDTR_MOE        (1U << 15)
#define TIM_SMCR_MSM        (1U << 16)
#define TIM_SMCR_SMS_Pos    0U
#define TIM_SMCR_TS_Pos     4U
#define TIM_CR2_MMS_Pos     4U
#define TIM_CR1_CEN         (1U << 0)
#define TIM_CCMR1_OC1M_Pos  4U
#define TIM_CCMR1_OC2M_Pos  12U
#define TIM_CCMR2_OC3M_Pos  4U
#define TIM_CCMR2_OC4M_Pos  12U

// ---- STM32H7 IRQ numbers (any value OK — NVIC_DisableIRQ is no-op) ----
#define TIM1_UP_TIM10_IRQn  25
#define TIM1_CC_IRQn        27

// ---- GPIO alternate function constants ----
#define GPIO_AF1_TIM1       1U
#define GPIO_AF3_TIM8       3U

// ---- APB2 timer frequency (200 MHz for STM32H725) ----
#define APB2_TIMER_FREQ     200000000U
