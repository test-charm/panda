// libpanda_body.c — compiles board/body/main.c as host .dylib.
// Tests body firmware USB commands (0xb3 motor speed, 0xb4 motor enable).
//
// Build: ./build.sh body
// Test:  cd .. && ./gradlew cucumber

#include "fake_stm.h"

#ifndef E2E_TEST
#define E2E_TEST
#endif

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
#define FDCAN1 (&fake_fdcan[0])
#define FDCAN2 (&fake_fdcan[1])
#define FDCAN3 (&fake_fdcan[2])
static FDCAN_GlobalTypeDef fake_fdcan[3] = {{0}, {0}, {0}};

// ---- FDCAN SRAM buffer (needed by fdcan.h) ----
#define FAKE_FDCAN_SRAM_SIZE 0x4000
static uint8_t fake_fdcan_sram[FAKE_FDCAN_SRAM_SIZE] __attribute__((aligned(256)));
#undef FDCAN_START_ADDRESS
#define FDCAN_START_ADDRESS ((uintptr_t)fake_fdcan_sram)
FDCAN_GlobalTypeDef *cans[3] = {FDCAN1, FDCAN2, FDCAN3};

// ---- CMSIS intrinsic stubs ----
void __disable_irq(void) {}
void __enable_irq(void) {}
void __DSB(void) {}
void __ISB(void) {}
void __WFI(void) {}

// ---- Utility stubs ----
static uint32_t e2e_microsecond_timer = 0U;
uint32_t microsecond_timer_get(void) { return e2e_microsecond_timer; }
void microsecond_timer_init(void) { e2e_microsecond_timer = 0U; }
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

int e2e_ctrl_mode_req_override = -1;

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
uint16_t e2e_adc_left_pha_a_raw;
uint16_t e2e_adc_left_pha_c_raw;
uint16_t e2e_adc_left_dc_raw;
uint16_t e2e_adc_right_pha_a_raw;
uint16_t e2e_adc_right_pha_c_raw;
uint16_t e2e_adc_right_dc_raw;
uint16_t e2e_adc_battery_raw;

// ADC_TypeDef: alias for our fake ADC struct so ADC1/ADC2 are compatible
typedef struct e2e_ADC_Regs ADC_TypeDef;

// The e2e lladc.h provides adc_get_mV but not adc_get_raw or adc_init.
// Provide these as non-static (the real lladc.h is prevented by our guard).
static inline uint16_t adc_get_raw(const adc_signal_t *sig) {
  if ((sig->adc == ADC2) && (sig->channel == 10U)) return e2e_adc_left_pha_a_raw;
  if ((sig->adc == ADC2) && (sig->channel == 11U)) return e2e_adc_left_pha_c_raw;
  if ((sig->adc == ADC2) && (sig->channel == 18U)) return e2e_adc_left_dc_raw;
  if ((sig->adc == ADC1) && (sig->channel == 7U)) return e2e_adc_right_pha_a_raw;
  if ((sig->adc == ADC1) && (sig->channel == 15U)) return e2e_adc_right_pha_c_raw;
  if ((sig->adc == ADC1) && (sig->channel == 5U)) return e2e_adc_right_dc_raw;
  if ((sig->adc == ADC1) && (sig->channel == 4U)) return e2e_adc_battery_raw;
  return 0U;
}
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
  e2e_microsecond_timer = 0U;
  e2e_ctrl_mode_req_override = -1;
  current_board = &board_body;

  e2e_GPIOA = (GPIO_TypeDef){0};
  e2e_GPIOB = (GPIO_TypeDef){0};
  e2e_GPIOC = (GPIO_TypeDef){0};
  e2e_GPIOD = (GPIO_TypeDef){0};
  e2e_GPIOE = (GPIO_TypeDef){0};
  e2e_GPIOF = (GPIO_TypeDef){0};
  e2e_GPIOG = (GPIO_TypeDef){0};
  e2e_ADC1 = (struct e2e_ADC_Regs){0};
  e2e_ADC2 = (struct e2e_ADC_Regs){0};
  e2e_SYSCFG = (struct e2e_SYSCFG_Regs){0};
  e2e_EXTI = (struct e2e_EXTI_Regs){0};
  e2e_TIM1 = (TIM_TypeDef){0};
  e2e_TIM8 = (TIM_TypeDef){0};
  e2e_adc_left_pha_a_raw = 0U;
  e2e_adc_left_pha_c_raw = 0U;
  e2e_adc_left_dc_raw = 0U;
  e2e_adc_right_pha_a_raw = 0U;
  e2e_adc_right_pha_c_raw = 0U;
  e2e_adc_right_dc_raw = 0U;
  e2e_adc_battery_raw = 0U;

  // body_main() startup initializes board GPIO/EXTI, then CAN, DotStar, and BLDC.
  // Mirror that startup path here so each body scenario begins from firmware init state.
  board_body_init();
  body_can_init();
  dotstar_init();
  bldc_init();
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

