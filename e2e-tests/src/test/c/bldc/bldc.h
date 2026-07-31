// E2E stub: overrides board/body/bldc/bldc.h for host compilation.
// The real BLDC controller uses Simulink auto-code with word-size checks
// that fail on macOS (8-byte long vs STM32 32-bit). This stub provides
// minimal implementations for e2e testing.
// NOTE: The real bldc.h has #ifndef BLDC_H guard. We #define BLDC_H in
// libpanda_body.c to skip it, so this stub must NOT have the same guard.

#include "board/body/bldc/bldc_defs.h"
#include "board/body/boards/board_declarations.h"

#include <stdint.h>
#include <stdbool.h>

#include "board/stm32h7/lladc.h"

// Minimal Simulink types (matching BLDC_controller.h)
typedef struct { double n_mot; uint8_t z_errCode; } ExtY;
typedef struct { double spd_ref; } ExtU;
typedef struct { void *_pad[100]; } DW;
typedef struct { void *_pad[50]; } P;
typedef struct tag_RTM {
  P *defaultParam;
  ExtU *inputs;
  ExtY *outputs;
  DW *dwork;
} RT_MODEL;

// Stub Simulink functions
static inline void BLDC_controller_initialize(RT_MODEL *const rtM) { (void)rtM; }
static inline void BLDC_controller_step(RT_MODEL *const rtM) { (void)rtM; }

// Parameter data
static P rtP_Left, rtP_Right;

// Model instances
static RT_MODEL rtM_Left_Obj;
static RT_MODEL rtM_Right_Obj;

RT_MODEL *const rtM_Left = &rtM_Left_Obj;
RT_MODEL *const rtM_Right = &rtM_Right_Obj;

static DW   rtDW_Left;
static ExtU rtU_Left;
static ExtY rtY_Left;

static DW   rtDW_Right;
static ExtU rtU_Right;
static ExtY rtY_Right;

// Motor globals — declared extern here, defined in libpanda_body.c.
// These are referenced by body/can.h before bldc.h is included.
extern volatile int rpm_left;
extern volatile int rpm_right;
extern volatile bool enable_motors;

static const uint16_t pwm_res = (((uint32_t)CORE_FREQ * 1000000U / 2U) / PWM_FREQ);

void motor_set_enable(bool enable) {
  enable_motors = enable;
}

float motor_encoder_get_speed_rpm(uint8_t motor) {
  (void)motor;
  return 0.0f;
}

void bldc_init(void) {
  // No-op: motor hardware init not needed for e2e comms testing
}

void bldc_step(void) {
  // No-op: motor control not needed for e2e comms testing
}
