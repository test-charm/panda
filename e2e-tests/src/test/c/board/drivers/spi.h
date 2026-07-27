// E2E wrapper: stubs hardware LL functions, then includes real board/drivers/spi.h.
// This lets spi_version_packet(), spi_rx_done(), spi_tx_done() compile for host testing.
#include <stdint.h>

// Forward-declare libc functions (provided by board/libc.h, included later)
void *memcpy(void *dest, const void *src, unsigned int len);
int memcmp(const void *ptr1, const void *ptr2, unsigned int num);

#define SPI_BUF_SIZE 4096U

// Declarations needed before real spi.h is pulled in (defined later in libpanda.c)
extern uint8_t hw_type;

// Hardware LL stubs (DMA, SPI peripheral init)
static inline void llspi_init(void) {}
static inline void llspi_mosi_dma(uint8_t *addr, int len) { (void)addr; (void)len; }
static inline void llspi_miso_dma(const uint8_t *addr, int len) { (void)addr; (void)len; }

// Include the real spi.h. Relative path goes up from
//   e2e-tests/src/test/c/board/drivers/spi.h
// to project root, then board/drivers/spi.h.
// We cannot use "board/drivers/spi.h" because -I$SCRIPT_DIR makes it resolve to this file.
#include "../../../../../../board/drivers/spi.h"
