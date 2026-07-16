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

typedef uint32_t GPIO_TypeDef;
