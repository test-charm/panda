// E2E compatibility wrapper for board/body/bldc/bldc.h
// Fixes macOS LP64 word-size mismatch in Simulink auto-code
// and includes the real BLDC controller (~3700 lines of FOC math + lookup tables).
//
// Strategy:
//   1. Include <limits.h> early to satisfy #ifndef UCHAR_MAX guard in BLDC_controller.c
//   2. Then override ULONG_MAX/LONG_MAX to ILP32 values (ARM Cortex target)
//   3. Include real BLDC_controller.h/.c/.data.c — the #if checks now pass
//   4. ulong_T remains 64-bit (unsigned long) but is never actually used in the model structs
//   5. Provide real bldc_init()/bldc_step() through e2e peripheral stubs
//
// NOTE: The real bldc.h has #ifndef BLDC_H guard. We #define BLDC_H in
// libpanda_body.c to skip it, so this stub must NOT have the same guard.

// ============================================================================
// Step 1: Pre-include <limits.h> so BLDC_controller.c's #ifndef UCHAR_MAX skips it.
// This lets us control ULONG_MAX/LONG_MAX without <limits.h> overriding them later.
// ============================================================================
#include <limits.h>

// ============================================================================
// Step 2: Override word-size macros to match ARM Cortex ILP32 target.
// BLDC_controller.c checks: #if ULONG_MAX != 0xFFFFFFFFU → #error on macOS LP64.
// By including <limits.h> first (above), the #ifndef UCHAR_MAX guard in
// BLDC_controller.c prevents re-inclusion, so our values stick.
// ============================================================================
#undef ULONG_MAX
#undef LONG_MAX
#define ULONG_MAX  0xFFFFFFFFU
#define LONG_MAX   0x7FFFFFFF

// ============================================================================
// Step 3: Include real BLDC controller header (type definitions)
// Defines: RT_MODEL, ExtY (n_mot, DC_phaA/B/C, z_errCode), ExtU, DW, P, ConstP
// Note: ulong_T = unsigned long (64-bit on macOS) but never used in model structs.
// ============================================================================
#include "board/body/bldc/BLDC_controller.h"

// ============================================================================
// Step 4: Include real BLDC controller implementation (3306 lines of FOC math)
// The #if checks use our overridden ULONG_MAX/LONG_MAX values.
// ============================================================================
#include "board/body/bldc/BLDC_controller.c"

// ============================================================================
// Step 5: Include real BLDC controller parameter data
// Defines: const ConstP rtConstP (lookup tables), P rtP_Left (tunable params)
// ============================================================================
#include "board/body/bldc/BLDC_controller_data.c"

// ============================================================================
// Step 6: Real dependencies (same as real bldc.h)
// ============================================================================
#include "board/body/bldc/bldc_defs.h"              // LEFT_TIM, RIGHT_TIM, PWM_FREQ, RPM_DEADBAND, etc.
#include "board/body/boards/board_declarations.h"    // GPIO pin definitions (IGNITION_SW_PORT, etc.)
#include "board/stm32h7/lladc.h"                     // adc_get_raw(), adc_signal_t (e2e stub)

// ============================================================================
// Motor globals — declared extern here, defined in libpanda_body.c.
// Referenced by body/can.h before bldc.h is included.
// ============================================================================
extern volatile int rpm_left;
extern volatile int rpm_right;
extern volatile bool enable_motors;
extern int e2e_ctrl_mode_req_override;

// ============================================================================
// Battery globals — defined here (matching real bldc.h).
// NOTE: must be defined here, not in libpanda_body.c, to avoid duplicate symbols.
// ============================================================================
volatile uint16_t batt_voltage_raw = 0;
volatile uint16_t batt_percentage = 0;

// ============================================================================
// Model instances (matching real bldc.h)
// ============================================================================
static RT_MODEL rtM_Left_Obj;
static RT_MODEL rtM_Right_Obj;

RT_MODEL *const rtM_Left = &rtM_Left_Obj;
RT_MODEL *const rtM_Right = &rtM_Right_Obj;

static DW   rtDW_Left;                  // Observable states
static ExtU rtU_Left;                   // External inputs
static ExtY rtY_Left;                   // External outputs
// rtP_Left is defined in BLDC_controller_data.c (global, not static)

static DW   rtDW_Right;                 // Observable states
static ExtU rtU_Right;                  // External inputs
static ExtY rtY_Right;                  // External outputs
static P    rtP_Right;                  // Parameters (copied from rtP_Left)

