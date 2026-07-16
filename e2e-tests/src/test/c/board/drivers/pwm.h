// Stub: overrides board/drivers/pwm.h for host compilation
#pragma once
void pwm_init(void) {}
void pwm_set(uint8_t chan, uint8_t duty) { (void)chan; (void)duty; }
