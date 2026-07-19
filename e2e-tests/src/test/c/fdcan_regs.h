// FDCAN register types and bit definitions for host-side e2e testing.
// Mirrors the real STM32H7 FDCAN peripheral at the register level.
// This allows can_init() → llcan_init() → register writes to a fake FDCAN_GlobalTypeDef
// instance, making register-level verification possible in e2e tests.
#pragma once

#include <stdint.h>
#include <stdbool.h>

// ---- Helper macros ----
#define UNUSED(x) ((void)(x))
#define MIN(a, b) (((a) < (b)) ? (a) : (b))
#define __IO volatile

// ---- FDCAN Global TypeDef (mirrors stm32h725xx.h:319-374) ----
typedef struct {
  __IO uint32_t CREL;         // 0x000
  __IO uint32_t ENDN;         // 0x004
  __IO uint32_t RESERVED1;    // 0x008
  __IO uint32_t DBTP;         // 0x00C
  __IO uint32_t TEST;         // 0x010
  __IO uint32_t RWD;          // 0x014
  __IO uint32_t CCCR;         // 0x018
  __IO uint32_t NBTP;         // 0x01C
  __IO uint32_t TSCC;         // 0x020
  __IO uint32_t TSCV;         // 0x024
  __IO uint32_t TOCC;         // 0x028
  __IO uint32_t TOCV;         // 0x02C
  __IO uint32_t RESERVED2[4]; // 0x030-0x03C
  __IO uint32_t ECR;          // 0x040
  __IO uint32_t PSR;          // 0x044
  __IO uint32_t TDCR;         // 0x048
  __IO uint32_t RESERVED3;    // 0x04C
  __IO uint32_t IR;           // 0x050
  __IO uint32_t IE;           // 0x054
  __IO uint32_t ILS;          // 0x058
  __IO uint32_t ILE;          // 0x05C
  __IO uint32_t RESERVED4[8]; // 0x060-0x07C
  __IO uint32_t GFC;          // 0x080
  __IO uint32_t SIDFC;        // 0x084
  __IO uint32_t XIDFC;        // 0x088
  __IO uint32_t RESERVED5;    // 0x08C
  __IO uint32_t XIDAM;        // 0x090
  __IO uint32_t HPMS;         // 0x094
  __IO uint32_t NDAT1;        // 0x098
  __IO uint32_t NDAT2;        // 0x09C
  __IO uint32_t RXF0C;        // 0x0A0
  __IO uint32_t RXF0S;        // 0x0A4
  __IO uint32_t RXF0A;        // 0x0A8
  __IO uint32_t RXBC;         // 0x0AC
  __IO uint32_t RXF1C;        // 0x0B0
  __IO uint32_t RXF1S;        // 0x0B4
  __IO uint32_t RXF1A;        // 0x0B8
  __IO uint32_t RXESC;        // 0x0BC
  __IO uint32_t TXBC;         // 0x0C0
  __IO uint32_t TXFQS;        // 0x0C4
  __IO uint32_t TXESC;        // 0x0C8
  __IO uint32_t TXBRP;        // 0x0CC
  __IO uint32_t TXBAR;        // 0x0D0
  __IO uint32_t TXBCR;        // 0x0D4
  __IO uint32_t TXBTO;        // 0x0D8
  __IO uint32_t TXBCF;        // 0x0DC
  __IO uint32_t TXBTIE;       // 0x0E0
  __IO uint32_t TXBCIE;       // 0x0E4
  __IO uint32_t RESERVED6[2]; // 0x0E8-0x0EC
  __IO uint32_t TXEFC;        // 0x0F0
  __IO uint32_t TXEFS;        // 0x0F4
  __IO uint32_t TXEFA;        // 0x0F8
  __IO uint32_t RESERVED7;    // 0x0FC
} FDCAN_GlobalTypeDef;