// ============================================================================
// Calibration / current measurement variables (matching real bldc.h)
// ============================================================================
static int16_t curL_phaA = 0, curL_phaC = 0, curL_DC = 0;
static int16_t curR_phaA = 0, curR_phaC = 0, curR_DC = 0;

static uint16_t offsetcount = 0;
static uint32_t offsetrlA = 0;
static uint32_t offsetrlC = 0;
static uint32_t offsetrrA = 0;
static uint32_t offsetrrC = 0;
static uint32_t offsetdcl = 0;
static uint32_t offsetdcr = 0;

static bool enableFin = 0;

static const uint16_t pwm_res = (((uint32_t)CORE_FREQ * 1000000U / 2U) / PWM_FREQ);

// ============================================================================
// ADC channel definitions (matching real bldc.h)
// ============================================================================
#define ADC_CHANNEL_BLDC(a, c) {.adc = (a), .channel = (c), .sample_time = SAMPLETIME_16_CYCLES, .oversampling = OVERSAMPLING_4}

const adc_signal_t adc_curL_phaA = ADC_CHANNEL_BLDC(ADC2, 10);
const adc_signal_t adc_curL_phaC = ADC_CHANNEL_BLDC(ADC2, 11);
const adc_signal_t adc_curL_DC   = ADC_CHANNEL_BLDC(ADC2, 18);
const adc_signal_t adc_curR_phaA = ADC_CHANNEL_BLDC(ADC1, 7);
const adc_signal_t adc_curR_phaC = ADC_CHANNEL_BLDC(ADC1, 15);
const adc_signal_t adc_curR_DC   = ADC_CHANNEL_BLDC(ADC1, 5);
const adc_signal_t adc_batVoltage = ADC_CHANNEL_BLDC(ADC1, 4);

// ============================================================================
// Function implementations (matching real bldc.h)
// ============================================================================

void motor_set_enable(bool enable) {
  enable_motors = enable;
}

float motor_encoder_get_speed_rpm(uint8_t motor) {
  float speed_rpm = 0.0f;
  if (motor == BODY_MOTOR_LEFT) {
    speed_rpm = (float)rtY_Left.n_mot;
  } else if (motor == BODY_MOTOR_RIGHT) {
    speed_rpm = (float)rtY_Right.n_mot;
  }

  if (ABS(speed_rpm) < RPM_DEADBAND) {
    speed_rpm = 0.0f;
  }

  return speed_rpm;
}

