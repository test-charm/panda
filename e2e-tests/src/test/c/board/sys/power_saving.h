// Stub: overrides board/sys/power_saving.h for host compilation
#pragma once
#include <stdbool.h>
void set_power_save_state(bool en) { (void)en; }
void enable_can_transceivers(bool en) { (void)en; }
void enter_stop_mode(void) {}
