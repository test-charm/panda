// libpanda_body.c — compiles board/body/main.c as host .dylib.
// Tests body firmware USB commands (0xb3 motor speed, 0xb4 motor enable).
//
// Build: ./build.sh body
// Test:  cd .. && ./gradlew cucumber

#include "fake_stm.h"

// ---- CMSIS + safety deps ----
#include "config.h"
#include "opendbc/safety/can.h"

// ---- adc_signal_t (needed before drivers.h) ----
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

// ---- common stubs shared with panda e2e ----
#include "stm32h7xx.h"    // Minimal CMSIS stub (UID_BASE, register types)
#include "board/stm32h7/stm32h7_config.h"
#include "fdcan_regs.h"

// ---- Fake GPIO instances (matching libpanda.c) ----
GPIO_TypeDef e2e_GPIOA, e2e_GPIOB, e2e_GPIOC, e2e_GPIOD, e2e_GPIOE, e2e_GPIOF, e2e_GPIOG;
#define GPIOA (&e2e_GPIOA)
#define GPIOB (&e2e_GPIOB)
#define GPIOC (&e2e_GPIOC)
#define GPIOD (&e2e_GPIOD)
#define GPIOE (&e2e_GPIOE)
#define GPIOF (&e2e_GPIOF)
#define GPIOG (&e2e_GPIOG)

// ---- Fake ADC instances (needed by BLDC) ----
struct e2e_ADC_Regs {
  uint32_t ISR, _pad0, IER, _pad1, CR, _pad2, CFGR, CFGR2;
  uint32_t SMPR[2], _pad3[2], PCSEL, _pad4, LTR[2], _pad5, HTR[2];
  uint32_t _pad6[24], SQR[4], _pad7[4], DR, _pad8[7], DIFSEL, CALFACT;
  uint32_t _pad9[199], JDR[4], _pad10[78];
  uint32_t AWD2CR, AWD3CR, _pad11[3], DIFSEL2;
};
struct e2e_ADC_Regs e2e_ADC1, e2e_ADC2;
#define ADC1 (&e2e_ADC1)
#define ADC2 (&e2e_ADC2)

// Fake SCB for enable_fpu() — matches body main.c
struct e2e_SCB_Regs { uint32_t _pad[4], CPACR; };
struct e2e_SCB_Regs e2e_SCB;
#undef SCB
#define SCB (&e2e_SCB)

// Fake PWR, RCC, SYSCFG, EXTI — minimal stubs
struct e2e_PWR_Regs { uint32_t _pad[200]; };
struct e2e_PWR_Regs e2e_PWR;
#define PWR (&e2e_PWR)
struct e2e_RCC_Regs { uint32_t _pad[200]; };
struct e2e_RCC_Regs e2e_RCC;
#define RCC (&e2e_RCC)
struct e2e_SYSCFG_Regs { uint32_t _pad[2], EXTICR[4], _pad2[200]; };
struct e2e_SYSCFG_Regs e2e_SYSCFG;
#define SYSCFG (&e2e_SYSCFG)
struct e2e_EXTI_Regs { uint32_t _pad[1], RTSR1, FTSR1, _pad1, IMR1, _pad2, PR1, _pad3[200]; };
struct e2e_EXTI_Regs e2e_EXTI;
#define EXTI (&e2e_EXTI)

// Fake NVIC stub
struct e2e_NVIC_Regs { uint32_t _pad[100]; };
struct e2e_NVIC_Regs e2e_NVIC;
#define NVIC (&e2e_NVIC)

// Fake TICK_TIMER
TIM_TypeDef e2e_body_tick_timer;
TIM_TypeDef *TICK_TIMER = &e2e_body_tick_timer;

// Fake TIM1 and TIM8 (BLDC motor control timers)
TIM_TypeDef e2e_TIM1, e2e_TIM8;
#undef TIM1
#define TIM1 (&e2e_TIM1)
#undef TIM8
#define TIM8 (&e2e_TIM8)

// ---- FDCAN instances ----
// FDCAN1/2/3 macros must be defined as pointers BEFORE including headers that use them
#define FDCAN1 (&e2e_FDCAN1)
#define FDCAN2 (&e2e_FDCAN2)
#define FDCAN3 (&e2e_FDCAN3)
FDCAN_GlobalTypeDef e2e_FDCAN1 = {0}, e2e_FDCAN2 = {0}, e2e_FDCAN3 = {0};
FDCAN_GlobalTypeDef fake_fdcan[3] = {{0}, {0}, {0}};
// cans[] is defined by fdcan.h, not here

// ---- FDCAN SRAM buffer (needed by fdcan.h) ----
uint32_t e2e_fdcan_sram[4096] __attribute__((aligned(256)));

// ---- CMSIS intrinsic stubs ----
void __disable_irq(void) {}
void __enable_irq(void) {}
void __DSB(void) {}
void __ISB(void) {}
void __WFI(void) {}

