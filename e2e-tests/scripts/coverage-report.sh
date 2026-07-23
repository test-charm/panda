#!/bin/bash
# Generate C code coverage report from Clang profraw data.
# Called by ./gradlew cucumberCoverage after tests complete.
#
# Prerequisites:
#   - libpanda.dylib built with COVERAGE=1 (see build.sh)
#   - default.profraw produced by LLVM_PROFILE_FILE env var
#
# Output:
#   - Terminal: coverage summary printed to stdout
#   - build/coverage/coverage.profdata  (merged profile)
#   - build/coverage/coverage.lcov      (LCOV trace file)
#   - build/coverage/coverage.json      (JSON export)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
E2E_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PROJECT_ROOT="$(cd "$E2E_DIR/.." && pwd)"
COVERAGE_DIR="$E2E_DIR/build/coverage"
BOARD="${BOARD:-cuatro}"
DYLIB="$E2E_DIR/src/test/c/libpanda_${BOARD}.dylib"
PROFRAW="$COVERAGE_DIR/default.profraw"
PROFDATA="$COVERAGE_DIR/coverage.profdata"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}[coverage] Generating C code coverage report...${NC}"

# ---- Validate inputs ----
if [ ! -f "$PROFRAW" ]; then
    echo -e "${RED}[coverage] ERROR: $PROFRAW not found.${NC}"
    echo "[coverage] Ensure tests ran with LLVM_PROFILE_FILE set."
    exit 1
fi

if [ ! -f "$DYLIB" ]; then
    echo -e "${RED}[coverage] ERROR: $DYLIB not found.${NC}"
    echo "[coverage] Rebuild with: COVERAGE=1 bash src/test/c/build.sh"
    exit 1
fi

# ---- Merge profraw → profdata ----
echo -e "${YELLOW}[coverage] Merging profile data...${NC}"
xcrun llvm-profdata merge "$PROFRAW" -o "$PROFDATA"

# ---- Terminal text report (summary only) ----
echo ""
echo -e "${GREEN}═══════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  C Code Coverage Report (source-based)${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════════${NC}"
echo ""

# Show per-file coverage: regions, functions, lines
xcrun llvm-cov report "$DYLIB" \
    -instr-profile="$PROFDATA" \
    -ignore-filename-regex='\.venv/|fake_stm\.h|libpanda\.c|stm32h7_config\.h|harness\.h|interrupts\.h|uart\.h' \
    | grep -v '^---' | grep -v '^Files' | grep -v '^TOTAL' || true

TOTAL_LINE=$(xcrun llvm-cov report "$DYLIB" \
    -instr-profile="$PROFDATA" \
    -ignore-filename-regex='\.venv/|fake_stm\.h|libpanda\.c|stm32h7_config\.h|harness\.h|interrupts\.h|uart\.h' \
    | grep '^TOTAL' || echo "TOTAL (no data)")

echo ""
echo -e "${GREEN}───────────────────────────────────────────────────────${NC}"
echo -e "${GREEN}$TOTAL_LINE${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════════${NC}"

# ---- LCOV export (for toolchain integration) ----
echo ""
echo -e "${YELLOW}[coverage] Exporting LCOV trace...${NC}"
xcrun llvm-cov export "$DYLIB" \
    -instr-profile="$PROFDATA" \
    -format=lcov \
    -ignore-filename-regex='\.venv/|fake_stm\.h|libpanda\.c|stm32h7_config\.h|harness\.h|interrupts\.h|uart\.h' \
    > "$COVERAGE_DIR/coverage.lcov"

# ---- HTML report ----
echo -e "${YELLOW}[coverage] Generating HTML report...${NC}"
HTML_DIR="$COVERAGE_DIR/html"
xcrun llvm-cov show "$DYLIB" \
    -instr-profile="$PROFDATA" \
    -format=html \
    -output-dir="$HTML_DIR" \
    -project-title='Panda Firmware E2E Coverage' \
    -ignore-filename-regex='\.venv/|fake_stm\.h|libpanda\.c|stm32h7_config\.h|harness\.h|interrupts\.h|uart\.h'

# ---- JSON export (for programmatic consumption) ----
echo -e "${YELLOW}[coverage] Exporting JSON...${NC}"
xcrun llvm-cov export "$DYLIB" \
    -instr-profile="$PROFDATA" \
    -format=text \
    -ignore-filename-regex='\.venv/|fake_stm\.h|libpanda\.c|stm32h7_config\.h|harness\.h|interrupts\.h|uart\.h' \
    > "$COVERAGE_DIR/coverage.json"

echo ""
echo -e "${GREEN}[coverage] Reports written to: $COVERAGE_DIR/${NC}"
echo -e "  coverage.profdata  — merged profile (for llvm-cov)"
echo -e "  coverage.lcov      — LCOV trace (for genhtml / Codecov)"
echo -e "  coverage.json      — JSON export"
echo -e "  html/index.html    — HTML report (open in browser)"
echo ""
echo -e "${GREEN}[coverage] Done.${NC}"
