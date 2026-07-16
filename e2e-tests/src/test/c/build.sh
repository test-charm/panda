#!/bin/bash
# Build native library from board/main.c for JNA testing.
# Compiles the FULL board/main.c (not just extracted functions).
# All hardware dependencies are stubbed via include-path overrides.
#
# Usage: ./build.sh
# Output: libpanda.dylib

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"

OPENDBC_INCLUDE="$PROJECT_ROOT/.venv/lib/python3.12/site-packages"

CC="${CC:-cc}"
CFLAGS="-std=gnu11 -fPIC -shared -O0 -g \
  -I$SCRIPT_DIR \
  -I$PROJECT_ROOT \
  -I$PROJECT_ROOT/board \
  -I$OPENDBC_INCLUDE \
  -Dmain=panda_main \
  -DALLOW_DEBUG \
  -Wno-unused-function \
  -Wno-unused-variable \
  -Wno-int-conversion \
  -Wno-incompatible-pointer-types \
  -Wno-macro-redefined \
  -Wno-incompatible-library-redeclaration \
  -Wno-pointer-to-int-cast"

OUTPUT="$SCRIPT_DIR/libpanda.dylib"

echo "[build] Compiling full board/main.c → libpanda.dylib ..."
$CC $CFLAGS -o "$OUTPUT" "$SCRIPT_DIR/libpanda.c"

echo "[build] Done: $OUTPUT"
ls -la "$OUTPUT"
