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
#include "fdcan_regs.h"

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
volatile bool stop_mode_requested;
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
static const uint32_t data_speeds[] = {20000};

// ---- Macros needed by main_comms.h ----
#define UID_BASE ((void *)0x1FFF7A10UL)
#define NUM_INTERRUPTS 0
#define DEVICE_SERIAL_NUMBER_ADDRESS ((void *)0x1FFF7A10UL)

// ---- Fake FDCAN hardware state ----
// Synthetic FDCAN peripheral instances — register writes go here instead of MMIO.
static FDCAN_GlobalTypeDef fake_fdcan[3] = {{0}, {0}, {0}};

// Fake SRAM buffer for FDCAN message RAM (llcan_init flushes this area).
#define FAKE_FDCAN_SRAM_SIZE 0x4000
static uint8_t fake_fdcan_sram[FAKE_FDCAN_SRAM_SIZE];
#undef FDCAN_START_ADDRESS
#define FDCAN_START_ADDRESS ((uint32_t)(uintptr_t)fake_fdcan_sram)

// Macro overrides: redirect hardware pointers to fake instances.
#define FDCAN1 (&fake_fdcan[0])
#define FDCAN2 (&fake_fdcan[1])
#define FDCAN3 (&fake_fdcan[2])

// FDCAN pointer array — matches real fdcan.h: cans[PANDA_CAN_CNT] = {FDCAN1, FDCAN2, FDCAN3}
FDCAN_GlobalTypeDef *cans[3] = {FDCAN1, FDCAN2, FDCAN3};

// Hardware stubs needed by can_init code path
#define NVIC_EnableIRQ(x) do {} while(0)
#define NVIC_DisableIRQ(x) do {} while(0)

// Tracking stubs for llcan_irq_enable/disable — records last CAN bus operated on
static int last_irq_enabled_bus = -1;
static int last_irq_disabled_bus[3] = {-1, -1, -1};  // track per-bus disable
static int irq_enable_call_count;
static int irq_disable_call_count;

void llcan_irq_enable(const FDCAN_GlobalTypeDef *x) {
    irq_enable_call_count++;
    if (x == FDCAN1) last_irq_enabled_bus = 0;
    else if (x == FDCAN2) last_irq_enabled_bus = 1;
    else if (x == FDCAN3) last_irq_enabled_bus = 2;
}
void llcan_irq_disable(const FDCAN_GlobalTypeDef *x) {
    irq_disable_call_count++;
    int bus = -1;
    if (x == FDCAN1) bus = 0;
    else if (x == FDCAN2) bus = 1;
    else if (x == FDCAN3) bus = 2;
    if (bus >= 0) last_irq_disabled_bus[bus] = irq_disable_call_count;
}
#define FDCAN1_IT1_IRQn 21
#define FDCAN2_IT0_IRQn 20
#define FDCAN2_IT1_IRQn 22
#define FDCAN3_IT0_IRQn 159
#define FDCAN3_IT1_IRQn 160

// ---- Macros needed by main_comms.h ----
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

// Tracking stub for set_ir_power — records all calls
#define MAX_IR_POWER_CALLS 16
static uint8_t ir_power_values[MAX_IR_POWER_CALLS];
static int ir_power_call_count;
void board_set_ir_power_stub(uint8_t p) {
    if (ir_power_call_count < MAX_IR_POWER_CALLS) {
        ir_power_values[ir_power_call_count] = p;
    }
    ir_power_call_count++;
}
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
void harness_init(void) {}
void harness_tick(void) {}
bool harness_check_ignition(void) { return false; }
uint8_t harness_detect_orientation(void) { return 1; }
void fake_siren_set(bool en) { siren_enabled = en; }
// can_init is defined in fdcan_e2e.gen.c (generated from real firmware source)
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

// Tracking stub: records last enable_can_transceivers call
static bool last_can_transceivers_enabled;
static int can_transceivers_call_count;
void enable_can_transceivers(bool en) {
    last_can_transceivers_enabled = en;
    can_transceivers_call_count++;
}

// ---- REAL set_power_save_state (auto-generated from board/sys/power_saving.h) ----
// Regenerate: python3 generate_power_save_stubs.py > power_save_e2e.gen.c
#include "power_save_e2e.gen.c"

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

// ---- Faithful can_init: writes to fake FDCAN_GlobalTypeDef registers ----
// Auto-generated from real firmware source by generate_fdcan_stubs.py.
// Regenerate: python3 generate_fdcan_stubs.py > fdcan_e2e.gen.c
#include "fdcan_e2e.gen.c"

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

