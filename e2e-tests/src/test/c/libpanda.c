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
// adc_signal_t needed by drivers.h (included via registers.h → stm32h7_config.h).
// Copied from board/stm32h7/lladc_declarations.h but with void* instead of ADC_TypeDef*
// to avoid needing the full ADC_TypeDef before it's defined at line ~508.
#ifndef ADC_SIGNAL_T_DEFINED
#define ADC_SIGNAL_T_DEFINED
typedef enum { SAMPLETIME_1_CYCLE = 0, SAMPLETIME_2_CYCLES = 1, SAMPLETIME_8_CYCLES = 2,
  SAMPLETIME_16_CYCLES = 3, SAMPLETIME_32_CYCLES = 4, SAMPLETIME_64_CYCLES = 5,
  SAMPLETIME_387_CYCLES = 6, SAMPLETIME_810_CYCLES = 7 } adc_sample_time_t;
typedef enum { OVERSAMPLING_1 = 0, OVERSAMPLING_2 = 1, OVERSAMPLING_4 = 2,
  OVERSAMPLING_8 = 3, OVERSAMPLING_16 = 4, OVERSAMPLING_32 = 5, OVERSAMPLING_64 = 6,
  OVERSAMPLING_128 = 7, OVERSAMPLING_256 = 8, OVERSAMPLING_512 = 9, OVERSAMPLING_1024 = 10 } adc_oversampling_t;
typedef struct { void *adc; uint8_t channel; adc_sample_time_t sample_time; adc_oversampling_t oversampling; } adc_signal_t;
#define ADC_CHANNEL_DEFAULT(a, c) {.adc = (a), .channel = (c), .sample_time = SAMPLETIME_32_CYCLES, .oversampling = OVERSAMPLING_64}
#endif
// harness types (normally in drivers.h inside #ifdef STM32H7; needed early for e2e)
#define HARNESS_STATUS_NC 0U
#define HARNESS_STATUS_NORMAL 1U
#define HARNESS_STATUS_FLIPPED 2U
struct harness_t {
  uint8_t status;
  uint16_t sbu1_voltage_mV;
  uint16_t sbu2_voltage_mV;
  bool relay_driven;
  bool sbu_adc_lock;
};
struct harness_configuration {
  GPIO_TypeDef * const GPIO_SBU1;
  GPIO_TypeDef * const GPIO_SBU2;
  GPIO_TypeDef * const GPIO_relay_SBU1;
  GPIO_TypeDef * const GPIO_relay_SBU2;
  const uint8_t pin_SBU1;
  const uint8_t pin_SBU2;
  const uint8_t pin_relay_SBU1;
  const uint8_t pin_relay_SBU2;
  const adc_signal_t adc_signal_SBU1;
  const adc_signal_t adc_signal_SBU2;
};
typedef struct harness_configuration harness_configuration;

// ---- Fake UID (must be before spi.h include, used by spi_version_packet) ----
static uint8_t fake_uid[12];
#undef UID_BASE
#define UID_BASE ((void *)fake_uid)

#include "board/stm32h7/stm32h7_config.h"
#include "fdcan_regs.h"

// ---- Timer ----
TIM_TypeDef tick_timer_inst;
TIM_TypeDef *TICK_TIMER = &tick_timer_inst;

// ---- Fake TIM instances for clock_source_set_timer_params ----
// Expand TIM_TypeDef with fields needed by clock_source.h
#undef TIM_TypeDef
typedef struct {
    uint32_t CR1, CR2, SMCR, DIER, SR, EGR, CCMR1, CCMR2, CCER, CNT, PSC, ARR;
    uint32_t _pad1;
    uint32_t CCR1, CCR2, CCR3, CCR4;
    uint32_t _pad2[3];
    uint32_t BDTR;
} e2e_TIM_TypeDef;

static e2e_TIM_TypeDef fake_TIM1, fake_TIM8;

// ---- Globals used by set_safety_mode() ----
// can_silent is defined by can_common.h (initialized to true), so we DON'T redefine
uint32_t safety_tx_blocked;
uint32_t safety_rx_invalid;
uint32_t heartbeat_counter;
bool heartbeat_lost;
bool heartbeat_disabled;
uint32_t uptime_cnt;
uint8_t hw_type;
bool siren_enabled;
uint32_t siren_countdown;
extern volatile bool stop_mode_requested;
#define MAX_LED_FADE 1024U

// ---- Fake hardware register types (field offsets match real STM32H7 headers) ----
// GPIO_TypeDef is now defined in fake_stm.h (full struct matching STM32H7)

struct e2e_ADC_Regs  { uint8_t _pad[8]; volatile uint32_t CR; };
struct e2e_RCC_Regs  { volatile uint32_t CR, HSICFGR, CRRCR; uint8_t _p[0xF0];
                       volatile uint32_t AHB3LPENR, AHB1LPENR, AHB2LPENR, AHB4LPENR; };
struct e2e_SYSCFG_Regs { uint32_t _r0; volatile uint32_t PMCR; volatile uint32_t EXTICR[4]; volatile uint32_t CFGR; };
struct e2e_EXTI_Regs {
    volatile uint32_t RTSR1, FTSR1, SWIER1, D3PMR1, D3PCR1L, D3PCR1H; uint8_t _p1[8];
    volatile uint32_t RTSR2, FTSR2, SWIER2, D3PMR2, D3PCR2L, D3PCR2H; uint8_t _p2[8];
    volatile uint32_t RTSR3, FTSR3, SWIER3, D3PMR3, D3PCR3L, D3PCR3H; uint8_t _p3[40];
    volatile uint32_t IMR1, EMR1, PR1;
};
struct e2e_PWR_Regs  { volatile uint32_t CR1, CSR1, CR2, CR3, CPUCR; uint32_t _r0; volatile uint32_t D3CR; };
struct e2e_NVIC_Regs {
    volatile uint32_t ISER[8]; uint8_t _p0[96];
    volatile uint32_t ICER[8]; uint8_t _p1[96];
    volatile uint32_t ISPR[8]; uint8_t _p2[96];
    volatile uint32_t ICPR[8];
};
struct e2e_SCB_Regs  { uint8_t _p[0x0C]; volatile uint32_t SCR; volatile uint32_t _p2[0x13]; volatile uint32_t CPACR; };

// Fake register instances (file scope, before harness_config_stub)
GPIO_TypeDef e2e_GPIOA, e2e_GPIOB, e2e_GPIOC, e2e_GPIOD, e2e_GPIOE, e2e_GPIOF, e2e_GPIOG;
struct e2e_ADC_Regs    e2e_ADC1, e2e_ADC2;
struct e2e_RCC_Regs    e2e_RCC;
struct e2e_SYSCFG_Regs e2e_SYSCFG;
struct e2e_EXTI_Regs   e2e_EXTI;
struct e2e_PWR_Regs    e2e_PWR;
struct e2e_NVIC_Regs   e2e_NVIC;
struct e2e_SCB_Regs    e2e_SCB;

// ---- Globals used by main_comms.h (get_health_pkt + comms_control_handler) ----
float interrupt_load;
uint16_t sound_output_level;
uint32_t enter_bootloader_mode;
uint16_t spi_error_count;

// _app_start used by main_comms.h header
int _app_start[0xC000];

// ---- Interrupt tracking (must be before fdcan.h which calls REGISTER_INTERRUPT) ----
// Full struct defined in e2e board/drivers/interrupts.h (C3)
#include "board/drivers/interrupts.h"
#define NUM_INTERRUPTS 161
interrupt interrupts[NUM_INTERRUPTS];
static char gitversion[64] = "00000000";
// speeds[] and data_speeds[] now come from real board/stm32h7/llfdcan.h (C3)

// ---- Fake Serial / Provision ----
static uint8_t fake_serial[16];
#undef DEVICE_SERIAL_NUMBER_ADDRESS
#define DEVICE_SERIAL_NUMBER_ADDRESS ((void *)fake_serial)

static uint8_t fake_provision[32];
#undef PROVISION_CHUNK_ADDRESS
#define PROVISION_CHUNK_ADDRESS ((void *)fake_provision)

// ---- Fake FDCAN hardware state ----
// Synthetic FDCAN peripheral instances — register writes go here instead of MMIO.
static FDCAN_GlobalTypeDef fake_fdcan[3] = {{0}, {0}, {0}};

// Fake SRAM buffer for FDCAN message RAM (llcan_init flushes this area).
#define FAKE_FDCAN_SRAM_SIZE 0x4000
static uint8_t fake_fdcan_sram[FAKE_FDCAN_SRAM_SIZE];
#undef FDCAN_START_ADDRESS
#define FDCAN_START_ADDRESS ((uintptr_t)fake_fdcan_sram)

// Macro overrides: redirect hardware pointers to fake instances.
#define FDCAN1 (&fake_fdcan[0])
#define FDCAN2 (&fake_fdcan[1])
#define FDCAN3 (&fake_fdcan[2])

