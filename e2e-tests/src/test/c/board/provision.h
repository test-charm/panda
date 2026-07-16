// Stub: overrides board/provision.h for host compilation
#pragma once
#include <stdint.h>
void get_provision_chunk(uint8_t *out) { if (out) out[0] = 0; }