// ---- JNA API: FDCAN register inspection ----
void jna_reset_fdcan(void) {
    for (int i = 0; i < 3; i++) {
        fake_fdcan[i] = (FDCAN_GlobalTypeDef){0};
    }
    for (size_t i = 0; i < FAKE_FDCAN_SRAM_SIZE; i++) {
        fake_fdcan_sram[i] = 0;
    }
    // Reset globals that persist across scenarios and affect can_init()
    can_loopback = false;
    can_silent = true;
    // Restore default bus_config (can_speed, can_data_speed) modified by 0xde set-can-bitrate
    bus_config[0].can_speed = 5000U;
    bus_config[0].can_data_speed = 20000U;
    bus_config[1].can_speed = 5000U;
    bus_config[1].can_data_speed = 20000U;
    bus_config[2].can_speed = 5000U;
    bus_config[2].can_data_speed = 20000U;
    // Reset CAN FD flags
    bus_config[0].canfd_auto = false;
    bus_config[0].canfd_non_iso = false;
    bus_config[0].canfd_enabled = false;
    bus_config[0].brs_enabled = false;
    bus_config[1].canfd_auto = false;
    bus_config[1].canfd_non_iso = false;
    bus_config[1].canfd_enabled = false;
    bus_config[1].brs_enabled = false;
    bus_config[2].canfd_auto = false;
    bus_config[2].canfd_non_iso = false;
    bus_config[2].canfd_enabled = false;
    bus_config[2].brs_enabled = false;
}

// Reset heartbeat state between scenarios
void jna_reset_heartbeat(void) {
    heartbeat_counter = 0U;
    heartbeat_lost = false;
    heartbeat_disabled = false;
    heartbeat_engaged = false;
    heartbeat_engaged_mismatches = 0U;
}

// Reset safety mode to SILENT between scenarios
void jna_reset_safety(void) {
    set_safety_mode(SAFETY_SILENT, 0U);
}
uint32_t jna_get_fdcan_cccr(int can_number) {
    if ((can_number < 0) || (can_number >= 3)) return 0;
    return fake_fdcan[can_number].CCCR;
}
uint32_t jna_get_fdcan_ie(int can_number) {
    if ((can_number < 0) || (can_number >= 3)) return 0;
    return fake_fdcan[can_number].IE;
}
uint32_t jna_get_fdcan_nbtp(int can_number) {
    if ((can_number < 0) || (can_number >= 3)) return 0;
    return fake_fdcan[can_number].NBTP;
}
uint32_t jna_get_fdcan_dbtp(int can_number) {
    if ((can_number < 0) || (can_number >= 3)) return 0;
    return fake_fdcan[can_number].DBTP;
}
uint32_t jna_get_fdcan_txbc(int can_number) {
    if ((can_number < 0) || (can_number >= 3)) return 0;
    return fake_fdcan[can_number].TXBC;
}
uint32_t jna_get_fdcan_rxf0c(int can_number) {
    if ((can_number < 0) || (can_number >= 3)) return 0;
    return fake_fdcan[can_number].RXF0C;
}
uint32_t jna_get_fdcan_txesc(int can_number) {
    if ((can_number < 0) || (can_number >= 3)) return 0;
    return fake_fdcan[can_number].TXESC;
}
uint32_t jna_get_fdcan_rxesc(int can_number) {
    if ((can_number < 0) || (can_number >= 3)) return 0;
    return fake_fdcan[can_number].RXESC;
}
uint32_t jna_get_fdcan_gfc(int can_number) {
    if ((can_number < 0) || (can_number >= 3)) return 0;
    return fake_fdcan[can_number].GFC;
}
uint32_t jna_get_fdcan_ile(int can_number) {
    if ((can_number < 0) || (can_number >= 3)) return 0;
    return fake_fdcan[can_number].ILE;
}
uint32_t jna_get_fdcan_ir(int can_number) {
    if ((can_number < 0) || (can_number >= 3)) return 0;
    return fake_fdcan[can_number].IR;
}

// ---- JNA API: Heartbeat state inspection ----
uint32_t jna_get_heartbeat_counter(void) {
    return heartbeat_counter;
}
int jna_get_heartbeat_lost(void) {
    return heartbeat_lost ? 1 : 0;
}
int jna_get_heartbeat_disabled(void) {
    return heartbeat_disabled ? 1 : 0;
}
int jna_get_heartbeat_engaged(void) {
    return heartbeat_engaged ? 1 : 0;
}

// ---- JNA API: Power save state inspection ----
int jna_get_power_save_enabled(void) {
    return power_save_enabled ? 1 : 0;
}

// ---- JNA API: Alternative experience inspection ----
// alternative_experience is declared in opendbc safety headers
uint32_t jna_get_alternative_experience(void) {
    return (uint32_t)alternative_experience;
}
void jna_reset_alternative_experience(void) {
    alternative_experience = 0U;
}

// ---- JNA API: Siren state inspection ----
int jna_get_siren_enabled(void) {
    return siren_enabled ? 1 : 0;
}
void jna_reset_siren(void) {
    siren_enabled = false;
}