// FDCAN pointer array — matches real fdcan.h: cans[PANDA_CAN_CNT] = {FDCAN1, FDCAN2, FDCAN3}
FDCAN_GlobalTypeDef *cans[3] = {FDCAN1, FDCAN2, FDCAN3};

// Hardware stubs needed by can_init code path
#define NVIC_EnableIRQ(x) e2e_nvic_enable_irq(x)
#define NVIC_DisableIRQ(x) e2e_nvic_disable_irq(x)

#define FDCAN1_IT0_IRQn 19
#define FDCAN1_IT1_IRQn 21
#define FDCAN2_IT0_IRQn 20
#define FDCAN2_IT1_IRQn 22
#define FDCAN3_IT0_IRQn 159
#define FDCAN3_IT1_IRQn 160

// Tracking stubs for llcan_irq_enable/disable — records last CAN bus operated on
// Real implementations now come from board/stm32h7/llfdcan.h (C3)
static int last_irq_enabled_bus = -1;
static int last_irq_disabled_bus[3] = {-1, -1, -1};  // track per-bus disable
static int irq_enable_call_count;
static int irq_disable_call_count;

// NVIC_DisableIRQ tracking — records IRQ numbers that were disabled
#define MAX_NVIC_DISABLE_CALLS 16
static int nvic_disabled_irqs[MAX_NVIC_DISABLE_CALLS];
static int nvic_disable_irq_count;
static void e2e_nvic_disable_irq(int irq) {
    irq_disable_call_count++;
    if (nvic_disable_irq_count < MAX_NVIC_DISABLE_CALLS) {
        nvic_disabled_irqs[nvic_disable_irq_count++] = irq;
    }
    // Track per-bus disable (mapping IRQn → bus number)
    int bus = -1;
    if (irq == FDCAN1_IT0_IRQn || irq == FDCAN1_IT1_IRQn) bus = 0;
    else if (irq == FDCAN2_IT0_IRQn || irq == FDCAN2_IT1_IRQn) bus = 1;
    else if (irq == FDCAN3_IT0_IRQn || irq == FDCAN3_IT1_IRQn) bus = 2;
    if (bus >= 0) last_irq_disabled_bus[bus] = 1;  // mark as disabled
}

// ---- Macros needed by main_comms.h ----
#define PROVISION_CHUNK_LEN 0x20
#define ENTER_BOOTLOADER_MAGIC 0x1U
#define ENTER_SOFTLOADER_MAGIC 0x2U
#define CAN_PACKET_VERSION_HASH 0
#define HEALTH_PACKET_VERSION 0
#define CAN_NUM_FROM_BUS_NUM(b) (b)
#define LED_GREEN 1
#define LED_BLUE 2
#define LED_RED 0

// ---- harness + board + uart ----
// harness is now real production code (B5), included via board/stm32h7/board.h
// harness_detect_orientation() is non-static under E2E_TEST — forward-declare for JNA
uint8_t harness_detect_orientation(void);
// Initialize SBU voltages above detection threshold so default detection is NC (0).
// This matches the production behavior where floating SBU pins read high via pull-ups.
struct harness_t harness = {.sbu1_voltage_mV = 3300U, .sbu2_voltage_mV = 3300U};

#include "board/drivers/uart.h"
uart_ring uart_ring_debug = {0};
uart_ring uart_ring_som_debug = {0};
static uint8_t uart_debug_rx_buf[256];
static uint8_t uart_debug_tx_buf[256];
static uint8_t uart_som_debug_tx_buf[256];
uart_ring *get_ring_by_number(int a) {
    if (a == 0) {
        uart_ring_debug.elems_rx = uart_debug_rx_buf;
        uart_ring_debug.rx_fifo_size = 256;
        uart_ring_debug.elems_tx = uart_debug_tx_buf;
        uart_ring_debug.tx_fifo_size = 256;
        return &uart_ring_debug;
    }
    if (a == 4) {
        uart_ring_som_debug.elems_tx = uart_som_debug_tx_buf;
        uart_ring_som_debug.tx_fifo_size = 256;
        return &uart_ring_som_debug;
    }
    return NULL;
}

#include "boards/board_declarations.h"

// Board selection fallback
#if !defined(E2E_BOARD_CUATRO) && !defined(E2E_BOARD_TRES) && !defined(E2E_BOARD_RED)
#define E2E_BOARD_CUATRO
#endif

// Health voltage/current — JNA setters for e2e testing

// ---- enter_stop_mode tracking ----
static bool irq_disabled;
static bool dsb_called;
static bool isb_called;
static bool wfi_entered;
static bool adc1_deep_powerdown;
static bool adc2_deep_powerdown;
static bool hsi48_disabled;
static bool sram_retention_disabled;
static bool sbu_exti_configured;
static bool can_exti_configured;
static bool pwr_stop_mode_configured;
static bool voltage_scaling_low_power_set;
static bool wfi_entered;
static bool ignition_checked;
static bool nvic_interrupts_disabled;
static bool nvic_wakeup_enabled;
static bool sleepdeep_set;

GPIO_TypeDef dummy_gpio;

static uint32_t e2e_voltage_mV = 12000;
static uint32_t e2e_current_mA = 0;
uint32_t board_read_voltage_mV_stub(void) { return e2e_voltage_mV; }
uint32_t board_read_current_mA_stub(void) { return e2e_current_mA; }

void jna_set_voltage_mV(int val) { e2e_voltage_mV = (uint32_t)val; }
void jna_set_current_mA(int val) { e2e_current_mA = (uint32_t)val; }

// Tracking stub for set_ir_power — records all calls
#define MAX_IR_POWER_CALLS 16
static uint8_t ir_power_values[MAX_IR_POWER_CALLS];
void board_set_ir_power_stub(uint8_t p) {
    fake_TIM1.CCR1 = p;  // IR PWM duty cycle
    ir_power_values[0] = p;
}
void board_set_siren_stub(bool en);
bool board_read_som_gpio_stub(void);

struct harness_configuration harness_config_stub = {
    .GPIO_SBU1 = (GPIO_TypeDef *)&e2e_GPIOC,
    .GPIO_SBU2 = (GPIO_TypeDef *)&e2e_GPIOA,
    .GPIO_relay_SBU1 = (GPIO_TypeDef *)&dummy_gpio,
    .GPIO_relay_SBU2 = (GPIO_TypeDef *)&dummy_gpio,
    .pin_SBU1 = 4,
    .pin_SBU2 = 1,
    .pin_relay_SBU1 = 0,
    .pin_relay_SBU2 = 0,
    .adc_signal_SBU1 = {.adc = (void *)&e2e_ADC1, .channel = 4},
    .adc_signal_SBU2 = {.adc = (void *)&e2e_ADC1, .channel = 17},
};

// ---- E2E board.h: real board headers (red/tres/cuatro) + init stubs ----
// Must be included AFTER all GPIO/PWR/macro definitions and AFTER harness_config_stub.
// Provides static board functions (enable_can_transceiver, set_bootkick, etc.)
// compiled directly instead of via board_stubs_e2e.gen.c.
TIM_TypeDef fake_TIM3;
#include "board/stm32h7/board.h"

