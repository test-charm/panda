// Stub: overrides board/drivers/harness.h for host compilation
#pragma once
#include <stdint.h>
#include <stdbool.h>

#define HARNESS_STATUS_NC 0
#define HARNESS_STATUS_NORMAL 1
#define HARNESS_STATUS_FLIPPED 2

typedef uint32_t GPIO_TypeDef;

struct harness_configuration {
    int _unused;
};

typedef struct harness_configuration harness_configuration;

void set_intercept_relay(bool intercept, bool ignition_relay);
