// E2E stub: overrides board/stm32h7/board.h for host compilation.
// Includes real board headers (cuatro/red/tres) so their static functions
// are compiled directly instead of being extracted into board_stubs_e2e.gen.c.
//
// detect_board_type() is defined in libpanda.c — NOT here.
#pragma once

#include <stdint.h>
#include <stdbool.h>

// GPIO_TypeDef is defined in fake_stm.h (included before this file via libpanda.c).
// Declare extern GPIO instances — defined in libpanda.c.
extern GPIO_TypeDef e2e_GPIOA, e2e_GPIOB, e2e_GPIOC, e2e_GPIOD, e2e_GPIOE, e2e_GPIOF, e2e_GPIOG;
#define GPIOA (&e2e_GPIOA)
#define GPIOB (&e2e_GPIOB)
#define GPIOC (&e2e_GPIOC)
#define GPIOD (&e2e_GPIOD)
#define GPIOE (&e2e_GPIOE)
#define GPIOF (&e2e_GPIOF)
#define GPIOG (&e2e_GPIOG)

// ADC — defined in libpanda.c
#define ADC1 (&e2e_ADC1)
extern struct e2e_ADC_Regs e2e_ADC1;

// PWR
extern struct e2e_PWR_Regs e2e_PWR;
#define PWR (&e2e_PWR)

// GPIO OTYPE register bit macros (needed by tres_init, cuatro_init)
#define GPIO_OTYPER_OT8  (1UL << 8)
#define GPIO_OTYPER_OT10 (1UL << 10)
#define GPIO_OTYPER_OT11 (1UL << 11)

// ---- Typedefs normally from main_declarations.h ----
typedef struct board board;
extern board *current_board;

// ---- Include stubs BEFORE board headers (they provide types the boards need) ----
#include "board/stm32h7/lladc.h"        // e2e stub: adc_signal_t, adc_get_mV
#include "board/drivers/harness.h"      // e2e stub: harness_configuration, harness_t
#include "board/drivers/gpio.h"         // real: set_gpio_output, set_gpio_pullup, set_gpio_mode, set_gpio_alternate, etc.

// pwm_init/pwm_set — forward declarations matching real signatures
// (e2e pwm.h uses simplified void arg, not suitable for board init compilation)
void pwm_init(TIM_TypeDef *TIM, uint8_t channel);
void pwm_set(TIM_TypeDef *TIM, uint8_t channel, uint8_t percentage);

#include "board/boards/board_declarations.h"
#include "board/boards/unused_funcs.h"

// ---- Typedefs normally from main_declarations.h (simplified to avoid deps) ----
typedef struct board board;

// ---- Stubs for functions called by board init (never invoked at runtime) ----
void common_init_gpio(void) {}
void gpio_uart7_init(void) {}
void uart_init(void *q, int baud) { (void)q; (void)baud; }
void sound_init(void);  // defined in libpanda.c
void fake_siren_set(bool enabled);
void fake_i2c_siren_set(bool enabled);
// clock_source_init declared in board/drivers/drivers.h, no stub needed

// ---- TIM3 needed by tres_init() ----
extern TIM_TypeDef fake_TIM3;
#define TIM3 (&fake_TIM3)

// ---- Include real board headers ----
// All three must be included because:
//   - cuatro references tres_set_can_mode and red_read_voltage_mV
//   - tres references red_read_voltage_mV
// Inclusion order: red first, then tres, then cuatro (matches production).
#include "board/boards/red.h"
#include "board/boards/tres.h"
#include "board/boards/cuatro.h"