// ---- JNA: BLDC motor control (B8-B9) ----

// B8: bldc_init / TIM status
void jna_body_bldc_init(void) {
  bldc_init();
}

// LEFT_TIM = TIM8, RIGHT_TIM = TIM1 (defined in bldc_defs.h)
unsigned int jna_body_get_tim8_cr1(void) { return LEFT_TIM->CR1; }
unsigned int jna_body_get_tim1_cr1(void) { return RIGHT_TIM->CR1; }
unsigned int jna_body_get_tim8_arr(void) { return LEFT_TIM->ARR; }
unsigned int jna_body_get_tim1_arr(void) { return RIGHT_TIM->ARR; }

// B9: bldc_step — FOC algorithm execution
// e2e_bldc_skip_calibration() is defined in the e2e bldc.h wrapper
void e2e_bldc_skip_calibration(void);

void jna_bldc_step(void) { bldc_step(); }
void jna_body_skip_calibration(void) { e2e_bldc_skip_calibration(); }
void jna_body_set_motor_speeds(int left, int right) { rpm_left = left; rpm_right = right; }
void jna_body_set_enable_motors_val(int enable) { enable_motors = (bool)enable; }

unsigned int jna_body_get_tim8_ccr1(void) { return LEFT_TIM->CCR1; }
unsigned int jna_body_get_tim8_ccr2(void) { return LEFT_TIM->CCR2; }
unsigned int jna_body_get_tim8_ccr3(void) { return LEFT_TIM->CCR3; }
unsigned int jna_body_get_tim1_ccr1(void) { return RIGHT_TIM->CCR1; }
unsigned int jna_body_get_tim1_ccr2(void) { return RIGHT_TIM->CCR2; }
unsigned int jna_body_get_tim1_ccr3(void) { return RIGHT_TIM->CCR3; }
unsigned int jna_body_is_left_output_enabled(void) { return (LEFT_TIM->BDTR & TIM_BDTR_MOE) != 0U; }
unsigned int jna_body_is_right_output_enabled(void) { return (RIGHT_TIM->BDTR & TIM_BDTR_MOE) != 0U; }
int jna_body_get_left_input_target(void) { return rtU_Left.r_inpTgt; }
int jna_body_get_right_input_target(void) { return rtU_Right.r_inpTgt; }
void jna_body_set_ctrl_mode_req(int mode) { e2e_ctrl_mode_req_override = mode; }
void jna_body_set_ctrl_type_sel(int ctrl_type) { rtP_Left.z_ctrlTypSel = (uint8_t)ctrl_type; rtP_Right.z_ctrlTypSel = (uint8_t)ctrl_type; }
void jna_body_set_phase_selection(int phase_selection) { rtP_Left.z_selPhaCurMeasABC = (uint8_t)phase_selection; rtP_Right.z_selPhaCurMeasABC = (uint8_t)phase_selection; }
void jna_body_set_cruise_enabled(int enabled) { rtP_Left.b_cruiseCtrlEna = enabled != 0; rtP_Right.b_cruiseCtrlEna = enabled != 0; }
void jna_body_set_cruise_target(int target_rpm) { rtP_Left.n_cruiseMotTgt = (int16_t)target_rpm; rtP_Right.n_cruiseMotTgt = (int16_t)target_rpm; }
void jna_body_set_field_weak_enabled(int enabled) { rtP_Left.b_fieldWeakEna = enabled != 0; rtP_Right.b_fieldWeakEna = enabled != 0; }
void jna_body_set_scheduler_ready(int ready) { rtDW_Left.UnitDelay6_DSTATE = ready != 0; rtDW_Right.UnitDelay6_DSTATE = ready != 0; }
void jna_body_seed_control_mode(int mode) {
  DW *controllers[2] = {&rtDW_Left, &rtDW_Right};
  for (int i = 0; i < 2; i++) {
    controllers[i]->is_active_c1_BLDC_controller = 1U;
    if (mode == 0) {
      controllers[i]->is_c1_BLDC_controller = IN_OPEN;
      controllers[i]->is_ACTIVE = IN_NO_ACTIVE_CHILD;
      controllers[i]->z_ctrlMod = OPEN_MODE;
    } else {
      controllers[i]->is_c1_BLDC_controller = IN_ACTIVE;
      controllers[i]->is_ACTIVE = (uint8_t)mode;
      controllers[i]->z_ctrlMod = (mode == IN_SPEED_MODE) ? SPD_MODE : (mode == IN_TORQUE_MODE) ? TRQ_MODE : VLT_MODE;
    }
  }
}
void jna_body_set_hall_states(int left_a, int left_b, int left_c, int right_a, int right_b, int right_c) {
  e2e_GPIOB.IDR &= ~((1U << 6) | (1U << 7) | (1U << 8));
  e2e_GPIOA.IDR &= ~((1U << 0) | (1U << 1) | (1U << 2));
  if (left_a == 0) e2e_GPIOB.IDR |= (1U << 6);
  if (left_b == 0) e2e_GPIOB.IDR |= (1U << 7);
  if (left_c == 0) e2e_GPIOB.IDR |= (1U << 8);
  if (right_a == 0) e2e_GPIOA.IDR |= (1U << 0);
  if (right_b == 0) e2e_GPIOA.IDR |= (1U << 1);
  if (right_c == 0) e2e_GPIOA.IDR |= (1U << 2);
}
void jna_body_set_adc_raw_values(int left_a, int left_c, int left_dc, int right_a, int right_c, int right_dc, int battery) {
  e2e_adc_left_pha_a_raw = (uint16_t)left_a;
  e2e_adc_left_pha_c_raw = (uint16_t)left_c;
  e2e_adc_left_dc_raw = (uint16_t)left_dc;
  e2e_adc_right_pha_a_raw = (uint16_t)right_a;
  e2e_adc_right_pha_c_raw = (uint16_t)right_c;
  e2e_adc_right_dc_raw = (uint16_t)right_dc;
  e2e_adc_battery_raw = (uint16_t)battery;
}
int jna_body_get_left_ctrl_mode(void) { return rtDW_Left.z_ctrlMod; }
int jna_body_get_right_ctrl_mode(void) { return rtDW_Right.z_ctrlMod; }
int jna_body_get_left_ctrl_type(void) { return rtP_Left.z_ctrlTypSel; }
int jna_body_get_right_ctrl_type(void) { return rtP_Right.z_ctrlTypSel; }
int jna_body_get_left_phase_selection(void) { return rtP_Left.z_selPhaCurMeasABC; }
int jna_body_get_right_phase_selection(void) { return rtP_Right.z_selPhaCurMeasABC; }
int jna_body_get_left_iq(void) { return rtY_Left.iq; }
int jna_body_get_right_iq(void) { return rtY_Right.iq; }
int jna_body_get_left_id(void) { return rtY_Left.id; }
int jna_body_get_right_id(void) { return rtY_Right.id; }
int jna_body_get_left_electrical_angle(void) { return rtY_Left.a_elecAngle; }
int jna_body_get_right_electrical_angle(void) { return rtY_Right.a_elecAngle; }
int jna_body_get_left_err_code(void) { return rtY_Left.z_errCode; }
int jna_body_get_right_err_code(void) { return rtY_Right.z_errCode; }
void jna_body_set_angle_meas_ena(int enabled) { rtP_Left.b_angleMeasEna = enabled != 0; rtP_Right.b_angleMeasEna = enabled != 0; }
void jna_body_set_mech_angle(int left_angle, int right_angle) { rtU_Left.a_mechAngle = (int16_t)left_angle; rtU_Right.a_mechAngle = (int16_t)right_angle; }
void jna_body_set_diag_ena(int enabled) { rtP_Left.b_diagEna = enabled != 0; rtP_Right.b_diagEna = enabled != 0; }
void jna_body_set_err_qual(int qual, int dequal) { rtP_Left.t_errQual = (uint16_T)qual; rtP_Right.t_errQual = (uint16_T)qual; rtP_Left.t_errDequal = (uint16_T)dequal; rtP_Right.t_errDequal = (uint16_T)dequal; }

