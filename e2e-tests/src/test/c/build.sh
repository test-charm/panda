#!/bin/bash
# Build native library from board/main.c for JNA mutation testing.
# Extracts set_safety_mode() and is_car_safety_mode() from main.c at build time.
# Usage: ./build.sh
# Output: libpanda_safety.dylib

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"

OPENDBC_INCLUDE="$PROJECT_ROOT/.venv/lib/python3.12/site-packages"

# Extract just the safety mode functions from board/main.c
# set_safety_mode() (line 41) + is_car_safety_mode() (line 91)
SAFETY_SRC="$SCRIPT_DIR/_safety_mode_extracted.c"
echo "// Auto-extracted from board/main.c — do not edit" > "$SAFETY_SRC"
echo '#include "board/drivers/fdcan.h"' >> "$SAFETY_SRC"
echo '#include "opendbc/safety/can.h"' >> "$SAFETY_SRC"
echo '#include "opendbc/safety/safety.h"' >> "$SAFETY_SRC"
echo "" >> "$SAFETY_SRC"
# Extract from "this is the only way" through 2 function-closing braces
awk '/^\/\/ this is the only way to leave silent mode$/{ p=1; brace=0 }
     p {
         print
         if (/^}/) brace++
         if (brace == 2) exit
     }' "$PROJECT_ROOT/board/main.c" >> "$SAFETY_SRC"

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

OUTPUT="$SCRIPT_DIR/libpanda_safety.dylib"

echo "[build] Extracted safety functions from board/main.c"
echo "[build] Compiling → libpanda_safety.dylib ..."
$CC $CFLAGS -o "$OUTPUT" "$SCRIPT_DIR/panda_safety.c"

rm -f "$SAFETY_SRC"
echo "[build] Done: $OUTPUT"
ls -la "$OUTPUT"