// ---- FDCAN CCCR register bits ----
#define FDCAN_CCCR_INIT_Pos       (0U)
#define FDCAN_CCCR_INIT_Msk       (0x1UL << FDCAN_CCCR_INIT_Pos)
#define FDCAN_CCCR_INIT           FDCAN_CCCR_INIT_Msk
#define FDCAN_CCCR_CCE_Pos        (1U)
#define FDCAN_CCCR_CCE_Msk        (0x1UL << FDCAN_CCCR_CCE_Pos)
#define FDCAN_CCCR_CCE            FDCAN_CCCR_CCE_Msk
#define FDCAN_CCCR_ASM_Pos        (2U)
#define FDCAN_CCCR_ASM_Msk        (0x1UL << FDCAN_CCCR_ASM_Pos)
#define FDCAN_CCCR_ASM            FDCAN_CCCR_ASM_Msk
#define FDCAN_CCCR_CSA_Pos        (3U)
#define FDCAN_CCCR_CSA_Msk        (0x1UL << FDCAN_CCCR_CSA_Pos)
#define FDCAN_CCCR_CSA            FDCAN_CCCR_CSA_Msk
#define FDCAN_CCCR_CSR_Pos        (4U)
#define FDCAN_CCCR_CSR_Msk        (0x1UL << FDCAN_CCCR_CSR_Pos)
#define FDCAN_CCCR_CSR            FDCAN_CCCR_CSR_Msk
#define FDCAN_CCCR_MON_Pos        (5U)
#define FDCAN_CCCR_MON_Msk        (0x1UL << FDCAN_CCCR_MON_Pos)
#define FDCAN_CCCR_MON            FDCAN_CCCR_MON_Msk
#define FDCAN_CCCR_DAR_Pos        (6U)
#define FDCAN_CCCR_DAR_Msk        (0x1UL << FDCAN_CCCR_DAR_Pos)
#define FDCAN_CCCR_DAR            FDCAN_CCCR_DAR_Msk
#define FDCAN_CCCR_TEST_Pos       (7U)
#define FDCAN_CCCR_TEST_Msk       (0x1UL << FDCAN_CCCR_TEST_Pos)
#define FDCAN_CCCR_TEST           FDCAN_CCCR_TEST_Msk
#define FDCAN_CCCR_FDOE_Pos       (8U)
#define FDCAN_CCCR_FDOE_Msk       (0x1UL << FDCAN_CCCR_FDOE_Pos)
#define FDCAN_CCCR_FDOE           FDCAN_CCCR_FDOE_Msk
#define FDCAN_CCCR_BRSE_Pos       (9U)
#define FDCAN_CCCR_BRSE_Msk       (0x1UL << FDCAN_CCCR_BRSE_Pos)
#define FDCAN_CCCR_BRSE           FDCAN_CCCR_BRSE_Msk
#define FDCAN_CCCR_PXHD_Pos       (12U)
#define FDCAN_CCCR_PXHD_Msk       (0x1UL << FDCAN_CCCR_PXHD_Pos)
#define FDCAN_CCCR_PXHD           FDCAN_CCCR_PXHD_Msk
#define FDCAN_CCCR_TXP_Pos        (14U)
#define FDCAN_CCCR_TXP_Msk        (0x1UL << FDCAN_CCCR_TXP_Pos)
#define FDCAN_CCCR_TXP            FDCAN_CCCR_TXP_Msk
#define FDCAN_CCCR_NISO_Pos       (15U)
#define FDCAN_CCCR_NISO_Msk       (0x1UL << FDCAN_CCCR_NISO_Pos)
#define FDCAN_CCCR_NISO           FDCAN_CCCR_NISO_Msk

// ---- FDCAN TEST register bits ----
#define FDCAN_TEST_LBCK_Pos       (4U)
#define FDCAN_TEST_LBCK_Msk       (0x1UL << FDCAN_TEST_LBCK_Pos)
#define FDCAN_TEST_LBCK           FDCAN_TEST_LBCK_Msk

// ---- FDCAN NBTP register bits ----
#define FDCAN_NBTP_NTSEG2_Pos     (0U)
#define FDCAN_NBTP_NTSEG1_Pos     (8U)
#define FDCAN_NBTP_NBRP_Pos       (16U)
#define FDCAN_NBTP_NSJW_Pos       (25U)

// ---- FDCAN DBTP register bits ----
#define FDCAN_DBTP_DSJW_Pos       (0U)
#define FDCAN_DBTP_DTSEG2_Pos     (4U)
#define FDCAN_DBTP_DTSEG1_Pos     (8U)
#define FDCAN_DBTP_DBRP_Pos       (16U)

