// Stub: overrides board/drivers/gpio.h
#pragma once
#include <stdint.h>
#include <stdbool.h>

typedef uint32_t GPIO_TypeDef;

void set_gpio_mode(GPIO_TypeDef *gpio, uint8_t pin, uint8_t mode);
void set_gpio_output(GPIO_TypeDef *gpio, uint8_t pin, bool value);
void set_gpio_pullup(GPIO_TypeDef *gpio, uint8_t pin, uint8_t pull);
