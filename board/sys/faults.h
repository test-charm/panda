#include "board/sys/sys.h"

#ifdef E2E_TEST
// In e2e tests, override PERMANENT_FAULTS to test the permanent fault code path.
// FAULT_UNUSED_INTERRUPT_HANDLED is never triggered by any e2e test tick path.
#undef PERMANENT_FAULTS
#define PERMANENT_FAULTS FAULT_UNUSED_INTERRUPT_HANDLED
#endif

uint8_t fault_status = FAULT_STATUS_NONE;
uint32_t faults = 0U;

void fault_occurred(uint32_t fault) {
  if ((faults & fault) == 0U) {
    if ((PERMANENT_FAULTS & fault) != 0U) {
      print("Permanent fault occurred: 0x"); puth(fault); print("\n");
      fault_status = FAULT_STATUS_PERMANENT;
    } else {
      print("Temporary fault occurred: 0x"); puth(fault); print("\n");
      fault_status = FAULT_STATUS_TEMPORARY;
    }
  }
  faults |= fault;
}

void fault_recovered(uint32_t fault) {
  if ((PERMANENT_FAULTS & fault) == 0U) {
    faults &= ~fault;
  } else {
    print("Cannot recover from a permanent fault!\n");
  }
}