void bldc_init(void) {
  adc_init(ADC1);
  adc_init(ADC2);

  // Initialize Hall Sensors for Left Motor (PB6, PB7, PB8)
  set_gpio_mode(GPIOB, 6, MODE_INPUT); set_gpio_pullup(GPIOB, 6, PULL_UP);
  set_gpio_mode(GPIOB, 7, MODE_INPUT); set_gpio_pullup(GPIOB, 7, PULL_UP);
  set_gpio_mode(GPIOB, 8, MODE_INPUT); set_gpio_pullup(GPIOB, 8, PULL_UP);

  // Initialize Hall Sensors for Right Motor (PA0, PA1, PA2)
  set_gpio_mode(GPIOA, 0, MODE_INPUT); set_gpio_pullup(GPIOA, 0, PULL_UP);
  set_gpio_mode(GPIOA, 1, MODE_INPUT); set_gpio_pullup(GPIOA, 1, PULL_UP);
  set_gpio_mode(GPIOA, 2, MODE_INPUT); set_gpio_pullup(GPIOA, 2, PULL_UP);

  // Setup the model pointers for Left motor
  rtM_Left->defaultParam = &rtP_Left;
  rtM_Left->inputs = &rtU_Left;
  rtM_Left->outputs = &rtY_Left;
  rtM_Left->dwork = &rtDW_Left;
  BLDC_controller_initialize(rtM_Left);

  /* Set BLDC controller parameters */
  rtP_Left.b_angleMeasEna       = 0;            // Motor angle input: 0 = estimated angle, 1 = measured angle
  rtP_Left.z_selPhaCurMeasABC   = 2;            // Left motor measured current phases {Green, Blue} = {iA, iB}
  rtP_Left.z_ctrlTypSel         = CTRL_TYP_SEL;
  rtP_Left.b_diagEna            = DIAG_ENA;
  rtP_Left.i_max                = (int16_t)(I_MOT_MAX * A2BIT_CONV) << 4;
  rtP_Left.n_max                = N_MOT_MAX << 4;
  rtP_Left.b_fieldWeakEna       = FIELD_WEAK_ENA;
  rtP_Left.id_fieldWeakMax      = (int16_t)(FIELD_WEAK_MAX * A2BIT_CONV) << 4;
  rtP_Left.a_phaAdvMax          = PHASE_ADV_MAX << 4;
  rtP_Left.r_fieldWeakHi        = FIELD_WEAK_HI << 4;
  rtP_Left.r_fieldWeakLo        = FIELD_WEAK_LO << 4;
  rtP_Left.z_maxCntRst          = 4000;
  rtP_Left.cf_speedCoef         = CF_SPEED_COEF;
  rtP_Left.t_errQual            = 1280U;         // 80ms at 16kHz loop rate
  rtP_Left.t_errDequal          = T_ERR_DEQUAL_CYCLES;

  // Setup the model pointers for Right motor
  rtP_Right = rtP_Left; // copy parameters
  rtP_Right.z_selPhaCurMeasABC  = 2;
  rtM_Right->defaultParam = &rtP_Right;
  rtM_Right->inputs = &rtU_Right;
  rtM_Right->outputs = &rtY_Right;
  rtM_Right->dwork = &rtDW_Right;
  BLDC_controller_initialize(rtM_Right);

  // Initialize GPIOs for Motor Control
  // Left Motor (TIM1): PE8(CH1N), PE9(CH1), PE10(CH2N), PE11(CH2), PE12(CH3N), PE13(CH3)
  set_gpio_alternate(GPIOE, 8, GPIO_AF1_TIM1);
  set_gpio_alternate(GPIOE, 9, GPIO_AF1_TIM1);
  set_gpio_alternate(GPIOE, 10, GPIO_AF1_TIM1);
  set_gpio_alternate(GPIOE, 11, GPIO_AF1_TIM1);
  set_gpio_alternate(GPIOE, 12, GPIO_AF1_TIM1);
  set_gpio_alternate(GPIOE, 13, GPIO_AF1_TIM1);

  // Right Motor (TIM8): PC6(CH1), PC7(CH2), PC8(CH3), PA5(CH1N), PB14(CH2N), PB15(CH3N)
  set_gpio_alternate(GPIOC, 6, GPIO_AF3_TIM8);
  set_gpio_alternate(GPIOC, 7, GPIO_AF3_TIM8);
  set_gpio_alternate(GPIOC, 8, GPIO_AF3_TIM8);
  set_gpio_alternate(GPIOA, 5, GPIO_AF3_TIM8);
  set_gpio_alternate(GPIOB, 14, GPIO_AF3_TIM8);
  set_gpio_alternate(GPIOB, 15, GPIO_AF3_TIM8);

  // --- LEFT MOTOR (TIM8) ---
  LEFT_TIM->PSC = 0;
  LEFT_TIM->ARR = pwm_res;                              // Set auto-reload register for PWM_FREQ
  LEFT_TIM->CR1 = TIM_CR1_CMS_0;                        // Center-aligned mode 1
  LEFT_TIM->RCR = 1;                                    // Update event once per 2 PWM periods (16kHz)

  LEFT_TIM->CCMR1 = TIM_CCMR1_OC1M_2 | TIM_CCMR1_OC1M_1 | TIM_CCMR1_OC1PE | \
                    TIM_CCMR1_OC2M_2 | TIM_CCMR1_OC2M_1 | TIM_CCMR1_OC2PE;
  LEFT_TIM->CCMR2 = TIM_CCMR2_OC3M_2 | TIM_CCMR2_OC3M_1 | TIM_CCMR2_OC3PE;

  LEFT_TIM->CCER = TIM_CCER_CC1E | TIM_CCER_CC1NE | \
                   TIM_CCER_CC2E | TIM_CCER_CC2NE | \
                   TIM_CCER_CC3E | TIM_CCER_CC3NE;

  // --- RIGHT MOTOR (TIM1) ---
  RIGHT_TIM->PSC = 0;
  RIGHT_TIM->ARR = pwm_res;
  RIGHT_TIM->CR1 = TIM_CR1_CMS_0;
  RIGHT_TIM->RCR = 1;

  RIGHT_TIM->CCMR1 = TIM_CCMR1_OC1M_2 | TIM_CCMR1_OC1M_1 | TIM_CCMR1_OC1PE | \
                     TIM_CCMR1_OC2M_2 | TIM_CCMR1_OC2M_1 | TIM_CCMR1_OC2PE;
  RIGHT_TIM->CCMR2 = TIM_CCMR2_OC3M_2 | TIM_CCMR2_OC3M_1 | TIM_CCMR2_OC3PE;

  RIGHT_TIM->CCER = TIM_CCER_CC1E | TIM_CCER_CC1NE | \
                    TIM_CCER_CC2E | TIM_CCER_CC2NE | \
                    TIM_CCER_CC3E | TIM_CCER_CC3NE;

  // Set dead time (20 cycles -> ~166ns with 120MHz clock) and enable motor outputs
  LEFT_TIM->BDTR = 20U | TIM_BDTR_MOE;
  RIGHT_TIM->BDTR = 20U | TIM_BDTR_MOE;

  // Generate an update event to load the registers
  LEFT_TIM->EGR = TIM_EGR_UG;
  RIGHT_TIM->EGR = TIM_EGR_UG;

  // Enable TIM8 update interrupt for bldc_step
  LEFT_TIM->DIER |= TIM_DIER_UIE;

  // Start the timers
  LEFT_TIM->CR1 |= TIM_CR1_CEN;
  RIGHT_TIM->CR1 |= TIM_CR1_CEN;
}

