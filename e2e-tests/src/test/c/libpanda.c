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
bool power_save_enabled;
bool siren_enabled;
uint32_t siren_countdown;
volatile bool stop_mode_requested;
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
struct e2e_SCB_Regs  { uint8_t _p[0x0C]; volatile uint32_t SCR; };

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
#define NVIC_EnableIRQ(x) e2e_nvic_enable_irq(x)
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
#define FDCAN1_IT0_IRQn 19
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

// Board selection fallback
#if !defined(E2E_BOARD_CUATRO) && !defined(E2E_BOARD_TRES) && !defined(E2E_BOARD_RED)
#define E2E_BOARD_CUATRO
#endif

// Health voltage/current — JNA setters for e2e testing

// ---- enter_stop_mode tracking ----
#define NVIC_IRQ_TRACK_MAX 8
static int enter_stop_mode_call_count;
static bool irq_disabled;
static bool dsb_called;
static bool isb_called;
static bool wfi_entered;
#define NVIC_IRQ_TRACK_MAX 8
static int nvic_irq_enable_count;
static int nvic_irq_enabled[NVIC_IRQ_TRACK_MAX];
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

static uint8_t can_mode_last;
static int can_mode_call_count;
static uint32_t e2e_voltage_mV = 12000;
static uint32_t e2e_current_mA = 0;
void board_set_can_mode_stub(uint8_t mode) {
    can_mode_last = mode;
    can_mode_call_count++;
}
uint32_t board_read_voltage_mV_stub(void) { return e2e_voltage_mV; }
uint32_t board_read_current_mA_stub(void) { return e2e_current_mA; }

void jna_set_voltage_mV(int val) { e2e_voltage_mV = (uint32_t)val; }
void jna_set_current_mA(int val) { e2e_current_mA = (uint32_t)val; }

// Tracking stub for set_ir_power — records all calls
#define MAX_IR_POWER_CALLS 16
static uint8_t ir_power_values[MAX_IR_POWER_CALLS];
static int ir_power_call_count;
void board_set_ir_power_stub(uint8_t p) {
    // Write IR power percentage to fake PWM register (TIM CCR)
    // Real implementations use pwm_set(TIMx, channel, percentage)
    // For e2e testing, record in TIM CCR for verification
    fake_TIM1.CCR1 = p;  // IR PWM duty cycle
    ir_power_call_count++;
}
void board_set_fan_enabled_stub(bool en) { (void)en; }
void board_set_siren_stub(bool en);
static void stub_unused_set_amp_enabled(bool en) { (void)en; }
// Forward declarations — defined in board_stubs_e2e.gen.c (included after macro overrides)
void cuatro_set_bootkick(BootState state);
void cuatro_set_amp_enabled(bool enabled);
void cuatro_enable_can_transceiver(uint8_t transceiver, bool enabled);
void tres_set_bootkick(BootState state);
void tres_enable_can_transceiver(uint8_t transceiver, bool enabled);
void red_enable_can_transceiver(uint8_t transceiver, bool enabled);
bool board_read_som_gpio_stub(void);

struct harness_configuration harness_config_stub = {
    .GPIO_SBU1 = (GPIO_TypeDef *)&e2e_GPIOC,
    .GPIO_SBU2 = (GPIO_TypeDef *)&e2e_GPIOA,
    .pin_SBU1 = 4,
    .pin_SBU2 = 1,
    .has_harness = false,
    .HARNESS_CONNECTED_THRESHOLD = 10000,
};
struct board board_stub = {
    .harness_config = &harness_config_stub,
    .led_GPIO = {&dummy_gpio, &dummy_gpio, &dummy_gpio},
    .set_can_mode = board_set_can_mode_stub,
    .read_voltage_mV = board_read_voltage_mV_stub,
    .read_current_mA = board_read_current_mA_stub,
    .set_ir_power = board_set_ir_power_stub,
    .set_fan_enabled = board_set_fan_enabled_stub,
    .set_siren = board_set_siren_stub,
#if defined(E2E_BOARD_TRES)
    .set_bootkick = tres_set_bootkick,
    .set_amp_enabled = stub_unused_set_amp_enabled,
    .enable_can_transceiver = tres_enable_can_transceiver,
#elif defined(E2E_BOARD_RED)
    .set_bootkick = stub_unused_set_amp_enabled,
    .set_amp_enabled = stub_unused_set_amp_enabled,
    .enable_can_transceiver = red_enable_can_transceiver,
#else
    .set_bootkick = cuatro_set_bootkick,
    .set_amp_enabled = cuatro_set_amp_enabled,
    .enable_can_transceiver = cuatro_enable_can_transceiver,
#endif
    .read_som_gpio = board_read_som_gpio_stub,
};
const struct board *current_board = &board_stub;

// ---- Function stubs ----
// Recording stub: captures last set_intercept_relay call for test verification
static bool relay_a, relay_b;
static int relay_call_count;
void set_intercept_relay(bool a, bool b);
void harness_init(void) {}
void harness_tick(void) {}
bool harness_check_ignition(void) { return false; }
uint8_t harness_detect_orientation(void) { return 1; }
void fake_siren_set(bool en) { siren_enabled = en; }
// can_init is defined in fdcan_e2e.gen.c (generated from real firmware source)
void can_rx(uint8_t n) { (void)n; }
void process_can(uint8_t n) { (void)n; }
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