// ---- E2E board struct — real functions from board/boards/*.h + test intercepts ----
// Board functions for enable_can_transceiver, set_bootkick, set_amp_enabled,
// and set_can_mode come from the real board headers (compiled directly).
// Voltage, current, fan, IR, siren, and SOM GPIO are intercepted for testing.
#if defined(E2E_BOARD_CUATRO)
struct board e2e_board = {
    .harness_config = &cuatro_harness_config,
    .led_GPIO = {GPIOC, GPIOC, GPIOC},
    .led_pin = {6, 7, 9},
    .led_pwm_channels = {1, 2, 4},
    .has_spi = true,
    .has_fan = true,
    .avdd_mV = 1800U,
    .fan_enable_cooldown_time = 3U,
    .init = cuatro_init,
    .init_bootloader = unused_init_bootloader,
    .enable_can_transceiver = cuatro_enable_can_transceiver,
    .set_can_mode = tres_set_can_mode,
    .read_voltage_mV = board_read_voltage_mV_stub,
    .read_current_mA = board_read_current_mA_stub,
    .set_ir_power = board_set_ir_power_stub,
    .set_fan_enabled = cuatro_set_fan_enabled,
    .set_siren = board_set_siren_stub,
    .set_bootkick = cuatro_set_bootkick,
    .read_som_gpio = board_read_som_gpio_stub,
    .set_amp_enabled = cuatro_set_amp_enabled,
};
#elif defined(E2E_BOARD_TRES)
struct board e2e_board = {
    .harness_config = &tres_harness_config,
    .led_GPIO = {GPIOE, GPIOE, GPIOE},
    .led_pin = {4, 3, 2},
    .led_pwm_channels = {0, 0, 0},
    .has_spi = true,
    .has_fan = true,
    .avdd_mV = 1800U,
    .fan_enable_cooldown_time = 3U,
    .init = tres_init,
    .init_bootloader = unused_init_bootloader,
    .enable_can_transceiver = tres_enable_can_transceiver,
    .set_can_mode = tres_set_can_mode,
    .read_voltage_mV = board_read_voltage_mV_stub,
    .read_current_mA = unused_read_current,
    .set_ir_power = board_set_ir_power_stub,
    .set_fan_enabled = tres_set_fan_enabled,
    .set_siren = board_set_siren_stub,
    .set_bootkick = tres_set_bootkick,
    .read_som_gpio = board_read_som_gpio_stub,
    .set_amp_enabled = unused_set_amp_enabled,
};
#elif defined(E2E_BOARD_RED)
struct board e2e_board = {
    .harness_config = &red_harness_config,
    .led_GPIO = {GPIOE, GPIOE, GPIOE},
    .led_pin = {4, 3, 2},
    .led_pwm_channels = {0, 0, 0},
    .has_spi = false,
    .has_fan = false,
    .avdd_mV = 3300U,
    .fan_enable_cooldown_time = 0U,
    .init = red_init,
    .init_bootloader = unused_init_bootloader,
    .enable_can_transceiver = red_enable_can_transceiver,
    .set_can_mode = red_set_can_mode,
    .read_voltage_mV = board_read_voltage_mV_stub,
    .read_current_mA = unused_read_current,
    .set_ir_power = unused_set_ir_power,
    .set_fan_enabled = unused_set_fan_enabled,
    .set_siren = unused_set_siren,
    .set_bootkick = unused_set_bootkick,
    .read_som_gpio = unused_read_som_gpio,
    .set_amp_enabled = unused_set_amp_enabled,
};
#endif
board *current_board = &e2e_board;

// ---- JNA entry point for harness_detect_orientation (B5: now real production code) ----
void jna_detect_harness_orientation(void) {
  harness.status = harness_detect_orientation();
}

// ---- Function stubs ----
void fake_siren_set(bool en) { siren_enabled = en; }
void fake_i2c_siren_set(bool en) { siren_enabled = en; }
// can_init, can_rx, and process_can now come from real board/drivers/fdcan.h (C3)
void led_init(void) {}
void led_set(uint8_t led, bool en) { (void)led; (void)en; }
void pwm_init(TIM_TypeDef *TIM, uint8_t channel) { (void)TIM; (void)channel; }
void pwm_set(TIM_TypeDef *TIM, uint8_t channel, uint8_t percentage) { (void)TIM; (void)channel; (void)percentage; }
void usb_irqhandler(void) {}
void usb_init(void) {}
// spi_init() now comes from real board/drivers/spi.h (llspi stubs in e2e wrapper)
void early_initialization(void) {}
void clock_init(void) {}
void peripherals_init(void) {}
void detect_board_type(void) {
#if defined(E2E_BOARD_CUATRO)
    hw_type = HW_TYPE_CUATRO;
    current_board = &e2e_board;
#elif defined(E2E_BOARD_TRES)
    hw_type = HW_TYPE_TRES;
    current_board = &e2e_board;
#elif defined(E2E_BOARD_RED)
    hw_type = HW_TYPE_RED_PANDA;
    current_board = &e2e_board;
#endif
}
void sound_init(void) {}
void sound_tick(void) {}
void sound_init_dac(void) {}
void init_interrupts(bool en) { (void)en; }
void tick_timer_init(void) {}
void microsecond_timer_init(void) {}
void interrupt_timer_init(void) {}
void gpio_spi_init(void) {}
void disable_interrupts(void) {}
void enable_interrupts(void) {}
static int nvic_reset_call_count;
void NVIC_SystemReset(void) { nvic_reset_call_count++; }

int jna_get_nvic_reset_count(void) { return nvic_reset_call_count; }
void jna_reset_nvic_count(void) { nvic_reset_call_count = 0; }

int jna_get_stop_mode_requested(void) { return stop_mode_requested ? 1 : 0; }

// ---- JNA API: fake register value accessors ----
uint32_t jna_get_reg_GPIOA_MODER(void) { return e2e_GPIOA.MODER; }
uint32_t jna_get_reg_GPIOB_MODER(void) { return e2e_GPIOB.MODER; }
uint32_t jna_get_reg_GPIOC_MODER(void) { return e2e_GPIOC.MODER; }
uint32_t jna_get_reg_GPIOD_MODER(void) { return e2e_GPIOD.MODER; }
uint32_t jna_get_reg_GPIOE_MODER(void) { return e2e_GPIOE.MODER; }
uint32_t jna_get_reg_GPIOF_MODER(void) { return e2e_GPIOF.MODER; }
uint32_t jna_get_reg_GPIOG_MODER(void) { return e2e_GPIOG.MODER; }
uint32_t jna_get_reg_GPIOA_ODR(void)   { return e2e_GPIOA.ODR; }
uint32_t jna_get_reg_GPIOB_ODR(void)   { return e2e_GPIOB.ODR; }
uint32_t jna_get_reg_GPIOC_ODR(void)   { return e2e_GPIOC.ODR; }
uint32_t jna_get_reg_GPIOD_ODR(void)   { return e2e_GPIOD.ODR; }
uint32_t jna_get_reg_GPIOB_PUPDR(void)  { return e2e_GPIOB.PUPDR; }
uint32_t jna_get_reg_GPIOE_ODR(void)   { return e2e_GPIOE.ODR; }
uint32_t jna_get_reg_GPIOF_ODR(void)   { return e2e_GPIOF.ODR; }
uint32_t jna_get_reg_GPIOG_ODR(void)   { return e2e_GPIOG.ODR; }
// GPIO OTYPER (output type)
uint32_t jna_get_reg_GPIOA_OTYPER(void) { return e2e_GPIOA.OTYPER; }
uint32_t jna_get_reg_GPIOB_OTYPER(void) { return e2e_GPIOB.OTYPER; }
uint32_t jna_get_reg_GPIOC_OTYPER(void) { return e2e_GPIOC.OTYPER; }
uint32_t jna_get_reg_GPIOD_OTYPER(void) { return e2e_GPIOD.OTYPER; }
uint32_t jna_get_reg_GPIOE_OTYPER(void) { return e2e_GPIOE.OTYPER; }
uint32_t jna_get_reg_GPIOF_OTYPER(void) { return e2e_GPIOF.OTYPER; }
uint32_t jna_get_reg_GPIOG_OTYPER(void) { return e2e_GPIOG.OTYPER; }
// GPIO OSPEEDR (output speed)
uint32_t jna_get_reg_GPIOA_OSPEEDR(void) { return e2e_GPIOA.OSPEEDR; }
uint32_t jna_get_reg_GPIOB_OSPEEDR(void) { return e2e_GPIOB.OSPEEDR; }
uint32_t jna_get_reg_GPIOC_OSPEEDR(void) { return e2e_GPIOC.OSPEEDR; }
uint32_t jna_get_reg_GPIOD_OSPEEDR(void) { return e2e_GPIOD.OSPEEDR; }
uint32_t jna_get_reg_GPIOE_OSPEEDR(void) { return e2e_GPIOE.OSPEEDR; }
uint32_t jna_get_reg_GPIOF_OSPEEDR(void) { return e2e_GPIOF.OSPEEDR; }
uint32_t jna_get_reg_GPIOG_OSPEEDR(void) { return e2e_GPIOG.OSPEEDR; }
// GPIO PUPDR (pull-up/pull-down) — full set
uint32_t jna_get_reg_GPIOA_PUPDR(void)  { return e2e_GPIOA.PUPDR; }
uint32_t jna_get_reg_GPIOC_PUPDR(void)  { return e2e_GPIOC.PUPDR; }
uint32_t jna_get_reg_GPIOD_PUPDR(void)  { return e2e_GPIOD.PUPDR; }
uint32_t jna_get_reg_GPIOE_PUPDR(void)  { return e2e_GPIOE.PUPDR; }
uint32_t jna_get_reg_GPIOF_PUPDR(void)  { return e2e_GPIOF.PUPDR; }
uint32_t jna_get_reg_GPIOG_PUPDR(void)  { return e2e_GPIOG.PUPDR; }
uint32_t jna_get_reg_ADC1_CR(void)     { return e2e_ADC1.CR; }
uint32_t jna_get_reg_ADC2_CR(void)     { return e2e_ADC2.CR; }
uint32_t jna_get_reg_RCC_CR(void)          { return e2e_RCC.CR; }
uint32_t jna_get_reg_RCC_AHB2LPENR(void)   { return e2e_RCC.AHB2LPENR; }
uint32_t jna_get_reg_RCC_AHB3LPENR(void)   { return e2e_RCC.AHB3LPENR; }
uint32_t jna_get_reg_RCC_AHB4LPENR(void)   { return e2e_RCC.AHB4LPENR; }
uint32_t jna_get_reg_SYSCFG_EXTICR0(void)  { return e2e_SYSCFG.EXTICR[0]; }
uint32_t jna_get_reg_SYSCFG_EXTICR1(void)  { return e2e_SYSCFG.EXTICR[1]; }
uint32_t jna_get_reg_SYSCFG_EXTICR2(void)  { return e2e_SYSCFG.EXTICR[2]; }
uint32_t jna_get_reg_SYSCFG_EXTICR3(void)  { return e2e_SYSCFG.EXTICR[3]; }
uint32_t jna_get_reg_EXTI_IMR1(void)       { return e2e_EXTI.IMR1; }
uint32_t jna_get_reg_EXTI_RTSR1(void)      { return e2e_EXTI.RTSR1; }
uint32_t jna_get_reg_EXTI_FTSR1(void)      { return e2e_EXTI.FTSR1; }
uint32_t jna_get_reg_EXTI_PR1(void)        { return e2e_EXTI.PR1; }
uint32_t jna_get_reg_PWR_CR1(void)         { return e2e_PWR.CR1; }
uint32_t jna_get_reg_PWR_CR3(void)         { return e2e_PWR.CR3; }
uint32_t jna_get_reg_PWR_CPUCR(void)       { return e2e_PWR.CPUCR; }
uint32_t jna_get_reg_SCB_SCR(void)         { return e2e_SCB.SCR; }
uint32_t jna_get_reg_NVIC_ICER0(void)      { return e2e_NVIC.ICER[0]; }
uint32_t jna_get_reg_NVIC_ICER7(void)      { return e2e_NVIC.ICER[7]; }
uint32_t jna_get_reg_NVIC_ICPR0(void)      { return e2e_NVIC.ICPR[0]; }
uint32_t jna_get_reg_NVIC_ICPR7(void)      { return e2e_NVIC.ICPR[7]; }

