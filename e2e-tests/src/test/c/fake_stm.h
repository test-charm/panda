// Override for host e2e testing — extends board/fake_stm.h
// with extra TIM_TypeDef fields needed by board/main.c (SR for tick handler).
// Path priority: -I src/test/c is searched before -I board/
#pragma once

#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>

#include "utils.h"

#define ALLOW_DEBUG

#define ENTER_CRITICAL() 0
#define EXIT_CRITICAL() 0

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