// Tracking stub: records last enable_can_transceivers call AND drives real GPIO
static bool last_can_transceivers_enabled;
static int can_transceivers_call_count;
void enable_can_transceivers(bool en) {
    last_can_transceivers_enabled = en;
    can_transceivers_call_count++;
    // Drive real GPIO via board implementation
    uint8_t main_bus = 1U;
    for (uint8_t i = 1U; i <= 4U; i++) {
        current_board->enable_can_transceiver(i, (i == main_bus) || en);
    }
}

// ---- REAL set_power_save_state (auto-generated from board/sys/power_saving.h) ----
// Regenerate: python3 generate_power_save_stubs.py > power_save_e2e.gen.c
#include "power_save_e2e.gen.c"

void sound_init(void) {}
void sound_tick(void) {}
void sound_init_dac(void) {}
void init_interrupts(bool en) { (void)en; }
void tick_timer_init(void) {}
void microsecond_timer_init(void) {}
void interrupt_timer_init(void) {}
void gpio_spi_init(void) {}
void fan_init(void) {}
void fan_tick(void) {}
void check_registers(void) {}
void disable_interrupts(void) {}
void enable_interrupts(void) {}
static int nvic_reset_call_count;
void NVIC_SystemReset(void) { nvic_reset_call_count++; }

int jna_get_nvic_reset_count(void) { return nvic_reset_call_count; }
void jna_reset_nvic_count(void) { nvic_reset_call_count = 0; }

int jna_get_stop_mode_requested(void) { return stop_mode_requested ? 1 : 0; }

// ---- JNA API: enter_stop_mode tracking ----
int jna_get_enter_stop_mode_call_count(void) { return enter_stop_mode_call_count; }

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
uint32_t jna_get_reg_GPIOE_ODR(void)   { return e2e_GPIOE.ODR; }
uint32_t jna_get_reg_GPIOF_ODR(void)   { return e2e_GPIOF.ODR; }
uint32_t jna_get_reg_GPIOG_ODR(void)   { return e2e_GPIOG.ODR; }
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
int jna_get_nvic_irq_enable_count(void)    { return nvic_irq_enable_count; }
int jna_get_nvic_irq_enabled_at(int i)     { return (i >= 0 && i < NVIC_IRQ_TRACK_MAX) ? nvic_irq_enabled[i] : -1; }

