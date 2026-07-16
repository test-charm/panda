// libpanda_safety.c — compiles board/main.c safety functions as host .dylib
// for JNA-based mutation testing without hardware.
// Include-path stubs in board/ override hardware-specific headers.

#include "fake_stm.h"
#include "config.h"
#include <stdbool.h>

// harness_configuration needed by board_declarations.h
#include "board/drivers/harness.h"
#include "boards/board_declarations.h"

// ---- Hardware globals used by set_safety_mode() ----
uint32_t safety_tx_blocked;
uint32_t safety_rx_invalid;
bool can_silent;
uint32_t heartbeat_counter;
bool heartbeat_lost;

// ---- Stub for current_board->set_can_mode ----
void board_set_can_mode_stub(uint8_t mode) { (void)mode; }

// ---- Board instance ----
struct harness_configuration harness_config_stub;
struct board board_stub = {
    .harness_config = &harness_config_stub,
    .set_can_mode = board_set_can_mode_stub,
};
const struct board *current_board = &board_stub;

// ---- Function stubs ----
void set_intercept_relay(bool intercept, bool ignition_relay) {
    (void)intercept; (void)ignition_relay;
}
void can_clear_send(uint32_t can_if, uint8_t bus) {
    (void)can_if; (void)bus;
}
void can_init_all(void) {}

// ---- Real firmware headers ----
#include "board/health.h"
#include "board/sys/faults.h"
#include "board/libc.h"

// ---- Extracted safety functions from board/main.c ----
// Build script extracts set_safety_mode() + is_car_safety_mode()
// into _safety_mode_extracted.c. Mutations to board/main.c
// are caught by rebuilding.
#include "_safety_mode_extracted.c"

// ---- JNA API ----
#ifdef __cplusplus
extern "C" {
#endif

void jna_set_safety_mode(uint16_t mode, uint16_t param) {
    set_safety_mode(mode, param);
}

bool jna_get_can_silent(void) {
    return can_silent;
}

#ifdef __cplusplus
}
#endif
