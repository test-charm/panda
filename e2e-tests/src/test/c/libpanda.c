// libpanda.c — compiles FULL board/main.c as host .dylib for JNA-based testing.
// All STM32 HAL deps are stubbed via include-path overrides + inline stubs.
// No hardware required.
//
// Build: ./build.sh
// Test:  cd .. && ./gradlew cucumber

#include "fake_stm.h"
#include "config.h"
#include <stdbool.h>

// CANPacket_t needed before opendbc safety headers
#include "opendbc/safety/can.h"

// CMSIS stubs (SCB, etc.) — config.h won't include stm32h7_config without STM32H7
#include "board/stm32h7/stm32h7_config.h"

// ---- Globals NOT defined in main.c or fake_stm.h ----
bool siren_enabled;
uint32_t siren_countdown;
TIM_TypeDef tick_timer_inst;
TIM_TypeDef *TICK_TIMER = &tick_timer_inst;
uint32_t stop_mode_requested;
#define MAX_LED_FADE 1024U

// Globals from board/main_definitions.h and other firmware headers
uint32_t heartbeat_counter;
bool heartbeat_lost;
bool heartbeat_disabled;
uint32_t uptime_cnt;
uint8_t hw_type;
bool power_save_enabled;
#define LED_GREEN 1
#define LED_BLUE 2
#define LED_RED 0

// harness global
struct harness_t harness;

// ---- harness + board ----
#include "board/drivers/harness.h"
#include "boards/board_declarations.h"

void board_set_can_mode_stub(uint8_t mode) { (void)mode; }
GPIO_TypeDef dummy_gpio;

struct harness_configuration harness_config_stub;
struct board board_stub = {
    .harness_config = &harness_config_stub,
    .set_can_mode = board_set_can_mode_stub,
    .led_GPIO = {&dummy_gpio, &dummy_gpio, &dummy_gpio},
};
const struct board *current_board = &board_stub;

// ---- All function stubs ----
void set_intercept_relay(bool a, bool b) { (void)a; (void)b; }
void can_clear_send(uint32_t x, uint8_t y) { (void)x; (void)y; }
void harness_init(void) {}
void harness_tick(void) {}
bool harness_check_ignition(void) { return false; }
uint8_t harness_detect_orientation(void) { return 1; }

void fake_siren_set(bool en) { siren_enabled = en; }

bool can_init(uint8_t n) { (void)n; return true; }
void can_rx(uint8_t n) { (void)n; }
void process_can(uint8_t n) { (void)n; }
void update_can_health_pkt(uint8_t n) { (void)n; }

void simple_watchdog_init(uint32_t a, uint32_t b) { (void)a; (void)b; }
void simple_watchdog_kick(void) {}
void led_init(void) {}
void led_set(uint8_t led, bool en) { (void)led; (void)en; }
void pwm_init(void) {}
void pwm_set(uint8_t ch, uint8_t d) { (void)ch; (void)d; }
void usb_irqhandler(void) {}
void usb_init(void) {}
void spi_init(void) {}
void bootkick_tick(bool ign, bool hb) { (void)ign; (void)hb; }
void early_initialization(void) {}
void clock_init(void) {}
void peripherals_init(void) {}
void detect_board_type(void) {}
void get_provision_chunk(uint8_t *out) { if (out) out[0] = 0; }
void set_power_save_state(bool en) { (void)en; }
void enable_can_transceivers(bool en) { (void)en; }
void enter_stop_mode(void) {}
void comms_control_handler(void) {}
void comms_can_read(void) {}
void comms_can_write(void) {}
void comms_can_reset(void) {}
void refresh_can_tx_slots_available(void) {}
void sound_init(void) {}
void sound_tick(void) {}
void sound_init_dac(void) {}
void init_interrupts(bool en) { (void)en; }
void tick_timer_init(void) {}
void microsecond_timer_init(void) {}
void interrupt_timer_init(void) {}
void gpio_spi_init(void) {}
void fan_init(void) {}
void fan_set_power(uint8_t p) { (void)p; }
void fan_tick(void) {}

// Fault/register stubs
void check_registers(void) {}
void disable_interrupts(void) {}
void enable_interrupts(void) {}

// ADC
typedef struct { uint32_t x; } ADC_TypeDef;
ADC_TypeDef adc1_inst;
#define ADC1 (&adc1_inst)
void adc_init(ADC_TypeDef *adc) { (void)adc; }

// GPIO
#include "board/drivers/gpio.h"
void set_gpio_output(GPIO_TypeDef *gpio, uint8_t pin, bool val) { (void)gpio; (void)pin; (void)val; }
void set_gpio_mode(GPIO_TypeDef *gpio, uint8_t pin, uint8_t mode) { (void)gpio; (void)pin; (void)mode; }
void set_gpio_pullup(GPIO_TypeDef *gpio, uint8_t pin, uint8_t pull) { (void)gpio; (void)pin; (void)pull; }

// CMSIS intrinsics
void __WFI(void) {}
#define SCB_SCR_SLEEPDEEP_Msk 0x4U
#define SCB_SCR_SLEEPONEXIT_Msk 0x2U

// UART stubs needed by debug_ring_callback in main.c
#include "board/drivers/uart.h"
bool get_char(uart_ring *q, char *elem) { (void)q; (void)elem; return false; }
int put_char(uart_ring *q, char c) { (void)q; (void)c; return 0; }

// ---- Real firmware headers ----
#include "board/health.h"
#include "board/sys/faults.h"
#include "board/libc.h"
#include "board/drivers/interrupts.h"   // REGISTER_INTERRUPT, TICK_TIMER_IRQ

// ---- FULL board/main.c ----
// -Dmain=panda_main avoids symbol conflict.
// All mutations in board/main.c are caught by rebuild + ./gradlew cucumber.
#include "board/main.c"

// ---- JNA API ----
#ifdef __cplusplus
extern "C" {
#endif

void jna_set_safety_mode(uint16_t mode, uint16_t param) { set_safety_mode(mode, param); }
bool jna_get_can_silent(void) { return can_silent; }

#ifdef __cplusplus
}
#endif
