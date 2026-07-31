// Minimal stub for stm32h7xx.h — provides CMSIS types needed by body firmware
// without pulling in the full STM32 CMSIS HAL (which conflicts with fake_stm.h).
#pragma once

// GPIO_TypeDef is already provided by fake_stm.h (included before this file).
// ADC_TypeDef, TIM_TypeDef also come from fake_stm.h.

// Minimal types from the real stm32h7xx.h that body headers may need.
typedef enum { RESET = 0, SET = !RESET } FlagStatus, ITStatus;
typedef enum { DISABLE = 0, ENABLE = !DISABLE } FunctionalState;
typedef enum { SUCCESS = 0, ERROR = !SUCCESS } ErrorStatus;

#define SET_BIT(REG, BIT)     ((REG) |= (BIT))
#define CLEAR_BIT(REG, BIT)   ((REG) &= ~(BIT))
#define READ_BIT(REG, BIT)    ((REG) & (BIT))
#define CLEAR_REG(REG)        ((REG) = (0x0))
#define WRITE_REG(REG, VAL)   ((REG) = (VAL))
#define READ_REG(REG)         ((REG))
#define MODIFY_REG(REG, CLEARMASK, SETMASK)  WRITE_REG((REG), (((READ_REG(REG)) & (~(CLEARMASK))) | (SETMASK)))

// UID_BASE — needed by spi.h / usb.h
#define UID_BASE  ((uint32_t)0x1FF1E800UL)

// FDCAN register base address (needed by llfdcan_declarations.h)
#define FDCAN1_BASE  0x4000AC00UL
#define FDCAN2_BASE  0x4000B000UL
#define FDCAN3_BASE  0x4000B400UL

// USB SRAM base
#define USB_SRAM_BASE  0x40006800UL

// Flash base
#define FLASH_BASE  0x08000000UL

// SRAM1 base
#define SRAM1_BASE  0x24000000UL

#define __IO volatile
