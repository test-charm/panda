// Stub: overrides board/drivers/led.h for host compilation
#pragma once
void led_init(void) {}
void led_set(uint8_t led, uint8_t brightness) { (void)led; (void)brightness; }