// CMSIS intrinsic tracking
int jna_get_irq_disabled(void)             { return irq_disabled ? 1 : 0; }
int jna_get_dsb_called(void)               { return dsb_called ? 1 : 0; }
int jna_get_isb_called(void)               { return isb_called ? 1 : 0; }
int jna_get_wfi_entered(void)              { return wfi_entered ? 1 : 0; }

void jna_reset_stop_mode_tracking(void) {
    stop_mode_requested = false;
    irq_disabled = false;
    dsb_called = false;
    isb_called = false;
    wfi_entered = false;
    e2e_voltage_mV = 12000;
    e2e_current_mA = 0;
    // Zero all fake register instances
    e2e_GPIOA = (GPIO_TypeDef){0};   e2e_GPIOB = (GPIO_TypeDef){0};
    e2e_GPIOC = (GPIO_TypeDef){0};   e2e_GPIOD = (GPIO_TypeDef){0};
    e2e_GPIOE = (GPIO_TypeDef){0};   e2e_GPIOF = (GPIO_TypeDef){0};
    e2e_GPIOG = (GPIO_TypeDef){0};
    e2e_ADC1 = (struct e2e_ADC_Regs){0};     e2e_ADC2 = (struct e2e_ADC_Regs){0};
    e2e_RCC  = (struct e2e_RCC_Regs){0};     e2e_SYSCFG = (struct e2e_SYSCFG_Regs){0};
    e2e_EXTI = (struct e2e_EXTI_Regs){0};    e2e_PWR = (struct e2e_PWR_Regs){0};
    e2e_NVIC = (struct e2e_NVIC_Regs){0};    e2e_SCB = (struct e2e_SCB_Regs){0};
}

// Stubs for can_comms functions (real can_comms.h calls these)
void can_tx_comms_resume_usb(void) {}
// can_tx_comms_resume_spi now comes from real board/drivers/spi.h

// fan state + llfan_init stub (fan_init from board/drivers/fan.h calls this)
void llfan_init(void) {}
struct fan_state_t fan_state;
#include "board/drivers/fan.h"

// ADC
typedef struct { uint32_t x; } ADC_TypeDef;
ADC_TypeDef adc1_inst;
#define ADC1 (&adc1_inst)
void adc_init(ADC_TypeDef *adc) { (void)adc; }

// production harness code — included verbatim from board/drivers/harness.h

#define SCB_SCR_SLEEPDEEP_Msk 0x4U
#define SCB_SCR_SLEEPONEXIT_Msk 0x2U

// UART helpers
bool get_char(uart_ring *q, char *elem) {
    if ((q == NULL) || (q->w_ptr_rx == q->r_ptr_rx)) return false;
    if (elem != NULL) *elem = (char)q->elems_rx[q->r_ptr_rx];
    q->r_ptr_rx = (q->r_ptr_rx + 1U) % q->rx_fifo_size;
    return true;
}
int put_char(uart_ring *q, char c) {
    if ((q == NULL) || (q->elems_tx == ((void *)0))) return 0;
    uint32_t next_w = (q->w_ptr_tx + 1U) % q->tx_fifo_size;
    if (next_w == q->r_ptr_tx) return 0; // full
    q->elems_tx[q->w_ptr_tx] = (uint8_t)c;
    q->w_ptr_tx = next_w;
    return 1;
}

// ---- Real firmware headers ----
#include "board/health.h"
#include "board/sys/faults.h"

// ---- Watchdog (real production code from board/drivers/simple_watchdog.h) ----
#include "board/drivers/simple_watchdog.h"

#include "board/libc.h"
// interrupts.h now included earlier (before interrupts[] array) for real REGISTER_INTERRUPT (C3)

// CMSIS intrinsics (must be BEFORE board/main.c — main.c power_save path uses __WFI)
static void e2e_nvic_enable_irq(int irqn) {
    irq_enable_call_count++;
    // Track per-bus enable (mapping IRQn → bus number)
    if (irqn == FDCAN1_IT0_IRQn || irqn == FDCAN1_IT1_IRQn) last_irq_enabled_bus = 0;
    else if (irqn == FDCAN2_IT0_IRQn || irqn == FDCAN2_IT1_IRQn) last_irq_enabled_bus = 1;
    else if (irqn == FDCAN3_IT0_IRQn || irqn == FDCAN3_IT1_IRQn) last_irq_enabled_bus = 2;
}
void __disable_irq(void) { irq_disabled = true; }
void __enable_irq(void) {}
void __DSB(void) { dsb_called = true; }
void __ISB(void) { isb_called = true; }
void __WFI(void) { wfi_entered = true; }

// ---- FULL board/main.c ----
// CMSIS register macros (must be before main.c for power_saving.h's enter_stop_mode)
#undef ADC1
#undef ADC2
#define ADC1 (&e2e_ADC1)
#define ADC2 (&e2e_ADC2)

#undef RCC
#define RCC (&e2e_RCC)
#undef SYSCFG
#define SYSCFG (&e2e_SYSCFG)
#undef EXTI
#define EXTI (&e2e_EXTI)
#undef PWR
#define PWR (&e2e_PWR)
#undef NVIC
#define NVIC (&e2e_NVIC)

#undef SCB
#define SCB ((struct e2e_SCB_Regs *)&e2e_SCB)
#define SCB_SCR_SLEEPDEEP_Msk 0x4U

// Bit definitions (matching stm32h7xx.h)
#define ADC_CR_ADEN           (0x1UL << 0U)
#define ADC_CR_DEEPPWD        (0x1UL << 29U)
#define RCC_CR_HSI48ON        (0x1UL << 12U)
#define RCC_AHB2LPENR_SRAM1LPEN  (0x1UL << 29U)
#define RCC_AHB2LPENR_SRAM2LPEN  (0x1UL << 30U)
#define RCC_AHB4LPENR_SRAM4LPEN  (0x1UL << 29U)
#define RCC_AHB3LPENR_AXISRAMLPEN  (0x1UL << 31U)
#define SYSCFG_EXTICR1_EXTI1_PA   ((uint32_t)0x00000000)
#define SYSCFG_EXTICR2_EXTI4_PC   ((uint32_t)0x00000002)
#define SYSCFG_EXTICR2_EXTI5_PB   ((uint32_t)0x00000010)
#define SYSCFG_EXTICR3_EXTI8_PB   ((uint32_t)0x00000001)
#define SYSCFG_EXTICR4_EXTI12_PD  ((uint32_t)0x00000003)
#define PWR_CPUCR_PDDS_D1     (0x1UL << 0U)
#define PWR_CPUCR_PDDS_D2     (0x1UL << 1U)
#define PWR_CPUCR_PDDS_D3     (0x1UL << 2U)
#define PWR_CR1_SVOS          (0x3UL << 14U)
#define PWR_CR1_SVOS_0        (0x1UL << 14U)
#define PWR_CR1_FLPS          (0x1UL << 9U)
#define EXTI1_IRQn        7
#define EXTI4_IRQn        10
#define EXTI9_5_IRQn      23
#define EXTI15_10_IRQn    40
#define NVIC_EnableIRQ(x) e2e_nvic_enable_irq(x)