// ---- JNA API: Power-save hardware call tracking ----
// llcan_irq_enable/disable tracking
int jna_get_irq_enable_call_count(void) { return irq_enable_call_count; }
int jna_get_irq_disable_call_count(void) { return irq_disable_call_count; }
int jna_get_last_irq_enabled_bus(void) { return last_irq_enabled_bus; }
int jna_get_irq_disabled_bus(int bus) {
    if ((bus < 0) || (bus >= 3)) return -1;
    return last_irq_disabled_bus[bus] > 0 ? 1 : 0;
}
// enable_can_transceivers tracking
int jna_get_can_transceivers_enabled(void) { return last_can_transceivers_enabled ? 1 : 0; }
int jna_get_can_transceivers_call_count(void) { return can_transceivers_call_count; }
// set_ir_power tracking
int jna_get_ir_power_call_count(void) { return ir_power_call_count; }
int jna_get_ir_power_value_at(int index) {
    if ((index < 0) || (index >= ir_power_call_count) || (index >= MAX_IR_POWER_CALLS)) return -1;
    return (int)ir_power_values[index];
}

void jna_reset_power_save_tracking(void) {
    power_save_enabled = false;
    irq_enable_call_count = 0;
    irq_disable_call_count = 0;
    last_irq_enabled_bus = -1;
    last_irq_disabled_bus[0] = -1;
    last_irq_disabled_bus[1] = -1;
    last_irq_disabled_bus[2] = -1;
    last_can_transceivers_enabled = false;
    can_transceivers_call_count = 0;
    ir_power_call_count = 0;
}

// ---- JNA API: CAN comms buffer inspection (comms_can_reset) ----
uint32_t jna_get_can_read_buffer_ptr(void) {
    return can_read_buffer.ptr;
}
uint32_t jna_get_can_read_buffer_tail(void) {
    return can_read_buffer.tail_size;
}
uint32_t jna_get_can_write_buffer_ptr(void) {
    return can_write_buffer.ptr;
}
uint32_t jna_get_can_write_buffer_tail(void) {
    return can_write_buffer.tail_size;
}

// ---- JNA API: Version ----
const char *jna_get_gitversion(void) {
    return gitversion;
}

// ---- JNA API: Packet versions (read from response after 0xdd) ----
// Returns the two uint32 values from the last control response buffer.
// Call after controlWrite(0xdd, 0, 0).
void jna_get_packet_versions(uint32_t *out_health_version, uint32_t *out_can_version_hash) {
    if ((jna_resp_len >= 8U) && (out_health_version != ((void *)0)) && (out_can_version_hash != ((void *)0))) {
        (void)memcpy(out_health_version, jna_resp, 4U);
        (void)memcpy(out_can_version_hash, jna_resp + 4U, 4U);
    }
}

// ---- JNA API: Hardware type ----
uint8_t jna_get_hw_type(void) {
    return hw_type;
}

// ---- JNA API: CAN FD bus_config inspection ----
int jna_get_bus_canfd_auto(int bus) {
    if ((bus < 0) || (bus >= PANDA_CAN_CNT)) return 0;
    return bus_config[bus].canfd_auto ? 1 : 0;
}
int jna_get_bus_canfd_non_iso(int bus) {
    if ((bus < 0) || (bus >= PANDA_CAN_CNT)) return 0;
    return bus_config[bus].canfd_non_iso ? 1 : 0;
}
int jna_get_bus_canfd_enabled(int bus) {
    if ((bus < 0) || (bus >= PANDA_CAN_CNT)) return 0;
    return bus_config[bus].canfd_enabled ? 1 : 0;
}
int jna_get_bus_brs_enabled(int bus) {
    if ((bus < 0) || (bus >= PANDA_CAN_CNT)) return 0;
    return bus_config[bus].brs_enabled ? 1 : 0;
}
int jna_get_bus_can_data_speed(int bus) {
    if ((bus < 0) || (bus >= PANDA_CAN_CNT)) return 0;
    return (int)bus_config[bus].can_data_speed;
}
void jna_reset_bus_canfd_flags(void) {
    for (int i = 0; i < PANDA_CAN_CNT; i++) {
        bus_config[i].canfd_auto = false;
        bus_config[i].canfd_non_iso = false;
        bus_config[i].canfd_enabled = false;
        bus_config[i].brs_enabled = false;
    }
}

// ---- JNA API: Health packet inspection ----
static struct health_t jna_health;

void jna_read_health_pkt(void) {
    get_health_pkt(&jna_health);
}

uint32_t jna_get_health_uptime(void) {
    return jna_health.uptime_pkt;
}
uint32_t jna_get_health_voltage(void) {
    return jna_health.voltage_pkt;
}
uint32_t jna_get_health_current(void) {
    return jna_health.current_pkt;
}
uint32_t jna_get_health_safety_tx_blocked(void) {
    return jna_health.safety_tx_blocked_pkt;
}
uint32_t jna_get_health_safety_rx_invalid(void) {
    return jna_health.safety_rx_invalid_pkt;
}
uint8_t jna_get_health_safety_mode(void) {
    return jna_health.safety_mode_pkt;
}
uint16_t jna_get_health_safety_param(void) {
    return jna_health.safety_param_pkt;
}
uint8_t jna_get_health_heartbeat_lost(void) {
    return jna_health.heartbeat_lost_pkt;
}

#ifdef __cplusplus
}
#endif