// ---- FDCAN TXBC register bits ----
#define FDCAN_TXBC_TBSA_Pos       (2U)
#define FDCAN_TXBC_TFQS_Pos       (24U)
#define FDCAN_TXBC_TFQM_Pos       (30U)
#define FDCAN_TXBC_TFQM_Msk       (0x1UL << FDCAN_TXBC_TFQM_Pos)
#define FDCAN_TXBC_TFQM           FDCAN_TXBC_TFQM_Msk

// ---- FDCAN TXESC register bits ----
#define FDCAN_TXESC_TBDS_Pos      (0U)

// ---- FDCAN RXESC register bits ----
#define FDCAN_RXESC_F0DS_Pos      (0U)

// ---- FDCAN XIDFC register bits ----
#define FDCAN_XIDFC_LSE_Pos       (16U)
#define FDCAN_XIDFC_LSE_Msk       (0x7FUL << FDCAN_XIDFC_LSE_Pos)
#define FDCAN_XIDFC_LSE           FDCAN_XIDFC_LSE_Msk

// ---- FDCAN SIDFC register bits ----
#define FDCAN_SIDFC_LSS_Pos       (16U)
#define FDCAN_SIDFC_LSS_Msk       (0xFFUL << FDCAN_SIDFC_LSS_Pos)
#define FDCAN_SIDFC_LSS           FDCAN_SIDFC_LSS_Msk

// ---- FDCAN GFC register bits ----
#define FDCAN_GFC_RRFE_Pos        (0U)
#define FDCAN_GFC_RRFE_Msk        (0x1UL << FDCAN_GFC_RRFE_Pos)
#define FDCAN_GFC_RRFE            FDCAN_GFC_RRFE_Msk
#define FDCAN_GFC_RRFS_Pos        (1U)
#define FDCAN_GFC_RRFS_Msk        (0x1UL << FDCAN_GFC_RRFS_Pos)
#define FDCAN_GFC_RRFS            FDCAN_GFC_RRFS_Msk
#define FDCAN_GFC_ANFE_Pos        (2U)
#define FDCAN_GFC_ANFE_Msk        (0x3UL << FDCAN_GFC_ANFE_Pos)
#define FDCAN_GFC_ANFE            FDCAN_GFC_ANFE_Msk
#define FDCAN_GFC_ANFS_Pos        (4U)
#define FDCAN_GFC_ANFS_Msk        (0x3UL << FDCAN_GFC_ANFS_Pos)
#define FDCAN_GFC_ANFS            FDCAN_GFC_ANFS_Msk

// ---- FDCAN RXF0C register bits ----
#define FDCAN_RXF0C_F0SA_Pos      (2U)
#define FDCAN_RXF0C_F0S_Pos       (16U)
#define FDCAN_RXF0C_F0OM_Pos      (31U)
#define FDCAN_RXF0C_F0OM_Msk      (0x1UL << FDCAN_RXF0C_F0OM_Pos)
#define FDCAN_RXF0C_F0OM          FDCAN_RXF0C_F0OM_Msk

// ---- FDCAN ILE register bits ----
#define FDCAN_ILE_EINT0_Pos       (0U)
#define FDCAN_ILE_EINT0_Msk       (0x1UL << FDCAN_ILE_EINT0_Pos)
#define FDCAN_ILE_EINT0           FDCAN_ILE_EINT0_Msk
#define FDCAN_ILE_EINT1_Pos       (1U)
#define FDCAN_ILE_EINT1_Msk       (0x1UL << FDCAN_ILE_EINT1_Pos)
#define FDCAN_ILE_EINT1           FDCAN_ILE_EINT1_Msk

