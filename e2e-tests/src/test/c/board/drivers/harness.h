// Stub: overrides board/drivers/harness.h
#include <stdint.h>
#include <stdbool.h>

#define HARNESS_STATUS_NC 0
#define HARNESS_STATUS_NORMAL 1
#define HARNESS_STATUS_FLIPPED 2

typedef uint32_t GPIO_TypeDef;

struct harness_t {
    uint8_t status;
    bool sbu_adc_lock;
    bool relay_driven;
    bool ignition_triggered;
    uint16_t sbu1_voltage_mV;
    uint16_t sbu2_voltage_mV;
};

struct harness_configuration {
    GPIO_TypeDef *GPIO_SBU1;
    GPIO_TypeDef *GPIO_SBU2;
    uint8_t pin_SBU1;
    uint8_t pin_SBU2;
    bool has_harness;
    uint16_t HARNESS_CONNECTED_THRESHOLD;
};
typedef struct harness_configuration harness_configuration;

extern struct harness_t harness;

void set_intercept_relay(bool intercept, bool ignition_relay);
void harness_init(void);
void harness_tick(void);
bool harness_check_ignition(void);
uint8_t harness_detect_orientation(void);