// ---- Real FDCAN hardware layer (C3: de-stubbed llfdcan.h) ----
// Must be included BEFORE main.c because main.c → fdcan.h → calls llcan_* functions
#include "board/stm32h7/llfdcan.h"

#include "board/main.c"

// ---- Real bootkick FSM from board/drivers/bootkick.h ----
// Static locals promoted to e2e_* file-scope variables via #ifdef E2E_TEST.
// bootkick_reset_triggered is already a real global.
#include "board/drivers/bootkick.h"

// JNA accessors for promoted state (static locals in production code)
int jna_get_bootkick_state(void)            { return (int)e2e_boot_state; }
int jna_get_bootkick_reset_triggered(void)   { return (int)bootkick_reset_triggered; }
int jna_get_bootkick_waiting_countdown(void) { return (int)e2e_waiting_to_boot_countdown; }
int jna_get_bootkick_reset_countdown(void)   { return (int)e2e_boot_reset_countdown; }

void jna_reset_bootkick(void) {
  e2e_boot_state = BOOT_BOOTKICK;
  e2e_bootkick_ign_prev = false;
  e2e_bootkick_harness_status_prev = HARNESS_STATUS_NC;
  e2e_bootkick_last_serial_ptr = 0;
  e2e_waiting_to_boot_countdown = 0;
  e2e_boot_reset_countdown = 0;
  bootkick_reset_triggered = false;
  // Default ignition OFF: SBU1 (GPIOC.4) and SBU2 (GPIOA.1) IDR bits high
  // (harness_check_ignition uses active-low: IDR=1 → ignition OFF)
  e2e_GPIOC.IDR |= (1U << 4);
  e2e_GPIOA.IDR |= (1U << 1);
#if defined(E2E_BOARD_TRES)
  e2e_GPIOB.IDR &= ~(1U << 1);
#elif !defined(E2E_BOARD_RED)
  e2e_GPIOC.IDR |= (1U << 3);
#endif
}

// ---- Harness control (e2e-specific, not in generated code) ----
// Sets ignition line by writing GPIO IDR bits for both SBU1 and SBU2.
// harness_check_ignition() reads these via get_gpio_input() (active-low).
void jna_set_ignition_line(uint8_t val) {
  bool ignition_on = (val != 0U);
  if (ignition_on) {
    e2e_GPIOC.IDR &= ~(1U << 4);   // SBU1: low → ignition ON
    e2e_GPIOA.IDR &= ~(1U << 1);   // SBU2: low → ignition ON
  } else {
    e2e_GPIOC.IDR |= (1U << 4);    // SBU1: high → ignition OFF
    e2e_GPIOA.IDR |= (1U << 1);    // SBU2: high → ignition OFF
  }
}
uint8_t jna_get_ignition_can(void)       { return ignition_can ? 1U : 0U; }
void jna_set_ignition_can(uint8_t val)   { ignition_can = (val != 0U); ignition_can_cnt = 0U; }
void jna_set_harness_status(uint8_t val) { harness.status = val; }
uint8_t jna_get_harness_status(void)     { return harness.status; }
void jna_set_sbu1_voltage_mV(int val)    { harness.sbu1_voltage_mV = (uint16_t)val; }
void jna_set_sbu2_voltage_mV(int val)    { harness.sbu2_voltage_mV = (uint16_t)val; }
void jna_set_relay_driven(uint8_t val)   { harness.relay_driven = (val != 0U); }
void jna_set_som_uart_wptr(uint16_t val) { uart_ring_som_debug.w_ptr_tx = val; }

// ---- Override hardware registers for e2e testing ----
// Must come AFTER board/main.c (which may define its own macros)
#undef GPIOA
#undef GPIOB
#undef GPIOC
#undef GPIOD
#undef GPIOE
#undef GPIOF
#undef GPIOG
#define GPIOA (&e2e_GPIOA)
#define GPIOB (&e2e_GPIOB)
#define GPIOC (&e2e_GPIOC)
#define GPIOD (&e2e_GPIOD)
#define GPIOE (&e2e_GPIOE)
#define GPIOF (&e2e_GPIOF)
#define GPIOG (&e2e_GPIOG)

// Forward declarations
void register_set(volatile uint32_t *addr, uint32_t val, uint32_t mask);
void register_clear_bits(volatile uint32_t *addr, uint32_t mask);
void register_set_bits(volatile uint32_t *addr, uint32_t val);

// enter_stop_mode is provided by real board/sys/power_saving.h.
// Although it is static, it's accessible from jna_process_stop_mode() because
// libpanda.c textually includes board/main.c which includes power_saving.h.

// Simulates the main loop's stop_mode_requested check.
void jna_process_stop_mode(void) {
    if (stop_mode_requested) {
        enter_stop_mode();
    }
}

// Simulates the main loop's WFI idle path (board/main.c:377-385).
// Tests the non-CUATRO __WFI() light sleep path and CUATRO with SOM GPIO high.
// The CUATRO enter_stop_mode() deep sleep path is covered by deep_sleep.feature.
void jna_process_wfi_idle(void) {
    if (power_save_enabled) {
        // CUATRO deep sleep path is already tested — skip it here
        if ((hw_type == HW_TYPE_CUATRO) && !current_board->read_som_gpio()) {
            return;
        }
        // Pre-set SCB_SCR so we can verify the SLEEPDEEP clear at main.c:384
        SCB->SCR = SCB_SCR_SLEEPDEEP_Msk;
        __WFI();
        SCB->SCR &= ~SCB_SCR_SLEEPDEEP_Msk;
    }
}

// Real board_read_som_gpio (after GPIO macro overrides)
bool board_read_som_gpio_stub(void) {
#if defined(E2E_BOARD_TRES)
    return get_gpio_input(GPIOB, 1);
#elif defined(E2E_BOARD_RED)
    return false;
#else
    return !get_gpio_input(GPIOC, 3);
#endif
}

// Siren stub (after GPIO macro overrides)
static bool siren_was_active;
void board_set_siren_stub(bool en) {
    if (en) siren_was_active = true;
    set_gpio_output(GPIOB, 14, en);
}
int jna_get_siren_active(void) {
    // sirenActive replaced by stopModeRegs.gpioBOdr bit14 — return value from GPIO
    return (GPIOB->ODR & (1UL << 14)) ? 1 : 0;
}
int jna_get_siren_was_active(void) {
    return siren_was_active ? 1 : 0;
}

// Simulate main.c tick handler — applies siren_enabled flag to GPIO
void jna_tick_siren(void) {
    current_board->set_siren(siren_enabled);
}

// ---- can_init, can_rx, process_can, can_clear_send now come from real board/drivers/fdcan.h (C3) ----
// Included via board/main.c → #include "board/drivers/fdcan.h"

// Override TIM1/TIM8 with fake instances for register-level verification
#undef TIM1
#undef TIM8
#define TIM1 ((e2e_TIM_TypeDef *)&fake_TIM1)
#define TIM8 ((e2e_TIM_TypeDef *)&fake_TIM8)

// ---- clock_source_set_timer_params from board/drivers/clock_source.h ----
// Uses fake TIM1/TIM8 instances defined above.
#include "board/drivers/clock_source.h"

// ---- update_can_health_pkt from board/drivers/can_health_pkt.h (B4 — shared with production) ----
#include "board/drivers/can_health_pkt.h"

// ---- fan_set_power from board/drivers/fan.h (already included above) ----

// ---- JNA API: goes through comms_control_handler → set_safety_mode() ----
static uint8_t jna_resp[0x40];
static int jna_resp_len;

bool relay_malfunction;
void jna_set_relay_malfunction(int val) { relay_malfunction = (val != 0); }
int jna_get_relay_malfunction(void) { return (int)relay_malfunction; }
uint32_t jna_get_faults(void) { return faults; }
void jna_reset_faults(void) { faults = 0U; }
uint32_t jna_get_fault_status(void) { return (uint32_t)fault_status; }
void jna_trigger_fault(uint32_t fault) { fault_occurred(fault); }
void jna_recover_fault(uint32_t fault) { fault_recovered(fault); }
void jna_call_tick_handler(void) { TICK_TIMER->SR = 1U; tick_handler(); }

