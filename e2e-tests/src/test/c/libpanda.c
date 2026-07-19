// libpanda.c — compiles FULL board/main.c as host .dylib.
// All STM32 HAL deps stubbed. Goes through FULL firmware path including
// comms_control_handler() for disease testing.
//
// Build: ./build.sh
// Test:  cd .. && ./gradlew cucumber

#include "fake_stm.h"
#include "config.h"
#include <stdbool.h>

// ---- Deps that must be available before firmware headers ----
#include "opendbc/safety/can.h"
#include "board/stm32h7/stm32h7_config.h"

// ---- Timer ----
TIM_TypeDef tick_timer_inst;
TIM_TypeDef *TICK_TIMER = &tick_timer_inst;

// ---- Globals used by set_safety_mode() ----
// can_silent is defined by can_common.h (initialized to true), so we DON'T redefine
uint32_t safety_tx_blocked;
uint32_t safety_rx_invalid;
uint32_t heartbeat_counter;
bool heartbeat_lost;
bool heartbeat_disabled;
uint32_t uptime_cnt;
uint8_t hw_type;
bool power_save_enabled;
bool siren_enabled;
uint32_t siren_countdown;
uint32_t stop_mode_requested;
#define MAX_LED_FADE 1024U

// ---- Globals used by main_comms.h (get_health_pkt + comms_control_handler) ----
float interrupt_load;
uint16_t sound_output_level;
uint32_t enter_bootloader_mode;
bool bootkick_reset_triggered;
uint16_t spi_error_count;

// _app_start used by main_comms.h header
int _app_start[0xC000];

struct { uint32_t call_rate; } interrupts[0];
static char gitversion[64] = "00000000";
static const uint32_t speeds[] = {0};
static const uint32_t data_speeds[] = {0};

// ---- Macros needed by main_comms.h ----
#define UID_BASE ((void *)0x1FFF7A10UL)
#define NUM_INTERRUPTS 0
#define DEVICE_SERIAL_NUMBER_ADDRESS ((void *)0x1FFF7A10UL)
#define PROVISION_CHUNK_LEN 0x20
#define ENTER_BOOTLOADER_MAGIC 0x0
#define ENTER_SOFTLOADER_MAGIC 0x0
#define CAN_PACKET_VERSION_HASH 0
#define HEALTH_PACKET_VERSION 0
#define CAN_NUM_FROM_BUS_NUM(b) (b)
#define LED_GREEN 1
#define LED_BLUE 2
#define LED_RED 0

// ---- harness + board + uart ----
#include "board/drivers/harness.h"
struct harness_t harness;

#include "board/drivers/uart.h"
uart_ring uart_ring_debug = {0};
uart_ring uart_ring_som_debug = {0};
uart_ring *get_ring_by_number(int a) {
    return (a == 0) ? &uart_ring_debug : &uart_ring_som_debug;
}

#include "boards/board_declarations.h"
GPIO_TypeDef dummy_gpio;
static uint8_t can_mode_last;
static int can_mode_call_count;
void board_set_can_mode_stub(uint8_t mode) {
    can_mode_last = mode;
    can_mode_call_count++;
}
uint32_t board_read_voltage_mV_stub(void) { return 12000; }
uint32_t board_read_current_mA_stub(void) { return 0; }
void board_set_ir_power_stub(uint8_t p) { (void)p; }
void board_set_fan_enabled_stub(bool en) { (void)en; }
void board_set_siren_stub(bool en) { siren_enabled = en; }
void board_set_bootkick_stub(uint8_t s) { (void)s; }
bool board_read_som_gpio_stub(void) { return false; }

struct harness_configuration harness_config_stub;
struct board board_stub = {
    .harness_config = &harness_config_stub,
    .led_GPIO = {&dummy_gpio, &dummy_gpio, &dummy_gpio},
    .set_can_mode = board_set_can_mode_stub,
    .read_voltage_mV = board_read_voltage_mV_stub,
    .read_current_mA = board_read_current_mA_stub,
    .set_ir_power = board_set_ir_power_stub,
    .set_fan_enabled = board_set_fan_enabled_stub,
    .set_siren = board_set_siren_stub,
    .set_bootkick = board_set_bootkick_stub,
    .read_som_gpio = board_read_som_gpio_stub,
};
const struct board *current_board = &board_stub;

// ---- Function stubs ----
// Recording stub: captures last set_intercept_relay call for test verification
static bool relay_a, relay_b;
static int relay_call_count;
void set_intercept_relay(bool a, bool b) {
    relay_a = a;
    relay_b = b;
    relay_call_count++;
}
// Recording stub: captures last can_clear_send call for test verification
static uint32_t can_clear_send_arg_x;
static uint8_t can_clear_send_arg_y;
static int can_clear_send_count;
void can_clear_send(uint32_t x, uint8_t y) {
    can_clear_send_arg_x = x;
    can_clear_send_arg_y = y;
    can_clear_send_count++;
}
void harness_init(void) {}
void harness_tick(void) {}
bool harness_check_ignition(void) { return false; }
uint8_t harness_detect_orientation(void) { return 1; }
void fake_siren_set(bool en) { siren_enabled = en; }
bool can_init(uint8_t n) { (void)n; return true; }
void can_rx(uint8_t n) { (void)n; }
void process_can(uint8_t n) { (void)n; }
void update_can_health_pkt(uint8_t n, uint8_t ext) { (void)n; (void)ext; }
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
void clock_source_set_timer_params(uint16_t p, uint16_t l) { (void)p; (void)l; }
void check_registers(void) {}
void disable_interrupts(void) {}
void enable_interrupts(void) {}
void NVIC_SystemReset(void) {}