// ---- Utility stubs ----
uint32_t microsecond_timer_get(void) { return 0; }
void microsecond_timer_init(void) {}
void tick_timer_init(void) {}
void peripherals_init(void) {}
void clock_init(void) {}
void usb_init(void) {}
void early_initialization(void) {}
void interrupt_timer_init(void) {}
void fault_occurred(uint32_t fault) { (void)fault; }
void disable_interrupts(void) {}
void enable_interrupts(void) {}
static int nvic_reset_call_count = 0;
void NVIC_SystemReset(void) { nvic_reset_call_count++; }

// _app_start — the firmware binary signature location (from linker script)
int _app_start[0xc000] = {0};

// CAN comms extern
void can_tx_comms_resume_usb(void) {}

// ---- Interrupt table ----
interrupt interrupts[128];

// ---- Globals needed by body main.c ----
uint32_t enter_bootloader_mode;
uint8_t hw_type;
uint32_t uptime_cnt;

// ENTER_*_MAGIC values (from real board/early_init.h, not in e2e stub)
#define ENTER_BOOTLOADER_MAGIC 0x1U
#define ENTER_SOFTLOADER_MAGIC 0x2U

// ---- CAN state globals ----
bool can_silent;
bool can_loopback;

// LED_BLUE stub (fdcan.h uses it under PANDA_BODY)
#define LED_BLUE 1

// body_can_rx forward decl (fdcan.h calls this under #ifdef PANDA_BODY)
void body_can_rx(CANPacket_t *msg);

// NUM_INTERRUPTS (used by interrupts.h)
#define NUM_INTERRUPTS 128

// Provision address stub
#define PROVISION_CHUNK_ADDRESS  ((uint32_t)0x1FFF0000UL)

// ---- SYSCFG EXTI macros (needed by board_body.h) ----
#define SYSCFG_EXTICR4_EXTI15     (0xFU << 12)
#define SYSCFG_EXTICR4_EXTI15_PC  (0x2U << 12)
#define SYSCFG_EXTICR4_EXTI13     (0xFU << 4)
#define SYSCFG_EXTICR4_EXTI13_PC  (0x2U << 4)

// ---- GPIO functions — include real gpio.h (provides implementations) ----
#include "board/drivers/gpio.h"

// ---- board struct for body ----
// typedef needed because board_body.h defines `board board_body = { ... }`
typedef struct board board;
#include "board/body/boards/board_declarations.h"
#include "board/body/boards/board_body.h"
board *current_board = &board_body;

// TIM3 (used by led.h — body doesn't use PWM LEDs, but the code references TIM3)
TIM_TypeDef e2e_body_TIM3;
#define TIM3 (&e2e_body_TIM3)

// ---- ADC stubs (override real lladc.h) ----
// The e2e lladc.h (at board/stm32h7/lladc.h) takes priority and uses #pragma once.
// It provides adc_signal_t and adc_get_mV(). It accesses `harness` struct which
// we define here. We also provide adc_get_raw and adc_init stubs.
#ifndef BOARD_STM32H7_LLADC_H_DEFINED
#define BOARD_STM32H7_LLADC_H_DEFINED

// Minimal harness struct (needed by e2e lladc.h's adc_get_mV)
struct harness_t {
  uint8_t status;
  uint16_t sbu1_voltage_mV;
  uint16_t sbu2_voltage_mV;
  bool relay_driven;
  bool sbu_adc_lock;
};
struct harness_t harness;

// ADC channel voltage stubs (needed by e2e lladc.h)
uint16_t e2e_adc_ch8_mV;
uint16_t e2e_adc_ch3_mV;
uint16_t e2e_adc_ch2_mV;

// ADC_TypeDef: alias for our fake ADC struct so ADC1/ADC2 are compatible
typedef struct e2e_ADC_Regs ADC_TypeDef;

// The e2e lladc.h provides adc_get_mV but not adc_get_raw or adc_init.
// Provide these as non-static (the real lladc.h is prevented by our guard).
static inline uint16_t adc_get_raw(const adc_signal_t *sig) { (void)sig; return 0; }
static inline void adc_init(ADC_TypeDef *adc) { (void)adc; }
#endif

// Now include the e2e lladc.h — its #pragma once means it won't be re-included later
#include "board/stm32h7/lladc.h"

// ---- UART stubs ----
void uart_init(void *q, int baud) { (void)q; (void)baud; }
void print(const char *a) { (void)a; }
void puth(unsigned int i) { (void)i; }
void hexdump(const void *a, int l) { (void)a; (void)l; }
bool get_char(uart_ring *q, char *elem) { (void)q; (void)elem; return false; }
void injectc(uart_ring *q, char elem) { (void)q; (void)elem; }
uart_ring *get_ring_by_number(int num) { (void)num; return (uart_ring *)0; }

