// Stub: provides siren/sound declarations used by main.c tick_handler()
#pragma once
#include <stdbool.h>

extern bool siren_enabled;
extern uint32_t siren_countdown;

void fake_siren_set(bool enabled);