// Stubs for can_comms functions (real can_comms.h calls these)
void can_tx_comms_resume_usb(void) {}
void can_tx_comms_resume_spi(void) {}

// fan_state instance (type from drivers.h)
struct fan_state_t fan_state;

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

// UART helpers
bool get_char(uart_ring *q, char *elem) { (void)q; (void)elem; return false; }
int put_char(uart_ring *q, char c) { (void)q; (void)c; return 0; }

// ---- Real firmware headers ----
#include "board/health.h"
#include "board/sys/faults.h"
#include "board/libc.h"
#include "board/drivers/interrupts.h"

// ---- FULL board/main.c ----
#include "board/main.c"

// ---- JNA API: goes through comms_control_handler → set_safety_mode() ----
static uint8_t jna_resp[0x40];
static int jna_resp_len;

#ifdef __cplusplus
extern "C" {
#endif

void jna_control_write(uint8_t request, uint16_t param1, uint16_t param2) {
    ControlPacket_t req = { .request = request, .param1 = param1, .param2 = param2, .length = 0 };
    jna_resp_len = comms_control_handler(&req, jna_resp);
}

// ---- JNA API: CAN pipeline testing (real can_send → safety_tx_hook → can_push) ----

// Send CAN through real firmware pipeline.
// Returns: 0 = allowed (queued to can_tx*_q), 1 = blocked (queued to can_rx_q with rejected=1)
int jna_can_send(uint32_t addr, uint8_t bus, const uint8_t *data, uint8_t len) {
    CANPacket_t pkt = {0};
    pkt.addr = addr;
    pkt.bus = bus;
    pkt.extended = (addr > 0x7FFU) ? 1U : 0U;
    pkt.data_len_code = len;
    if ((len > 0U) && (len <= 64U)) {
        (void)memcpy(pkt.data, data, len);
    }
    // can_set_checksum not needed: safety hooks use struct fields, not raw bytes

    uint32_t blocked_before = safety_tx_blocked;
    can_send(&pkt, bus, false);

    return (safety_tx_blocked > blocked_before) ? 1 : 0;
}

uint32_t jna_get_safety_tx_blocked(void) {
    return safety_tx_blocked;
}

// Pop from can_rx_q (blocked/rejected messages end up here).
// Returns true if a message was popped.
bool jna_can_pop_rx(uint32_t *out_addr, uint8_t *out_bus, uint8_t *out_rejected,
                     uint8_t *out_data, uint8_t *out_len) {
    CANPacket_t pkt;
    if (can_pop(&can_rx_q, &pkt)) {
        *out_addr = pkt.addr;
        *out_bus = pkt.bus;
        *out_rejected = pkt.rejected;
        *out_len = pkt.data_len_code;
        if (pkt.data_len_code > 0U) {
            (void)memcpy(out_data, pkt.data, pkt.data_len_code);
        }
        return true;
    }
    return false;
}

// Pop from can_tx{1,2,3}_q (allowed messages end up here).
// queue_idx: 0=tx1_q (bus 0), 1=tx2_q (bus 1), 2=tx3_q (bus 2)
bool jna_can_pop_tx(int queue_idx, uint32_t *out_addr, uint8_t *out_data, uint8_t *out_len) {
    if ((queue_idx < 0) || (queue_idx >= PANDA_CAN_CNT)) {
        return false;
    }

    CANPacket_t pkt;
    if (can_pop(can_queues[queue_idx], &pkt)) {
        *out_addr = pkt.addr;
        *out_len = pkt.data_len_code;
        if (pkt.data_len_code > 0U) {
            (void)memcpy(out_data, pkt.data, pkt.data_len_code);
        }
        return true;
    }
    return false;
}

// Clear all CAN queues (reset read/write pointers)
void jna_can_clear_all(void) {
    can_rx_q.w_ptr = 0U;
    can_rx_q.r_ptr = 0U;
    for (int i = 0; i < PANDA_CAN_CNT; i++) {
        can_queues[i]->w_ptr = 0U;
        can_queues[i]->r_ptr = 0U;
    }
}

// Query last set_intercept_relay call parameters
int jna_get_relay_call_count(void) {
    return relay_call_count;
}
int jna_get_relay_a(void) {
    return relay_a ? 1 : 0;
}
int jna_get_relay_b(void) {
    return relay_b ? 1 : 0;
}
void jna_clear_relay_calls(void) {
    relay_call_count = 0;
    relay_a = false;
    relay_b = false;
}

// Query last can_clear_send call
int jna_get_can_clear_send_count(void) {
    return can_clear_send_count;
}
int jna_get_can_clear_send_x(void) {
    return (int)can_clear_send_arg_x;
}
int jna_get_can_clear_send_y(void) {
    return (int)can_clear_send_arg_y;
}
void jna_clear_can_clear_send_calls(void) {
    can_clear_send_count = 0;
    can_clear_send_arg_x = 0U;
    can_clear_send_arg_y = 0U;
}

// Query last set_can_mode call
int jna_get_can_mode_call_count(void) {
    return can_mode_call_count;
}
int jna_get_can_mode(void) {
    return (int)can_mode_last;
}
void jna_clear_can_mode_calls(void) {
    can_mode_call_count = 0;
    can_mode_last = 0U;
}

#ifdef __cplusplus
}
#endif
