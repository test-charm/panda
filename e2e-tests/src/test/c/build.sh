#!/bin/bash
# Build native library from board/main.c for JNA testing.
# Compiles the FULL board/main.c (not just extracted functions).
# All hardware dependencies are stubbed via include-path overrides.
#
# Usage: ./build.sh [BOARD]
#   BOARD: cuatro (default) | tres | red
#   Output: libpanda_${BOARD}.dylib

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"

BOARD="${1:-cuatro}"
BOARD_UPPER="$(echo "$BOARD" | tr '[:lower:]' '[:upper:]')"

OPENDBC_INCLUDE="$PROJECT_ROOT/.venv/lib/python3.12/site-packages"

CC="${CC:-cc}"
CFLAGS="-std=gnu11 -fPIC -shared -O0 -g \
  -I$SCRIPT_DIR \
  -I$PROJECT_ROOT \
  -I$PROJECT_ROOT/board \
  -I$OPENDBC_INCLUDE \
  -Dmain=panda_main \
  -DALLOW_DEBUG \
  -DE2E_BOARD_$BOARD_UPPER \
  -DE2E_TEST \
  -Wno-unused-function \
  -Wno-unused-variable \
  -Wno-int-conversion \
  -Wno-incompatible-pointer-types \
  -Wno-macro-redefined \
  -Wno-incompatible-library-redeclaration \
  -Wno-pointer-to-int-cast"

# Coverage mode: instrument C code with Clang source-based coverage
if [ "${COVERAGE:-}" = "1" ]; then
    CFLAGS="$CFLAGS -fprofile-instr-generate -fcoverage-mapping"
    echo "[build] Coverage instrumentation enabled"
fi

OUTPUT="$SCRIPT_DIR/libpanda_${BOARD}.dylib"

# Skip rebuild if output is newer than all sources (only in non-coverage mode)
if [ "${COVERAGE:-}" != "1" ] && [ -f "$OUTPUT" ] \
    && [ "$OUTPUT" -nt "$SCRIPT_DIR/libpanda.c" ] \
    && [ "$OUTPUT" -nt "$PROJECT_ROOT/board/main.c" ] \
    && [ "$OUTPUT" -nt "$PROJECT_ROOT/board/stm32h7/llfdcan.h" ] \
    && [ "$OUTPUT" -nt "$PROJECT_ROOT/board/stm32h7/llfdcan_declarations.h" ] \
    && [ "$OUTPUT" -nt "$PROJECT_ROOT/board/drivers/fdcan.h" ] \
    && [ "$OUTPUT" -nt "$PROJECT_ROOT/board/drivers/can_common.h" ] \
    && [ "$OUTPUT" -nt "$PROJECT_ROOT/board/drivers/drivers.h" ] \
    && [ "$OUTPUT" -nt "$PROJECT_ROOT/board/sys/power_saving.h" ] \
    && [ "$OUTPUT" -nt "$SCRIPT_DIR/generate_bootkick_stubs.py" ] \
    && [ "$OUTPUT" -nt "$PROJECT_ROOT/board/drivers/bootkick.h" ] \
    && [ "$OUTPUT" -nt "$SCRIPT_DIR/fdcan_regs.h" ] \
    && [ "$OUTPUT" -nt "$SCRIPT_DIR/board/stm32h7/llfdcan_declarations.h" ] \
    && [ "$OUTPUT" -nt "$SCRIPT_DIR/board/stm32h7/lladc.h" ] \
    && [ "$OUTPUT" -nt "$PROJECT_ROOT/board/drivers/harness.h" ] \
    && [ "$OUTPUT" -nt "$PROJECT_ROOT/board/drivers/spi.h" ] \
    && [ "$OUTPUT" -nt "$SCRIPT_DIR/board/drivers/spi.h" ] \
    && [ "$OUTPUT" -nt "$SCRIPT_DIR/board/drivers/pwm.h" ] \
    && [ "$OUTPUT" -nt "$SCRIPT_DIR/board/drivers/led.h" ]; then
    echo "[build] libpanda_${BOARD}.dylib is up to date"
    ls -la "$OUTPUT"
    exit 0
fi

echo "[build] Compiling full board/main.c → libpanda_${BOARD}.dylib ..."
$CC $CFLAGS -o "$OUTPUT" "$SCRIPT_DIR/libpanda.c"

echo "[build] Done: $OUTPUT"
ls -la "$OUTPUT"