void jna_reset_stop_mode_tracking(void) {
    stop_mode_requested = false;
    enter_stop_mode_call_count = 0;
    irq_disabled = false;
    dsb_called = false;
    isb_called = false;
    wfi_entered = false;
    nvic_irq_enable_count = 0;
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
void can_tx_comms_resume_spi(void) {}

// fan_state instance (type from drivers.h)
struct fan_state_t fan_state;

// ADC
typedef struct { uint32_t x; } ADC_TypeDef;
ADC_TypeDef adc1_inst;
#define ADC1 (&adc1_inst)
void adc_init(ADC_TypeDef *adc) { (void)adc; }

// GPIO
// Forward declarations needed by board/drivers/gpio.h
void register_set(volatile uint32_t *addr, uint32_t val, uint32_t mask);
void register_set_bits(volatile uint32_t *addr, uint32_t val);
void register_clear_bits(volatile uint32_t *addr, uint32_t mask);
#include "board/drivers/gpio.h"

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

// CMSIS intrinsics (must be BEFORE board/main.c — main.c power_save path uses __WFI)
static void e2e_nvic_enable_irq(int irqn) {
    if (nvic_irq_enable_count < NVIC_IRQ_TRACK_MAX) {
        nvic_irq_enabled[nvic_irq_enable_count] = irqn;
    }
    nvic_irq_enable_count++;
}
void __disable_irq(void) { irq_disabled = true; }
void __enable_irq(void) {}
void __DSB(void) { dsb_called = true; }
void __ISB(void) { isb_called = true; }
void __WFI(void) { wfi_entered = true; }

// ---- FULL board/main.c ----
#include "board/main.c"

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
#define MODE_INPUT 0U
#define MODE_OUTPUT 1U
#define MODE_ANALOG 3U
#define PULL_NONE 0U
#define OUTPUT_TYPE_OPEN_DRAIN 1U
#define EXTI1_IRQn        7
#define EXTI4_IRQn        10
#define EXTI9_5_IRQn      23
#define EXTI15_10_IRQn    40
#define NVIC_EnableIRQ(x) e2e_nvic_enable_irq(x)

// Forward declarations
void register_set(volatile uint32_t *addr, uint32_t val, uint32_t mask);
void register_clear_bits(volatile uint32_t *addr, uint32_t mask);
void register_set_bits(volatile uint32_t *addr, uint32_t val);

// ---- Production board stubs (auto-generated from board/boards/*.h) ----
// Regenerate: python3 generate_board_stubs.py > board_stubs_e2e.gen.c
#include "board_stubs_e2e.gen.c"

// ---- REAL enter_stop_mode (auto-generated from board/sys/power_saving.h) ----
// Regenerate: python3 generate_enter_stop_mode_stubs.py > enter_stop_mode_e2e.gen.c
#include "enter_stop_mode_e2e.gen.c"

// Simulates the main loop's stop_mode_requested check.
void jna_process_stop_mode(void) {
    if (stop_mode_requested) {
        enter_stop_mode();
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
void board_set_siren_stub(bool en) {
    set_gpio_output(GPIOB, 14, en);
}

// Simulate main.c tick handler — applies siren_enabled flag to GPIO
void jna_tick_siren(void) {
    current_board->set_siren(siren_enabled);
}

// Real relay control (after GPIO macro overrides)
void set_intercept_relay(bool a, bool b) {
    // Cuatro: relay SBU1 = PA9 (ignition), relay SBU2 = PA3 (intercept), active-low
    set_gpio_output(GPIOA, 9, !b);
    set_gpio_output(GPIOA, 3, !a);
    relay_a = a;
    relay_b = b;
    relay_call_count++;
}

// ---- Faithful can_init: writes to fake FDCAN_GlobalTypeDef registers ----
// Auto-generated from real firmware source by generate_fdcan_stubs.py.
// Regenerate: python3 generate_fdcan_stubs.py > fdcan_e2e.gen.c
#include "fdcan_e2e.gen.c"

// Override TIM1/TIM8 with fake instances for register-level verification
#undef TIM1
#undef TIM8
#define TIM1 ((e2e_TIM_TypeDef *)&fake_TIM1)
#define TIM8 ((e2e_TIM_TypeDef *)&fake_TIM8)

// e2e register_set: writes directly to fake register without critical section
void register_set(volatile uint32_t *addr, uint32_t val, uint32_t mask) {
    (*addr) = ((*addr) & (~mask)) | (val & mask);
}

void register_set_bits(volatile uint32_t *addr, uint32_t val) {
    register_set(addr, val, val);
}

void register_clear_bits(volatile uint32_t *addr, uint32_t mask) {
    register_set(addr, (~mask), mask);
}

// ---- REAL clock_source_set_timer_params (auto-generated from board/drivers/clock_source.h) ----
// Regenerate: python3 generate_clock_source_stubs.py > clock_source_e2e.gen.c
#include "clock_source_e2e.gen.c"

// ---- REAL update_can_health_pkt (auto-generated from board/drivers/fdcan.h) ----
// Regenerate: python3 generate_can_health_stubs.py > can_health_e2e.gen.c
#include "can_health_e2e.gen.c"

// ---- REAL fan_set_power (auto-generated from board/drivers/fan.h) ----
// Regenerate: python3 generate_fan_stubs.py > fan_e2e.gen.c
#include "fan_e2e.gen.c"

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
void jna_set_fdcan_psr(int can_number, uint32_t val) {
    if ((can_number >= 0) && (can_number < 3)) fake_fdcan[can_number].PSR = val;
}
void jna_set_fdcan_ecr(int can_number, uint32_t val) {
    if ((can_number >= 0) && (can_number < 3)) fake_fdcan[can_number].ECR = val;
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

// fan_power — direct read from fan_state.power (set by real fan_set_power)
int jna_get_fan_power(void) { return (int)fan_state.power; }

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

// ---- JNA API: Clock source TIM registers ----
// After clock_source_set_timer_params(param1, param2), the fake TIM
// registers are set to computed values. Expose them for verification.
uint32_t jna_get_TIM1_CCR1(void) { return fake_TIM1.CCR1; }
uint32_t jna_get_ir_pwm(void)               { return fake_TIM1.CCR1; }
uint32_t jna_get_TIM1_CCR2(void) { return fake_TIM1.CCR2; }
uint32_t jna_get_TIM8_CCR3(void) { return fake_TIM8.CCR3; }
uint32_t jna_get_TIM1_ARR(void)  { return fake_TIM1.ARR; }
uint32_t jna_get_TIM1_CCR4(void) { return fake_TIM1.CCR4; }
void jna_reset_TIM_regs(void) {
    fake_TIM1 = (e2e_TIM_TypeDef){0};
    fake_TIM8 = (e2e_TIM_TypeDef){0};
}

// ---- JNA API: Microsecond timer and fan RPM ----
uint32_t jna_get_microsecond_timer(void) {
    return microsecond_timer_get();
}
uint16_t jna_get_fan_rpm(void) {
    return fan_state.rpm;
}

// ---- JNA API: Setup + response buffer inspection ----
void jna_set_microsecond_timer(uint32_t val) { MICROSECOND_TIMER->CNT = val; }
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
int jna_get_can_health_irq0_call_rate(int bus) {
    if ((bus < 0) || (bus >= PANDA_CAN_CNT)) return 0;
    return (int)can_health[bus].irq0_call_rate;
}
int jna_get_can_health_irq1_call_rate(int bus) {
    if ((bus < 0) || (bus >= PANDA_CAN_CNT)) return 0;
    return (int)can_health[bus].irq1_call_rate;
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

// ---- can_clear_send tracking ----
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