// ---- JNA: DotStar LED driver (B10-B12) ----
void jna_dotstar_init(void) { dotstar_init(); }
void jna_dotstar_fill(unsigned int r, unsigned int g, unsigned int b) {
  dotstar_fill((uint8_t)r, (uint8_t)g, (uint8_t)b);
}
void jna_dotstar_show(void) { dotstar_show(); }
void jna_dotstar_set_pixel(unsigned int index, unsigned int r, unsigned int g, unsigned int b) {
  dotstar_set_pixel((uint16_t)index, (uint8_t)r, (uint8_t)g, (uint8_t)b);
}
void jna_dotstar_set_global_brightness(unsigned int brightness) {
  dotstar_set_global_brightness((uint8_t)brightness);
}
void jna_dotstar_run_rainbow(unsigned int now_us) { dotstar_run_rainbow((uint32_t)now_us); }
void jna_dotstar_apply_breathe(unsigned int r, unsigned int g, unsigned int b,
                                unsigned int now_us, unsigned int cycle_us) {
  dotstar_rgb_t color = {.r = (uint8_t)r, .g = (uint8_t)g, .b = (uint8_t)b};
  dotstar_apply_breathe(color, (uint32_t)now_us, (uint32_t)cycle_us);
}

unsigned int jna_dotstar_get_pixel_r(unsigned int index) {
  if (index >= DOTSTAR_LED_COUNT) return 0;
  return dotstar_state.pixels[index].r;
}
unsigned int jna_dotstar_get_pixel_g(unsigned int index) {
  if (index >= DOTSTAR_LED_COUNT) return 0;
  return dotstar_state.pixels[index].g;
}
unsigned int jna_dotstar_get_pixel_b(unsigned int index) {
  if (index >= DOTSTAR_LED_COUNT) return 0;
  return dotstar_state.pixels[index].b;
}
unsigned int jna_dotstar_get_brightness(void) { return dotstar_state.global_brightness; }
unsigned int jna_dotstar_is_initialized(void) { return dotstar_state.initialized ? 1U : 0U; }