// ---- Safety hooks — include real safety.h BEFORE CAN layers ----
// can_common.h calls safety_tx_hook which is defined in opendbc/safety/safety.h.
// This must be included before can_common.h.
#include "opendbc/safety/safety.h"

// ---- libc.h MUST come before llfdcan.h (provides delay()) ----
#include "board/libc.h"

// ---- Forward declarations for led/pwm (needed by fdcan.h before led.h is included) ----
void led_set(uint8_t color, bool enabled);
void pwm_init(TIM_TypeDef *TIM, uint8_t channel);
void pwm_set(TIM_TypeDef *TIM, uint8_t channel, uint8_t percentage);

// ---- Prerequisites for body/main.c CAN layers ----
// llfdcan.h and interrupts.h are needed before fdcan.h (included by body/main.c)
// can_common.h and fdcan.h are included by body/main.c in the correct order.
#include "board/stm32h7/llfdcan.h"
#include "board/drivers/interrupts.h"

// Motor globals (declared in bldc.h, used by body/can.h before bldc.h is included)
extern volatile int rpm_left;
extern volatile int rpm_right;
extern volatile bool enable_motors;

// Define the actual globals (normally defined in bldc.h, but we skip it for e2e)
volatile int rpm_left = 0;
volatile int rpm_right = 0;
volatile bool enable_motors = 0;

// Battery globals now defined in e2e bldc.h compatibility wrapper
// (board/body/bldc/bldc.h → included via board/body/main.c)

// ---- Provision (for UID_BASE, DEVICE_SERIAL_NUMBER_ADDRESS) ----
#include "board/provision.h"

// ---- Fake gitversion ----
#include "board/obj/gitversion.h"
// The e2e stub only provides GIT_VERSION macro. The real code uses `gitversion` array.
const uint8_t gitversion[19] = "e2e-test-00000000";

// ---- FULL body main.c ----
// Prevent real bldc.h from being included (has Simulink word-size checks).
// Our e2e stub at board/body/bldc/bldc.h (found via -I $SCRIPT_DIR) provides the override.
#define BLDC_H
#define main body_main
#include "board/body/main.c"
#undef main

// ---- JNA wrappers for body commands ----
// comms_control_handler is defined in board/body/main_comms.h (included by body/main.c)

// Shared response buffer — filled by jna_body_control_write, read by jna_body_get_resp_byte
static uint8_t resp_buffer[64];
static int resp_buffer_len = 0;

// JNA: Send a control request and get response length + fill resp_buffer
int jna_body_control_write(unsigned int request, unsigned int param1, unsigned int param2) {
  ControlPacket_t req = {.request = request, .param1 = param1, .param2 = param2, .length = 0};
  uint8_t resp[64] = {0};
  resp_buffer_len = comms_control_handler(&req, resp);
  for (int i = 0; i < resp_buffer_len && i < 64; i++) {
    resp_buffer[i] = resp[i];
  }
  return resp_buffer_len;
}

// JNA: Read motor target globals
int jna_body_get_rpm_left(void)  { return rpm_left; }
int jna_body_get_rpm_right(void) { return rpm_right; }
int jna_body_get_enable_motors(void) { return (int)enable_motors; }

// JNA: Get hardware type
int jna_body_get_hw_type(void) { return (int)hw_type; }

// panda e2e compatibility — ApplicationSteps.setUp() calls jna_panda_init
// via PandaClient.clearAll(). Provide a no-op so body tests don't fail.
void jna_panda_init(void) {
  // Initialize key state that body/main.c's main() would set
  hw_type = HW_TYPE_BODY;
  uptime_cnt = 0;
  nvic_reset_call_count = 0;
  enter_bootloader_mode = 0;
}

// ---- JNA: Response buffer access (filled by jna_body_control_write) ----
int jna_body_get_resp_len(void) { return resp_buffer_len; }
int jna_body_get_resp_byte(int index) {
  if (index < 0 || index >= resp_buffer_len) return -1;
  return (int)resp_buffer[index];
}

// ---- JNA: NVIC reset count (NVIC_SystemReset call counter) ----
int jna_body_get_nvic_reset_count(void) { return nvic_reset_call_count; }
void jna_body_reset_nvic_count(void) { nvic_reset_call_count = 0; }

// ---- JNA: Bootloader mode state ----
int jna_body_get_enter_bootloader_mode(void) { return (int)enter_bootloader_mode; }

// ---- JNA: Signature data preset (for 0xd3/0xd4 signature commands) ----
void jna_body_set_app_code_len(int len) { _app_start[0] = len; }
void jna_body_set_signature_chunk(int chunk, const char *data, size_t data_len) {
  uint8_t *sig = (uint8_t *)_app_start + _app_start[0] + (size_t)chunk * 64U;
  for (size_t i = 0U; (i < 64U) && (i < data_len); i++) { sig[i] = (uint8_t)data[i]; }
}
