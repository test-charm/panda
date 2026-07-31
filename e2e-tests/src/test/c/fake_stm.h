// Override for host e2e testing — extends board/fake_stm.h
// with extra TIM_TypeDef fields needed by board/main.c (SR for tick handler).
// Path priority: -I src/test/c is searched before -I board/
//
// This file provides ALL types, macros, and stubs that real production headers
// (interrupts.h, timers.h, uart.h) need but normally get from STM32 CMSIS/HAL.
// With these in place, the real headers can be included directly — no e2e wrappers needed.
#pragma once

#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <stdbool.h>

#include "utils.h"

#define ALLOW_DEBUG

#define ENTER_CRITICAL()
#define EXIT_CRITICAL()

// ---- NVIC stubs (overridden later in libpanda.c for tracking) ----
#define NVIC_EnableIRQ(x)  ((void)(x))
#define NVIC_DisableIRQ(x) ((void)(x))
#define NVIC_ClearPendingIRQ(x) ((void)(x))

// =============================================================================
//  interrupts.h dependencies
// =============================================================================
// These normally come from drivers.h (#ifdef STM32H7 section) and stm32h7_config.h.

typedef int IRQn_Type;

typedef struct interrupt {
  IRQn_Type irq_type;
  void (*handler)(void);
  uint32_t call_counter;
  uint32_t call_rate;
  uint32_t max_call_rate;
  uint32_t call_rate_fault;
} interrupt;

#define REGISTER_INTERRUPT(irq_num, func_ptr, call_rate_max, rate_fault) \
  interrupts[irq_num].irq_type = (irq_num); \
  interrupts[irq_num].handler = (func_ptr);  \
  interrupts[irq_num].call_counter = 0U;   \
  interrupts[irq_num].call_rate = 0U;   \
  interrupts[irq_num].max_call_rate = (call_rate_max); \
  interrupts[irq_num].call_rate_fault = (rate_fault);

#define TICK_TIMER_IRQ 0

// Forward declarations for functions defined in timers.h (included later)
uint32_t microsecond_timer_get(void);
void interrupt_timer_init(void);

// =============================================================================
//  timers.h dependencies
// =============================================================================

#define INTERRUPT_TIMER_IRQ 54   // TIM6_DAC_IRQn

// enable_interrupt_timer() — real impl in board/stm32h7/peripherals.h:
//   register_set_bits(&(RCC->APB1LENR), RCC_APB1LENR_TIM6EN)
static inline void enable_interrupt_timer(void) {}

// =============================================================================
//  uart.h dependencies
// =============================================================================
// uart_ring type matching board/drivers/drivers.h, but void* instead of USART_TypeDef*.

typedef struct uart_ring {
    volatile uint16_t w_ptr_tx;
    volatile uint16_t r_ptr_tx;
    uint8_t *elems_tx;
    uint32_t tx_fifo_size;
    volatile uint16_t w_ptr_rx;
    volatile uint16_t r_ptr_rx;
    uint8_t *elems_rx;
    uint32_t rx_fifo_size;
    void *uart;
    void (*callback)(struct uart_ring *);
    bool overwrite;
} uart_ring;

// Stub for uart_tx_ring — real impl in board/stm32h7/lluart.h, not available in e2e.
static inline void uart_tx_ring(struct uart_ring *q) { (void)q; }

// Forward declarations — definitions come from board/main.c (debug_ring_callback)
// and libpanda.c (uart_ring_debug, uart_ring_som_debug).
void debug_ring_callback(uart_ring *ring);
extern uart_ring uart_ring_debug;
extern uart_ring uart_ring_som_debug;

// Shims for STM32 HAL USART peripheral macros referenced in real uart.h.
#define USART2  ((void*)0)
#define UART7   ((void*)1)
#define FIFO_SIZE_INT 0x400U

// Forward declarations for uart functions — real implementations from board/drivers/uart.h.
void print(const char *a);
void puth(unsigned int i);

// =============================================================================
//  Timer + GPIO hardware types
// =============================================================================

typedef struct {
  uint32_t CR1;     // 0x00
  uint32_t CR2;     // 0x04
  uint32_t SMCR;    // 0x08
  uint32_t DIER;    // 0x0C
  uint32_t SR;      // 0x10 — needed by main.c tick_handler: TICK_TIMER->SR
  uint32_t EGR;     // 0x14
  uint32_t CCMR1;   // 0x18
  uint32_t CCMR2;   // 0x1C
  uint32_t CCER;    // 0x20
  uint32_t CNT;     // 0x24
  uint32_t PSC;     // 0x28
  uint32_t ARR;     // 0x2C
  uint32_t RCR;     // 0x30 — Repetition Counter (needed by body BLDC)
  uint32_t CCR1;    // 0x34
  uint32_t CCR2;    // 0x38
  uint32_t CCR3;    // 0x3C
  uint32_t CCR4;    // 0x40
  uint32_t _pad2[3];// 0x44-0x4C
  uint32_t BDTR;    // 0x50
} TIM_TypeDef;

TIM_TypeDef timer;
TIM_TypeDef *MICROSECOND_TIMER = &timer;

// INTERRUPT_TIMER (TIM6) — needed by real interrupts.h for interrupt_timer_handler()
TIM_TypeDef interrupt_timer_inst;
TIM_TypeDef *INTERRUPT_TIMER = &interrupt_timer_inst;

// microsecond_timer_get() is now provided by real board/drivers/timers.h

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