// ---- JNA: Body CAN (B13-B17) ----
void jna_body_can_send_motor_speeds(int left, int right) {
  body_can_send_motor_speeds(BODY_BUS_NUMBER, (float)left, (float)right);
}

void jna_body_can_send_var_values(int ignition, int enable_motors_val, int fault, int left_z_errcode, int right_z_errcode) {
  body_can_send_var_values(BODY_BUS_NUMBER, ignition != 0, enable_motors_val != 0,
                           (uint8_t)fault, (uint8_t)left_z_errcode, (uint8_t)right_z_errcode);
}

void jna_body_can_send_body_data(int mcu_temp_raw, int batt_voltage_raw_val, int batt_percentage_val, int charger_connected) {
  body_can_send_body_data(BODY_BUS_NUMBER, (uint8_t)mcu_temp_raw, (uint16_t)batt_voltage_raw_val,
                          (uint8_t)batt_percentage_val, charger_connected != 0);
}

void jna_body_set_microsecond_timer(unsigned int now_us) {
  e2e_microsecond_timer = now_us;
}

void jna_body_can_receive_target(int left_rpm, int right_rpm) {
  CANPacket_t pkt = {0};
  const int16_t left_target_deci_rpm = (int16_t)(left_rpm * 10);
  const int16_t right_target_deci_rpm = (int16_t)(right_rpm * 10);

  pkt.addr = 0x250U;
  pkt.bus = BODY_BUS_NUMBER;
  pkt.data_len_code = 4U;
  pkt.data[0] = (uint8_t)((left_target_deci_rpm >> 8U) & 0xFFU);
  pkt.data[1] = (uint8_t)(left_target_deci_rpm & 0xFFU);
  pkt.data[2] = (uint8_t)((right_target_deci_rpm >> 8U) & 0xFFU);
  pkt.data[3] = (uint8_t)(right_target_deci_rpm & 0xFFU);
  body_can_rx(&pkt);
}

