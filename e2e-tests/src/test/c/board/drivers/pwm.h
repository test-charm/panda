// Stub: overrides board/drivers/pwm.h
#include <stdint.h>
void pwm_init(TIM_TypeDef *TIM, uint8_t channel);
void pwm_set(TIM_TypeDef *TIM, uint8_t channel, uint8_t percentage);