void bldc_step(void) {
  uint8_t ctrl_mode_req = (e2e_ctrl_mode_req_override >= 0) ? (uint8_t)e2e_ctrl_mode_req_override : CTRL_MOD_REQ;

  // Calibrate ADC offsets for the first few cycles
  if (offsetcount < 2000) {  // calibrate ADC offsets
    offsetcount++;
    uint32_t rawL_A = adc_get_raw(&adc_curL_phaA);
    uint32_t rawL_C = adc_get_raw(&adc_curL_phaC);
    uint32_t rawR_A = adc_get_raw(&adc_curR_phaA);
    uint32_t rawR_C = adc_get_raw(&adc_curR_phaC);
    uint32_t rawL_DC = adc_get_raw(&adc_curL_DC);
    uint32_t rawR_DC = adc_get_raw(&adc_curR_DC);

    if (offsetcount == 1) {
      offsetrlA = rawL_A; offsetrlC = rawL_C;
      offsetrrA = rawR_A; offsetrrC = rawR_C;
      offsetdcl = rawL_DC; offsetdcr = rawR_DC;
    } else {
      offsetrlA = (rawL_A + offsetrlA) / 2;
      offsetrlC = (rawL_C + offsetrlC) / 2;
      offsetrrA = (rawR_A + offsetrrA) / 2;
      offsetrrC = (rawR_C + offsetrrC) / 2;
      offsetdcl = (rawL_DC + offsetdcl) / 2;
      offsetdcr = (rawR_DC + offsetdcr) / 2;
    }
    return;
  }

  // Get Left motor currents
  curL_phaA = (int16_t)(((int32_t)offsetrlA - (int32_t)adc_get_raw(&adc_curL_phaA)) >> 5);
  curL_phaC = (int16_t)(((int32_t)offsetrlC - (int32_t)adc_get_raw(&adc_curL_phaC)) >> 5);
  curL_DC   = (int16_t)(((int32_t)offsetdcl - (int32_t)adc_get_raw(&adc_curL_DC)) >> 4);

  // Get Right motor currents
  curR_phaA = (int16_t)(((int32_t)offsetrrA - (int32_t)adc_get_raw(&adc_curR_phaA)) >> 5);
  curR_phaC = (int16_t)(((int32_t)offsetrrC - (int32_t)adc_get_raw(&adc_curR_phaC)) >> 5);
  curR_DC   = (int16_t)(((int32_t)offsetdcr - (int32_t)adc_get_raw(&adc_curR_DC)) >> 4);

  // Safety: Don't enable if offsets are bogus (e.g. ADC failed)
  if (offsetrrA == 0 || offsetrrC == 0 || !enable_motors) {
    enableFin = 0;
  } else {
    enableFin = 1;
  }

  // Read Hall Sensors
  rtU_Left.b_hallA = !((GPIOB->IDR >> 6) & 1);
  rtU_Left.b_hallB = !((GPIOB->IDR >> 7) & 1);
  rtU_Left.b_hallC = !((GPIOB->IDR >> 8) & 1);

  rtU_Right.b_hallA = !((GPIOA->IDR >> 0) & 1);
  rtU_Right.b_hallB = !((GPIOA->IDR >> 1) & 1);
  rtU_Right.b_hallC = !((GPIOA->IDR >> 2) & 1);

  if (!enableFin) {
    LEFT_TIM->BDTR &= ~TIM_BDTR_MOE;
    RIGHT_TIM->BDTR &= ~TIM_BDTR_MOE;
  } else {
    LEFT_TIM->BDTR |= TIM_BDTR_MOE;
    RIGHT_TIM->BDTR |= TIM_BDTR_MOE;
  }

  // read battery voltage
  batt_voltage_raw = adc_get_raw(&adc_batVoltage);

  int16_t batVoltageCalib = batt_voltage_raw * BAT_CALIB_REAL_VOLTAGE / BAT_CALIB_ADC;
  batt_percentage = 100 - (((420 * BAT_CELLS) - batVoltageCalib) / BAT_CELLS / VOLTS_PER_PERCENT / 100);

  // ========================= LEFT MOTOR ===========================
  rtU_Left.b_motEna      = enableFin;
  rtU_Left.z_ctrlModReq  = ctrl_mode_req;
  int deadband_rpm_left = rpm_left;
  if (ABS(deadband_rpm_left) < RPM_DEADBAND) {
    deadband_rpm_left = 0;
  }
  rtU_Left.r_inpTgt      = (CLAMP((int)deadband_rpm_left, -MAX_RPM, MAX_RPM) * RPM_TO_UNIT);

  rtU_Left.i_phaAB       = curL_phaA;
  rtU_Left.i_phaBC       = curL_phaC;
  rtU_Left.i_DCLink      = curL_DC;

  BLDC_controller_step(rtM_Left);

  int ul = rtY_Left.DC_phaA;
  int vl = rtY_Left.DC_phaB;
  int wl = rtY_Left.DC_phaC;

  LEFT_TIM->CCR1 = (uint16_t)CLAMP((ul + pwm_res / 2), PWM_MARGIN, pwm_res - PWM_MARGIN);
  LEFT_TIM->CCR2 = (uint16_t)CLAMP((vl + pwm_res / 2), PWM_MARGIN, pwm_res - PWM_MARGIN);
  LEFT_TIM->CCR3 = (uint16_t)CLAMP((wl + pwm_res / 2), PWM_MARGIN, pwm_res - PWM_MARGIN);

  // ========================= RIGHT MOTOR ===========================
  rtU_Right.b_motEna      = enableFin;
  rtU_Right.z_ctrlModReq  = ctrl_mode_req;
  int deadband_rpm_right = rpm_right;
  if (ABS(deadband_rpm_right) < RPM_DEADBAND) {
    deadband_rpm_right = 0;
  }
  rtU_Right.r_inpTgt      = -(CLAMP((int)deadband_rpm_right, -MAX_RPM, MAX_RPM) * RPM_TO_UNIT);

  rtU_Right.i_phaAB       = curR_phaA;
  rtU_Right.i_phaBC       = curR_phaC;
  rtU_Right.i_DCLink      = curR_DC;

  BLDC_controller_step(rtM_Right);

  int ur = rtY_Right.DC_phaA;
  int vr = rtY_Right.DC_phaB;
  int wr = rtY_Right.DC_phaC;

  RIGHT_TIM->CCR1 = (uint16_t)CLAMP((ur + pwm_res / 2), PWM_MARGIN, pwm_res - PWM_MARGIN);
  RIGHT_TIM->CCR2 = (uint16_t)CLAMP((vr + pwm_res / 2), PWM_MARGIN, pwm_res - PWM_MARGIN);
  RIGHT_TIM->CCR3 = (uint16_t)CLAMP((wr + pwm_res / 2), PWM_MARGIN, pwm_res - PWM_MARGIN);
}

// ============================================================================
// E2E helper: skip ADC calibration phase (for B9 testing).
// In production, the first 2000 bldc_step() calls calibrate ADC offsets.
// In e2e, adc_get_raw() always returns 0, so the offsets end up as 0,
// which causes the safety check to keep enableFin=0.
// This function sets offsetcount past the calibration threshold and
// sets non-zero offset values so the FOC safety check passes.
// ============================================================================
void e2e_bldc_skip_calibration(void) {
  offsetcount = 2000;
  offsetrrA = 1000;
  offsetrrC = 1000;
  offsetrlA = 1000;
  offsetrlC = 1000;
  offsetdcl = 500;
  offsetdcr = 500;
}