void jna_body_can_periodic(unsigned int now_us, int ignition, int plug_charging) {
  body_can_periodic(now_us, ignition != 0, plug_charging != 0);
}

unsigned int jna_body_get_last_can_cmd_timestamp_us(void) {
  return last_can_cmd_timestamp_us;
}

unsigned int jna_body_get_can_silent(void) {
  return can_silent ? 1U : 0U;
}

unsigned int jna_body_get_can_loopback(void) {
  return can_loopback ? 1U : 0U;
}

unsigned int jna_body_is_body_safety_mode(void) {
  return (current_safety_mode == SAFETY_BODY) ? 1U : 0U;
}

unsigned int jna_body_is_can_transceiver_enabled(void) {
  const unsigned int pin_mode = (CAN_TRANSCEIVER_EN_PORT->MODER >> (CAN_TRANSCEIVER_EN_PIN * 2U)) & 0x3U;
  const unsigned int pin_level = (CAN_TRANSCEIVER_EN_PORT->ODR >> CAN_TRANSCEIVER_EN_PIN) & 0x1U;
  return ((pin_mode == MODE_OUTPUT) && (pin_level == 0U)) ? 1U : 0U;
}

unsigned int jna_body_get_exticr3(void) {
  return SYSCFG->EXTICR[3];
}

unsigned int jna_body_get_exti_imr1(void) {
  return EXTI->IMR1;
}

unsigned int jna_body_get_exti_rtsr1(void) {
  return EXTI->RTSR1;
}

unsigned int jna_body_get_exti_ftsr1(void) {
  return EXTI->FTSR1;
}

unsigned int jna_body_get_charging_detect_pupdr(void) {
  return (CHARGING_DETECT_PORT->PUPDR >> (CHARGING_DETECT_PIN * 2U)) & 0x3U;
}

unsigned int jna_body_get_can_rx_mode(void) {
  return (CAN_RX_PORT->MODER >> (CAN_RX_PIN * 2U)) & 0x3U;
}

unsigned int jna_body_get_can_tx_mode(void) {
  return (CAN_TX_PORT->MODER >> (CAN_TX_PIN * 2U)) & 0x3U;
}

unsigned int jna_body_get_can_rx_af(void) {
  return (CAN_RX_PORT->AFR[CAN_RX_PIN >> 3U] >> ((CAN_RX_PIN & 7U) * 4U)) & 0xFU;
}

unsigned int jna_body_get_can_tx_af(void) {
  return (CAN_TX_PORT->AFR[CAN_TX_PIN >> 3U] >> ((CAN_TX_PIN & 7U) * 4U)) & 0xFU;
}

unsigned int jna_body_get_obdc_power_mode(void) {
  return (OBDC_POWER_ON_PORT->MODER >> (OBDC_POWER_ON_PIN * 2U)) & 0x3U;
}

unsigned int jna_body_get_gpu_power_mode(void) {
  return (GPU_POWER_ON_PORT->MODER >> (GPU_POWER_ON_PIN * 2U)) & 0x3U;
}

unsigned int jna_body_get_ignition_output_mode(void) {
  return (OBDC_IGNITION_ON_PORT->MODER >> (OBDC_IGNITION_ON_PIN * 2U)) & 0x3U;
}

unsigned int jna_body_get_obdc_power_output(void) {
  return (OBDC_POWER_ON_PORT->ODR >> OBDC_POWER_ON_PIN) & 0x1U;
}