#ifdef __cplusplus
extern "C" {
#endif

void jna_control_write(uint8_t request, uint16_t param1, uint16_t param2, uint16_t length) {
    ControlPacket_t req = { .request = request, .param1 = param1, .param2 = param2, .length = length };
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
    // can_set_checksum required: process_can checks it before writing to FDCAN registers
    can_set_checksum(&pkt);

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
                     uint8_t *out_returned, uint8_t *out_data, uint8_t *out_len) {
    CANPacket_t pkt;
    if (can_pop(&can_rx_q, &pkt)) {
        *out_addr = pkt.addr;
        *out_bus = pkt.bus;
        *out_rejected = pkt.rejected;
        *out_returned = pkt.returned;
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
bool jna_can_pop_tx(int queue_idx, uint32_t *out_addr, uint8_t *out_returned, uint8_t *out_data, uint8_t *out_len) {
    if ((queue_idx < 0) || (queue_idx >= PANDA_CAN_CNT)) {
        return false;
    }

    CANPacket_t pkt;
    if (can_pop(can_queues[queue_idx], &pkt)) {
        *out_addr = pkt.addr;
        *out_returned = pkt.returned;
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

// ---- JNA API: FDCAN register inspection ----
void jna_reset_fdcan(void) {
    // BSS + data-segment init + can_init() handle all reset.
    // Kept as empty shell for JNA interface compatibility.
}

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
uint32_t jna_get_fdcan_txfqs(int can_number) {
    if ((can_number < 0) || (can_number >= 3)) return 0;
    return fake_fdcan[can_number].TXFQS;
}
uint32_t jna_get_fdcan_txbar(int can_number) {
    if ((can_number < 0) || (can_number >= 3)) return 0;
    return fake_fdcan[can_number].TXBAR;
}
void jna_set_fdcan_psr(int can_number, uint32_t val) {
    if ((can_number >= 0) && (can_number < 3)) fake_fdcan[can_number].PSR = val;
}
void jna_set_fdcan_ecr(int can_number, uint32_t val) {
    if ((can_number >= 0) && (can_number < 3)) fake_fdcan[can_number].ECR = val;
}

// ---- JNA API: Manual interrupt-driven CAN processing (C3) ----
// Call process_can to simulate TX interrupt: drains can_queues[] → FDCAN registers → can_rx_q echo
void jna_process_can(int can_number) {
    if ((can_number >= 0) && (can_number < 3)) process_can((uint8_t)can_number);
}
// Call can_rx to simulate RX interrupt: reads FDCAN FIFO → can_rx_q
void jna_can_rx(int can_number) {
    if ((can_number >= 0) && (can_number < 3)) can_rx((uint8_t)can_number);
}

// ---- JNA API: Heartbeat state inspection ----
uint32_t jna_get_heartbeat_counter(void) {
    return heartbeat_counter;
}
void jna_set_heartbeat_counter(uint32_t val) {
    heartbeat_counter = val;
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

// ---- JNA API: Safety state inspection ----
int jna_get_controls_allowed(void) {
    return controls_allowed ? 1 : 0;
}
void jna_set_controls_allowed(int val) {
    controls_allowed = (val != 0);
}
int jna_get_current_safety_mode(void) {
    return (int)current_safety_mode;
}
int jna_get_siren_countdown(void) {
    return (int)siren_countdown;
}
int jna_get_siren_enabled(void) {
    return siren_enabled ? 1 : 0;
}

// ---- JNA API: safety_mode_cnt (declared in opendbc/safety/safety.h) ----
uint32_t jna_get_safety_mode_cnt(void) {
    return safety_mode_cnt;
}
void jna_set_safety_mode_cnt(uint32_t val) {
    safety_mode_cnt = val;
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
void jna_reset_siren(void) {
    siren_enabled = false;
    siren_was_active = false;
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
// set_ir_power tracking
// set_ir_power tracking — call count removed (redundant with TIM1.CCR1 register assertion).
// ir_power_values[0] stores the last set value for PowerSaveTracking.irPowerValue.
int jna_get_ir_power_value_at(int index) {
    if ((index < 0) || (index >= MAX_IR_POWER_CALLS)) return -1;
    return (int)ir_power_values[index];
}

// fan_power — direct read from fan_state.power (set by real fan_set_power)
int jna_get_fan_power(void) { return (int)fan_state.power; }

// fan_cooldown_counter — read from fan_state.cooldown_counter (managed by fan_tick)
int jna_get_fan_cooldown_counter(void) { return (int)fan_state.cooldown_counter; }

void jna_reset_power_save_tracking(void) {
    power_save_enabled = false;
    irq_enable_call_count = 0;
    irq_disable_call_count = 0;
    last_irq_enabled_bus = -1;
    last_irq_disabled_bus[0] = -1;
    last_irq_disabled_bus[1] = -1;
    last_irq_disabled_bus[2] = -1;
    nvic_disable_irq_count = 0;
}

int jna_get_nvic_disable_irq_count(void) { return nvic_disable_irq_count; }
int jna_get_nvic_disable_irq_at(int index) {
    if ((index < 0) || (index >= nvic_disable_irq_count)) return -1;
    return nvic_disabled_irqs[index];
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

// ---- JNA API: CAN comms buffer reset (comms_can_reset) ----
void jna_comms_can_reset(void) {
    comms_can_reset();
}

// ---- JNA API: USB endpoint simulation (exercises comms_can_read/write via USB path) ----
// usb_sim_ep3_out() → comms_can_write() — simulates host sending CAN data on USB ep3 OUT.
void jna_usb_ep3_out(const uint8_t *data, uint32_t len) {
    usb_sim_ep3_out(data, len);
}

// usb_sim_ep1_in() → comms_can_read() — simulates host reading CAN data from USB ep1 IN.
// Returns number of bytes read; stores in internal buffer accessible via jna_usb_ep1_in_*.
int jna_usb_ep1_in(uint8_t *out_data, uint32_t max_len) {
    return usb_sim_ep1_in(out_data, max_len);
}

int jna_usb_ep1_in_get_len(void) {
    return usb_sim_ep1_in_get_len();
}

int jna_usb_ep1_in_get_byte(int index) {
    return usb_sim_ep1_in_get_byte(index);
}

// ---- JNA API: CAN queue state manipulation for coverage testing ----
// queue_idx: 0=rx_q, 1=tx1_q, 2=tx2_q, 3=tx3_q
static can_ring *get_can_queue(int queue_idx) {
    if (queue_idx == 0) {
        return &can_rx_q;
    } else if ((queue_idx >= 1) && (queue_idx <= 3)) {
        return can_queues[queue_idx - 1];
    }
    return ((void *)0);
}

void jna_set_can_queue_state(int queue_idx, uint32_t w_ptr, uint32_t r_ptr) {
    can_ring *q = get_can_queue(queue_idx);
    if (q != ((void *)0)) {
        q->w_ptr = w_ptr;
        q->r_ptr = r_ptr;
    }
}

void jna_get_can_queue_state(int queue_idx, uint32_t *out_w_ptr, uint32_t *out_r_ptr, uint32_t *out_fifo_size) {
    can_ring *q = get_can_queue(queue_idx);
    if (q != ((void *)0)) {
        *out_w_ptr = q->w_ptr;
        *out_r_ptr = q->r_ptr;
        *out_fifo_size = q->fifo_size;
    } else {
        *out_w_ptr = 0U;
        *out_r_ptr = 0U;
        *out_fifo_size = 0U;
    }
}

// Direct can_push without safety hook — for testing queue-full behavior
bool jna_can_push_direct(int queue_idx, uint32_t addr, uint8_t bus, const uint8_t *data, uint8_t len) {
    can_ring *q = get_can_queue(queue_idx);
    if (q == ((void *)0)) {
        return false;
    }
    CANPacket_t pkt = {0};
    pkt.addr = addr;
    pkt.bus = bus;
    pkt.extended = (addr > 0x7FFU) ? 1U : 0U;
    pkt.data_len_code = len;
    if ((len > 0U) && (len <= 64U)) {
        (void)memcpy(pkt.data, data, len);
    }
    return can_push(q, &pkt);
}

// Direct can_pop for coverage testing
bool jna_can_pop_direct(int queue_idx, uint32_t *out_addr, uint8_t *out_bus,
                         uint8_t *out_data, uint8_t *out_len) {
    can_ring *q = get_can_queue(queue_idx);
    if (q == ((void *)0)) {
        return false;
    }
    CANPacket_t pkt;
    if (can_pop(q, &pkt)) {
        *out_addr = pkt.addr;
        *out_bus = pkt.bus;
        *out_len = pkt.data_len_code;
        if (pkt.data_len_code > 0U) {
            (void)memcpy(out_data, pkt.data, pkt.data_len_code);
        }
        return true;
    }
    return false;
}

// Expose can_slots_empty for wrap-around calculation coverage
int jna_can_slots_empty(int queue_idx) {
    can_ring *q = get_can_queue(queue_idx);
    if (q == ((void *)0)) {
        return 0;
    }
    return (int)can_slots_empty(q);
}

// ---- JNA API: comms_endpoint2_write (SPI + USB endpoint 2 write path) ----
// Calls real comms_endpoint2_write from board/main_comms.h.
// Captures written data from the ring's tx buffer for verification.
static uint8_t endpoint2_capture_buf[256];
static int endpoint2_capture_len;

void jna_comms_endpoint2_write(const uint8_t *data, uint32_t len) {
    uart_ring *ur = get_ring_by_number(data[0]);
    endpoint2_capture_len = 0;
    if ((ur != NULL) && (len > 1U) && ((data[0] < 2U) || (data[0] >= 4U))) {
        uint32_t start_w = ur->w_ptr_tx;
        comms_endpoint2_write(data, len);
        uint32_t end_w = ur->w_ptr_tx;
        for (uint32_t i = start_w; i != end_w; i = (i + 1U) % ur->tx_fifo_size) {
            if (endpoint2_capture_len < 256) {
                endpoint2_capture_buf[endpoint2_capture_len++] = ur->elems_tx[i];
            }
        }
    } else {
        comms_endpoint2_write(data, len);
    }
}
int jna_get_endpoint2_debug_len(void) { return endpoint2_capture_len; }
int jna_get_endpoint2_debug_byte(int index) {
    if ((index < 0) || (index >= endpoint2_capture_len)) return 0;
    return (int)endpoint2_capture_buf[index];
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

// ---- JNA API: Clock source TIM registers ----
// After clock_source_set_timer_params(param1, param2), the fake TIM
// registers are set to computed values. Expose them for verification.
uint32_t jna_get_TIM1_CCR1(void) { return fake_TIM1.CCR1; }
uint32_t jna_get_ir_pwm(void)               { return fake_TIM1.CCR1; }
uint32_t jna_get_TIM1_CCR2(void) { return fake_TIM1.CCR2; }
uint32_t jna_get_TIM8_CCR3(void) { return fake_TIM8.CCR3; }
uint32_t jna_get_TIM1_ARR(void)  { return fake_TIM1.ARR; }
uint32_t jna_get_TIM1_CCR4(void) { return fake_TIM1.CCR4; }

// TIM1 extended register getters
uint32_t jna_get_TIM1_PSC(void)   { return fake_TIM1.PSC; }
uint32_t jna_get_TIM1_SMCR(void)  { return fake_TIM1.SMCR; }
uint32_t jna_get_TIM1_BDTR(void)  { return fake_TIM1.BDTR; }
uint32_t jna_get_TIM1_CR1(void)   { return fake_TIM1.CR1; }
uint32_t jna_get_TIM1_CR2(void)   { return fake_TIM1.CR2; }
uint32_t jna_get_TIM1_CCMR1(void) { return fake_TIM1.CCMR1; }
uint32_t jna_get_TIM1_CCMR2(void) { return fake_TIM1.CCMR2; }
uint32_t jna_get_TIM1_CCER(void)  { return fake_TIM1.CCER; }
uint32_t jna_get_TIM1_DIER(void)  { return fake_TIM1.DIER; }

// TIM8 extended register getters
uint32_t jna_get_TIM8_PSC(void)   { return fake_TIM8.PSC; }
uint32_t jna_get_TIM8_ARR(void)   { return fake_TIM8.ARR; }
uint32_t jna_get_TIM8_SMCR(void)  { return fake_TIM8.SMCR; }
uint32_t jna_get_TIM8_BDTR(void)  { return fake_TIM8.BDTR; }
uint32_t jna_get_TIM8_CR1(void)   { return fake_TIM8.CR1; }
uint32_t jna_get_TIM8_CCMR2(void) { return fake_TIM8.CCMR2; }
uint32_t jna_get_TIM8_CCER(void)  { return fake_TIM8.CCER; }

// GPIO AFR register getters
uint32_t jna_get_reg_GPIOA_AFR0(void) { return e2e_GPIOA.AFR[0]; }
uint32_t jna_get_reg_GPIOA_AFR1(void) { return e2e_GPIOA.AFR[1]; }
uint32_t jna_get_reg_GPIOB_AFR0(void) { return e2e_GPIOB.AFR[0]; }
uint32_t jna_get_reg_GPIOB_AFR1(void) { return e2e_GPIOB.AFR[1]; }
uint32_t jna_get_reg_GPIOC_AFR0(void) { return e2e_GPIOC.AFR[0]; }
uint32_t jna_get_reg_GPIOC_AFR1(void) { return e2e_GPIOC.AFR[1]; }
uint32_t jna_get_reg_GPIOD_AFR0(void) { return e2e_GPIOD.AFR[0]; }
uint32_t jna_get_reg_GPIOD_AFR1(void) { return e2e_GPIOD.AFR[1]; }
uint32_t jna_get_reg_GPIOE_AFR0(void) { return e2e_GPIOE.AFR[0]; }
uint32_t jna_get_reg_GPIOE_AFR1(void) { return e2e_GPIOE.AFR[1]; }

// ---- JNA API: clock_source_init() ----
void jna_clock_source_init(int enable_channel1) {
    clock_source_init(enable_channel1 != 0);
}

void jna_reset_TIM_regs(void) {
    fake_TIM1 = (e2e_TIM_TypeDef){0};
    fake_TIM8 = (e2e_TIM_TypeDef){0};
}

// ---- JNA API: board_init() ----
void jna_board_init(void) {
    // Reset GPIO registers to clean state before init
    e2e_GPIOA = (GPIO_TypeDef){0};   e2e_GPIOB = (GPIO_TypeDef){0};
    e2e_GPIOC = (GPIO_TypeDef){0};   e2e_GPIOD = (GPIO_TypeDef){0};
    e2e_GPIOE = (GPIO_TypeDef){0};   e2e_GPIOF = (GPIO_TypeDef){0};
    e2e_GPIOG = (GPIO_TypeDef){0};
    // Reset PWR (used by tres_init USB LDO enable)
    e2e_PWR = (struct e2e_PWR_Regs){0};
    // Pre-set USB33RDY so tres_init's spin-wait doesn't hang
    e2e_PWR.CR3 = PWR_CR3_USB33RDY;
    // Reset TIM registers (used by clock_source_init inside init)
    jna_reset_TIM_regs();
    // Reset NVIC tracking (used by clock_source_init)
    jna_reset_nvic_count();
    // Call the board init function
    current_board->init();
}

// ---- JNA API: Setup + response buffer inspection ----
void jna_set_microsecond_timer(uint32_t val) { MICROSECOND_TIMER->CNT = val; }
void jna_reset_microsecond_timer(void) { MICROSECOND_TIMER->CNT = 0; }
void jna_set_mcu_uid(const char *hex, size_t hex_len) {
    for (size_t i = 0U; (i < 12U) && (i < hex_len); i++) {
        fake_uid[i] = (uint8_t)hex[i];
    }
}
void jna_reset_mcu_uid(void) { for (size_t i = 0U; i < 12U; i++) { fake_uid[i] = 0U; } }
void jna_set_interrupt_call_rate(uint8_t index, uint32_t val) {
    if (index < NUM_INTERRUPTS) { interrupts[index].call_rate = val; }
}
void jna_reset_interrupts(void) {
    for (uint8_t i = 0U; i < NUM_INTERRUPTS; i++) { interrupts[i].call_rate = 0U; }
}
// Verify REGISTER_INTERRUPT registration (C3: real macro populates interrupts[])
int jna_get_interrupt_handler(int irqn) {
    if ((irqn < 0) || (irqn >= NUM_INTERRUPTS)) return 0;
    return interrupts[irqn].handler != NULL ? 1 : 0;
}
int jna_get_interrupt_call_rate_max(int irqn) {
    if ((irqn < 0) || (irqn >= NUM_INTERRUPTS)) return 0;
    return (int)interrupts[irqn].max_call_rate;
}
void jna_set_serial(const char *hex, size_t hex_len) {
    for (size_t i = 0U; (i < 16U) && (i < hex_len); i++) { fake_serial[i] = (uint8_t)hex[i]; }
}
void jna_reset_serial(void) { for (size_t i = 0U; i < 16U; i++) { fake_serial[i] = 0U; } }
void jna_set_provision(const char *hex, size_t hex_len) {
    for (size_t i = 0U; (i < 32U) && (i < hex_len); i++) { fake_provision[i] = (uint8_t)hex[i]; }
}
void jna_reset_provision(void) { for (size_t i = 0U; i < 32U; i++) { fake_provision[i] = 0U; } }
void jna_set_app_code_len(int len) { _app_start[0] = len; }
void jna_set_signature_chunk(int chunk, const char *hex, size_t hex_len) {
    uint8_t *sig = (uint8_t*)_app_start + _app_start[0] + (size_t)chunk * 64U;
    for (size_t i = 0U; (i < 64U) && (i < hex_len); i++) { sig[i] = (uint8_t)hex[i]; }
}
void jna_reset_signature(void) { _app_start[0] = 0; }
uint32_t jna_get_enter_bootloader_mode(void) { return enter_bootloader_mode; }
void jna_reset_enter_bootloader_mode(void) { enter_bootloader_mode = 0U; }
void jna_uart_push(const char *data, size_t len) {
    if (uart_ring_debug.elems_rx == NULL) {
        uart_ring_debug.elems_rx = (uint8_t *)uart_debug_rx_buf;
        uart_ring_debug.rx_fifo_size = 256;
    }
    for (size_t i = 0U; (i < len) && (i < 256U); i++) {
        uart_ring_debug.elems_rx[i] = (uint8_t)data[i];
    }
    uart_ring_debug.w_ptr_rx = (len > 256U) ? 256U : (uint16_t)len;
    uart_ring_debug.r_ptr_rx = 0U;
}
void jna_reset_uart(void) {
    uart_ring_debug.w_ptr_rx = 0U;
    uart_ring_debug.r_ptr_rx = 0U;
}
void jna_set_fan_rpm(uint16_t val) { fan_state.rpm = val; }
uint32_t jna_get_resp_len(void) { return jna_resp_len; }
uint8_t jna_get_resp_byte(int index) {
    if ((index < 0) || (index >= 0x40)) return 0;
    return jna_resp[index];
}

// ---- JNA API: Setup for read-request tests ----
void jna_set_hw_type(uint8_t val) { hw_type = val; }
void jna_set_gitversion(const char *val) {
    size_t len = 0U;
    while ((len < 63U) && (val[len] != '\0')) {
        gitversion[len] = val[len];
        len++;
    }
    gitversion[len] = '\0';
}
void jna_set_som_gpio(int val) {
#if defined(E2E_BOARD_TRES)
    // Tres: SOM GPIO is on GPIOB pin 1, active-high
    if (val) e2e_GPIOB.IDR |= (1U << 1); else e2e_GPIOB.IDR &= ~(1U << 1);
#else
    // Cuatro/Red: GPIOC pin 3, active-low
    if (val) e2e_GPIOC.IDR &= ~(1U << 3); else e2e_GPIOC.IDR |= (1U << 3);
#endif
}

// ---- JNA API: Direct state setters (bypass firmware pipeline) ----
void jna_set_current_safety_mode(int val) { current_safety_mode = (uint16_t)val; }
void jna_set_alternative_experience(int val) { alternative_experience = val; }
void jna_set_heartbeat_disabled(int val) { heartbeat_disabled = (val != 0); }

// ---- JNA API: CAN health inspection ----
int jna_get_can_health_speed(int bus) {
    if ((bus < 0) || (bus >= PANDA_CAN_CNT)) return -1;
    return (int)can_health[bus].can_speed;
}
int jna_get_can_health_data_speed(int bus) {
    if ((bus < 0) || (bus >= PANDA_CAN_CNT)) return -1;
    return (int)can_health[bus].can_data_speed;
}
int jna_get_can_health_canfd_enabled(int bus) {
    if ((bus < 0) || (bus >= PANDA_CAN_CNT)) return 0;
    return can_health[bus].canfd_enabled ? 1 : 0;
}
int jna_get_can_health_brs_enabled(int bus) {
    if ((bus < 0) || (bus >= PANDA_CAN_CNT)) return 0;
    return can_health[bus].brs_enabled ? 1 : 0;
}
int jna_get_can_health_canfd_non_iso(int bus) {
    if ((bus < 0) || (bus >= PANDA_CAN_CNT)) return 0;
    return can_health[bus].canfd_non_iso ? 1 : 0;
}
int jna_get_can_health_last_error(int bus) {
    if ((bus < 0) || (bus >= PANDA_CAN_CNT)) return 0;
    return (int)can_health[bus].last_error;
}
int jna_get_can_health_receive_error_cnt(int bus) {
    if ((bus < 0) || (bus >= PANDA_CAN_CNT)) return 0;
    return (int)can_health[bus].receive_error_cnt;
}
int jna_get_can_health_transmit_error_cnt(int bus) {
    if ((bus < 0) || (bus >= PANDA_CAN_CNT)) return 0;
    return (int)can_health[bus].transmit_error_cnt;
}
int jna_get_can_health_can_core_reset_cnt(int bus) {
    if ((bus < 0) || (bus >= PANDA_CAN_CNT)) return 0;
    return (int)can_health[bus].can_core_reset_cnt;
}
int jna_get_can_health_bus_off_cnt(int bus) {
    if ((bus < 0) || (bus >= PANDA_CAN_CNT)) return 0;
    return (int)can_health[bus].bus_off_cnt;
}
int jna_get_can_health_error_warning(int bus) {
    if ((bus < 0) || (bus >= PANDA_CAN_CNT)) return 0;
    return (int)can_health[bus].error_warning;
}
int jna_get_can_health_error_passive(int bus) {
    if ((bus < 0) || (bus >= PANDA_CAN_CNT)) return 0;
    return (int)can_health[bus].error_passive;
}
int jna_get_can_health_last_data_error(int bus) {
    if ((bus < 0) || (bus >= PANDA_CAN_CNT)) return 0;
    return (int)can_health[bus].last_data_error;
}
int jna_get_can_health_total_error_cnt(int bus) {
    if ((bus < 0) || (bus >= PANDA_CAN_CNT)) return 0;
    return (int)can_health[bus].total_error_cnt;
}
int jna_get_can_health_total_rx_lost_cnt(int bus) {
    if ((bus < 0) || (bus >= PANDA_CAN_CNT)) return 0;
    return (int)can_health[bus].total_rx_lost_cnt;
}
// Direct call to update_can_health_pkt with custom ir_reg (bypasses handler)
void jna_call_update_can_health_pkt(int can_number, uint32_t ir_reg) {
    update_can_health_pkt((uint8_t)can_number, ir_reg);
}
void jna_reset_can_health(void) {
    for (int i = 0; i < PANDA_CAN_CNT; i++) {
        can_health[i] = (can_health_t){0};
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

// ---- Register divergence testing (check_registers) ----
// e2e register_set stub bypasses register_map; inject directly for testing.
// Sets up a fake register where shadow (register_map) and actual (*addr) can differ.
static uint32_t e2e_reg_divergence_storage;

void jna_set_register_divergent(int enable) {
    volatile uint32_t *addr = &e2e_reg_divergence_storage;
    uint32_t addr_val = (uint32_t)addr;

    // Find hash slot
    uint16_t hash = hash_addr(addr_val);
    uint16_t tries = REGISTER_MAP_SIZE;
    while (CHECK_COLLISION(hash, addr) && (tries > 0U)) {
        hash = hash_addr((uint32_t)hash);
        tries--;
    }

    if (tries != 0U) {
        if (enable) {
            // Divergent: shadow expects 0xAAAA, hardware reads 0x5555
            *addr = 0x5555U;
            register_map[hash].address = addr;
            register_map[hash].value = 0xAAAAU;
            register_map[hash].check_mask = 0xFFFFU;
            register_map[hash].logged_fault = false;
        } else {
            // Non-divergent: shadow = actual
            *addr = 0xAAAAU;
            register_map[hash].address = addr;
            register_map[hash].value = 0xAAAAU;
            register_map[hash].check_mask = 0xFFFFU;
            register_map[hash].logged_fault = false;
        }
    }
}

// ---- JNA API: SPI version packet (exercises spi_version_packet + crc_checksum) ----
// Writes the VERSION response (header + data + CRC-8) into buf. Returns total byte length.
// buf must be at least 32 bytes. spi_version_packet uses UID_BASE (fake_uid), hw_type, USB_PID.
uint16_t jna_spi_version_packet(uint8_t *buf) {
    return spi_version_packet(buf);
}

// Full panda init — called once after library load to set hardware to post-reset defaults.
// can_init() and jna_reset_safety() trigger side effects (CAN transceiver, IRQ calls).
// The reset calls below clean up tracking counters and GPIO state accumulated during init.
// All other state is handled by BSS zeroing + data-segment init on fresh dlopen.
void jna_panda_init(void) {
    detect_board_type();
    can_init(0);
    can_init(1);
    can_init(2);
    fan_init();
    jna_reset_safety();
    jna_reset_power_save_tracking();
    jna_reset_stop_mode_tracking();
    jna_reset_siren();
    jna_reset_heartbeat();
    jna_reset_bootkick();
    jna_comms_can_reset();
    simple_watchdog_init(FAULT_HEARTBEAT_LOOP_WATCHDOG, (3U * 1000000U / 8U));
    init_registers();  // clear register_map after init to avoid false divergence
}

int jna_get_can_init_timeout_ms(void) {
    return CAN_INIT_TIMEOUT_MS;
}

// ---- unused_funcs.h: init_bootloader JNA wrapper ----
// unused_init_bootloader is wired into all e2e board structs but can't be
// exercised through normal e2e paths (early_initialization is stubbed).
void jna_unused_init_bootloader(void) {
    unused_init_bootloader();
}