// ---- STM32H7 timer register bit macros (needed by clock_source.h / fan.h / pwm.h) ----
#define TIM_CCER_CC1E       (1U << 0)
#define TIM_CCER_CC2E       (1U << 4)
#define TIM_CCER_CC3E       (1U << 8)
#define TIM_CCER_CC4E       (1U << 12)
#define TIM_CCER_CC1NE      (1U << 2)   // body BLDC complementary output (correct bit 2)
#define TIM_CCER_CC2NE      (1U << 2)   // (unchanged from original fake_stm.h)
#define TIM_CCER_CC3NE      (1U << 4)   // (unchanged from original fake_stm.h)
#define TIM_SR_UIF          (1U << 0)   // Update interrupt flag
#define TIM_DIER_UIE        (1U << 0)
#define TIM_DIER_CC1IE      (1U << 1)
#define TIM_BDTR_MOE        (1U << 15)
#define TIM_SMCR_MSM        (1U << 16)
#define TIM_SMCR_SMS_Pos    0U
#define TIM_SMCR_TS_Pos     4U
#define TIM_CR2_MMS_Pos     4U
#define TIM_CR1_CEN         (1U << 0)
#define TIM_CR1_CMS_0       (1U << 5)   // Center-aligned mode 1 (body BLDC)
#define TIM_CR1_ARPE        (1U << 7)
#define TIM_CCMR1_OC1M_Pos  4U
#define TIM_CCMR1_OC1M_1    (1U << 5)
#define TIM_CCMR1_OC1M_2    (1U << 6)
#define TIM_CCMR1_OC1PE     (1U << 3)
#define TIM_CCMR1_OC2M_Pos  12U
#define TIM_CCMR1_OC2M_1    (1U << 13)
#define TIM_CCMR1_OC2M_2    (1U << 14)
#define TIM_CCMR1_OC2PE     (1U << 11)
#define TIM_CCMR2_OC3M_Pos  4U
#define TIM_CCMR2_OC3M_1    (1U << 5)
#define TIM_CCMR2_OC3M_2    (1U << 6)
#define TIM_CCMR2_OC3PE     (1U << 3)
#define TIM_CCMR2_OC4M_Pos  12U
#define TIM_CCMR2_OC4M_1    (1U << 13)
#define TIM_CCMR2_OC4M_2    (1U << 14)
#define TIM_CCMR2_OC4PE     (1U << 11)
#define TIM_EGR_UG          (1U << 0)

// ---- STM32H7 IRQ numbers (any value OK — NVIC_DisableIRQ is no-op) ----
#define TIM1_UP_TIM10_IRQn  25
#define TIM1_CC_IRQn        27
#define TIM8_UP_TIM13_IRQn  44   // needed by body BLDC
#define EXTI15_10_IRQn      40   // needed by body ignition/charging
#define FDCAN1_IT0_IRQn     100
#define FDCAN1_IT1_IRQn     101
#define FDCAN2_IT0_IRQn     102
#define FDCAN2_IT1_IRQn     103
#define FDCAN3_IT0_IRQn     104
#define FDCAN3_IT1_IRQn     105

// ---- GPIO alternate function constants ----
#define GPIO_AF1_TIM1       1U
#define GPIO_AF2_FDCAN3     2U
#define GPIO_AF2_TIM3       2U
#define GPIO_AF3_TIM8       3U
#define GPIO_AF3_DFSDM1     3U
#define GPIO_AF4_I2C5       4U
#define GPIO_AF5_FDCAN3     5U
#define GPIO_AF5_SPI4       5U
#define GPIO_AF7_UART7      7U
#define GPIO_AF7_USART2     7U
#define GPIO_AF8_SAI4       8U
#define GPIO_AF9_FDCAN1     9U
#define GPIO_AF9_FDCAN2     9U
#define GPIO_AF10_OTG1_FS   10U
#define GPIO_AF10_SAI4      10U

// ---- GPIO output speed register bits ----
#define GPIO_OSPEEDR_OSPEED11    (0x3UL << 22)
#define GPIO_OSPEEDR_OSPEED12    (0x3UL << 24)
#define GPIO_OSPEEDR_OSPEED13    (0x3UL << 26)
#define GPIO_OSPEEDR_OSPEED14    (0x3UL << 28)
#define GPIO_OSPEEDR_OSPEED5     (0x3UL << 10)    // body DotStar CLK/DATA pins (PB3, PB5)
#define GPIO_OSPEEDR_OSPEED5_Msk (0x3UL << 10)

// ---- PWR register bit macros (needed by tres_init) ----
#define PWR_CR3_USBREGEN         (1UL << 25)
#define PWR_CR3_USB33DEN         (1UL << 24)
#define PWR_CR3_USB33RDY         (1UL << 26)

// ---- APB2 timer frequency (200 MHz for STM32H725) ----
// APB1 is 120MHz, timer clock is 2x = 240MHz
#define CORE_FREQ           240U     // in MHz (needed by body BLDC)
#define APB1_FREQ           (CORE_FREQ/4U)
#define APB2_FREQ           (CORE_FREQ/4U)
#define APB1_TIMER_FREQ     240000000U
#define APB2_TIMER_FREQ     200000000U

// ---- llspi stubs (hardware SPI DMA, not available in e2e) ----
static inline void llspi_init(void) {}
static inline void llspi_mosi_dma(uint8_t *addr, int len) { (void)addr; (void)len; }
static inline void llspi_miso_dma(const uint8_t *addr, int len) { (void)addr; (void)len; }

// ---- hw_type extern (needed by real board/drivers/spi.h before definition) ----
extern uint8_t hw_type;

// ---- libc forward declarations (needed by real board/drivers/spi.h before board/libc.h) ----
void *memcpy(void *dest, const void *src, unsigned int len);
int memcmp(const void *ptr1, const void *ptr2, unsigned int num);