unsigned int jna_body_get_gpu_power_output(void) {
  return (GPU_POWER_ON_PORT->ODR >> GPU_POWER_ON_PIN) & 0x1U;
}

void jna_body_call_tick_handler(void) {
  TICK_TIMER->SR = 1U;
  tick_handler();
}

void jna_body_set_can0_transmit_error_cnt(int count) {
  can_health[0].transmit_error_cnt = (uint8_t)count;
}

void jna_body_set_can0_ile(int value) {
  fake_fdcan[0].ILE = (uint32_t)value;
}

unsigned int jna_body_get_can0_ile(void) {
  return fake_fdcan[0].ILE;
}

unsigned int jna_body_get_tick_count(void) {
  return tick_count;
}

unsigned int jna_body_get_red_led_output(void) {
  return (GPIOA->ODR >> 10U) & 0x1U;
}

void jna_body_set_charging_detect(int present) {
  if (present != 0) {
    CHARGING_DETECT_PORT->IDR |= (1U << CHARGING_DETECT_PIN);
  } else {
    CHARGING_DETECT_PORT->IDR &= ~(1U << CHARGING_DETECT_PIN);
  }
}

void jna_body_set_ignition_pressed(int pressed) {
  if (pressed != 0) {
    IGNITION_SW_PORT->IDR &= ~(1U << IGNITION_SW_PIN);
  } else {
    IGNITION_SW_PORT->IDR |= (1U << IGNITION_SW_PIN);
  }
}

void jna_body_trigger_charging_exti(void) {
  EXTI->PR1 = (1U << CHARGING_DETECT_PIN);
  exti15_10_handler();
}

void jna_body_trigger_ignition_exti(void) {
  EXTI->PR1 = (1U << IGNITION_SW_PIN);
  exti15_10_handler();
}

unsigned int jna_body_get_plug_charging(void) {
  return plug_charging ? 1U : 0U;
}

unsigned int jna_body_get_ignition(void) {
  return ignition ? 1U : 0U;
}

unsigned int jna_body_get_ignition_press_timestamp_us(void) {
  return ignition_press_timestamp_us;
}

unsigned int jna_body_get_ignition_output(void) {
  return (OBDC_IGNITION_ON_PORT->ODR >> OBDC_IGNITION_ON_PIN) & 0x1U;
}

void jna_body_trigger_tim8_irq(void) {
  LEFT_TIM->SR = TIM_SR_UIF;
  bldc_tim8_handler();
}

unsigned int jna_body_get_tim8_sr(void) {
  return LEFT_TIM->SR;
}

int jna_body_get_left_dc_pha_a(void) {
  return rtY_Left.DC_phaA;
}

bool jna_body_can_pop_tx(uint32_t *out_addr, uint8_t *out_returned, uint8_t *out_data, uint8_t *out_len,
                         uint8_t *out_extended, uint8_t *out_fd) {
  CANPacket_t pkt;
  if (can_pop(can_queues[BODY_BUS_NUMBER], &pkt)) {
    *out_addr = pkt.addr;
    *out_returned = pkt.returned;
    *out_len = pkt.data_len_code;
    *out_extended = pkt.extended;
    *out_fd = pkt.fd;
    if (pkt.data_len_code > 0U) {
      (void)memcpy(out_data, pkt.data, pkt.data_len_code);
    }
    return true;
  }
  return false;
}

bool jna_body_can_pop_rx(uint32_t *out_addr, uint8_t *out_bus, uint8_t *out_rejected, uint8_t *out_returned,
                         uint8_t *out_data, uint8_t *out_len, uint8_t *out_extended, uint8_t *out_fd) {
  CANPacket_t pkt;
  if (can_pop(&can_rx_q, &pkt)) {
    *out_addr = pkt.addr;
    *out_bus = pkt.bus;
    *out_rejected = pkt.rejected;
    *out_returned = pkt.returned;
    *out_len = pkt.data_len_code;
    *out_extended = pkt.extended;
    *out_fd = pkt.fd;
    if (pkt.data_len_code > 0U) {
      (void)memcpy(out_data, pkt.data, pkt.data_len_code);
    }
    return true;
  }
  return false;
}