// ---- FDCAN IE register bits ----
#define FDCAN_IE_RF0NE_Pos        (0U)
#define FDCAN_IE_RF0NE_Msk        (0x1UL << FDCAN_IE_RF0NE_Pos)
#define FDCAN_IE_RF0NE            FDCAN_IE_RF0NE_Msk
#define FDCAN_IE_RF0LE_Pos        (3U)
#define FDCAN_IE_RF0LE_Msk        (0x1UL << FDCAN_IE_RF0LE_Pos)
#define FDCAN_IE_RF0LE            FDCAN_IE_RF0LE_Msk
#define FDCAN_IE_TFEE_Pos         (11U)
#define FDCAN_IE_TFEE_Msk         (0x1UL << FDCAN_IE_TFEE_Pos)
#define FDCAN_IE_TFEE             FDCAN_IE_TFEE_Msk
#define FDCAN_IE_EPE_Pos          (23U)
#define FDCAN_IE_EPE_Msk          (0x1UL << FDCAN_IE_EPE_Pos)
#define FDCAN_IE_EPE              FDCAN_IE_EPE_Msk
#define FDCAN_IE_BOE_Pos          (25U)
#define FDCAN_IE_BOE_Msk          (0x1UL << FDCAN_IE_BOE_Pos)
#define FDCAN_IE_BOE              FDCAN_IE_BOE_Msk
#define FDCAN_IE_PEAE_Pos         (27U)
#define FDCAN_IE_PEAE_Msk         (0x1UL << FDCAN_IE_PEAE_Pos)
#define FDCAN_IE_PEAE             FDCAN_IE_PEAE_Msk
#define FDCAN_IE_PEDE_Pos         (28U)
#define FDCAN_IE_PEDE_Msk         (0x1UL << FDCAN_IE_PEDE_Pos)
#define FDCAN_IE_PEDE             FDCAN_IE_PEDE_Msk

// ---- FDCAN ILS register bits ----
#define FDCAN_ILS_TFEL_Pos        (11U)
#define FDCAN_ILS_TFEL_Msk        (0x1UL << FDCAN_ILS_TFEL_Pos)
#define FDCAN_ILS_TFEL            FDCAN_ILS_TFEL_Msk

// ---- FDCAN memory layout (mirrors llfdcan_declarations.h) ----
#define CAN_PCLK                  80000U     // KHz
#define BITRATE_PRESCALER         2U
#define CAN_SP_NOMINAL            80U        // 80% sampling point
#define CAN_SP_DATA_2M            80U
#define CAN_SP_DATA_5M            75U

#define CAN_QUANTA(speed, prescaler) (CAN_PCLK / ((speed) / 10U * (prescaler)))
#define CAN_SEG1(tq, sp)             (((tq) * (sp) / 100U) - 1U)
#define CAN_SEG2(tq, sp)             ((tq) * (100U - (sp)) / 100U)

#define FDCAN_START_ADDRESS         0U  // Overridden in libpanda.c
#define FDCAN_OFFSET                3384UL
#define FDCAN_OFFSET_W              846UL

#define FDCAN_RX_FIFO_0_EL_CNT      46UL
#define FDCAN_RX_FIFO_0_HEAD_SIZE   8UL
#define FDCAN_RX_FIFO_0_DATA_SIZE   64UL
#define FDCAN_RX_FIFO_0_EL_SIZE     (FDCAN_RX_FIFO_0_HEAD_SIZE + FDCAN_RX_FIFO_0_DATA_SIZE)
#define FDCAN_RX_FIFO_0_EL_W_SIZE   (FDCAN_RX_FIFO_0_EL_SIZE / 4UL)
#define FDCAN_RX_FIFO_0_OFFSET      0UL

#define FDCAN_TX_FIFO_EL_CNT        1UL
#define FDCAN_TX_FIFO_HEAD_SIZE     8UL
#define FDCAN_TX_FIFO_DATA_SIZE     64UL
#define FDCAN_TX_FIFO_EL_SIZE       (FDCAN_TX_FIFO_HEAD_SIZE + FDCAN_TX_FIFO_DATA_SIZE)
#define FDCAN_TX_FIFO_OFFSET        (FDCAN_RX_FIFO_0_OFFSET + (FDCAN_RX_FIFO_0_EL_CNT * FDCAN_RX_FIFO_0_EL_W_SIZE))

// ---- CAN identification ----
#define CAN_NAME_FROM_CANIF(CAN_DEV)  (((CAN_DEV) == FDCAN1) ? "FDCAN1" : (((CAN_DEV) == FDCAN2) ? "FDCAN2" : "FDCAN3"))
#define CAN_NUM_FROM_CANIF(CAN_DEV)   (((CAN_DEV) == FDCAN1) ? 0UL : (((CAN_DEV) == FDCAN2) ? 1UL : 2UL))
#define BUS_NUM_FROM_CAN_NUM(num)     (bus_config[num].bus_lookup)
#define CAN_NUM_FROM_BUS_NUM(num)     (bus_config[num].can_num_lookup)
