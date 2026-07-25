#!/bin/bash
# =============================================================================
# run_all_coverage.sh — Partitioned E2E test runner with combined coverage
# =============================================================================
# Runs all .feature tests exactly once, partitioned by board tags:
#   1. General tests (no board tag)   → board=cuatro
#   2. @cuatro tests                  → board=cuatro
#   3. @tres-only tests               → board=tres
#   4. @red-only tests                → board=red
#
# Then merges per-board coverage data into a single combined report.
#
# Output:
#   build/coverage/profraws/          — raw coverage profiles per board
#   build/coverage/{board}.lcov       — per-board LCOV trace files
#   build/coverage/merged.lcov        — combined LCOV trace file
#   build/coverage/html/index.html    — combined HTML report
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
E2E_DIR="$SCRIPT_DIR"
PROJECT_ROOT="$(cd "$E2E_DIR/.." && pwd)"
COVERAGE_DIR="$E2E_DIR/build/coverage"
PROFRAW_DIR="$COVERAGE_DIR/profraws"
C_DIR="$E2E_DIR/src/test/c"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info()  { echo -e "${BLUE}[INFO]${NC}  $*"; }
log_ok()    { echo -e "${GREEN}[OK]${NC}    $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }
log_step()  { echo -e "\n${CYAN}━━━ $* ━━━${NC}"; }

# ---------------------------------------------------------------------------
# Phase 0: Build all 3 coverage native libs ONCE
# ---------------------------------------------------------------------------
log_step "Phase 0: Building coverage native libs for all boards"

for BOARD in cuatro tres red; do
    log_info "Building libpanda_${BOARD}.dylib (coverage)..."
    COVERAGE=1 bash "$C_DIR/build.sh" "$BOARD"
done
log_ok "All 3 coverage dylibs built."

# ---------------------------------------------------------------------------
# Clean + prepare
# ---------------------------------------------------------------------------
log_step "Preparing coverage output directories"
rm -rf "$COVERAGE_DIR"
mkdir -p "$PROFRAW_DIR"/{cuatro,tres,red}

# ---------------------------------------------------------------------------
# Helper: run cucumber with coverage, save profraw
# Uses the `cucumber` gradle task (not `cucumberCoverage`) to avoid
# rebuilding the native lib. Coverage dylibs are pre-built in Phase 0.
# We skip buildNativeLib to preserve the coverage-instrumented dylibs.
# LLVM_PROFILE_FILE is set externally to control output path.
# ---------------------------------------------------------------------------
run_coverage() {
    local label="$1"    # human-readable label for logging
    local board="$2"    # cuatro | tres | red
    local tags="$3"     # Cucumber tag expression
    local dest="$4"     # destination path for the profraw copy

    log_step "Running: $label (board=$board, tags=$tags)"

    local profraw_tmp="$COVERAGE_DIR/default.profraw"
    LLVM_PROFILE_FILE="$profraw_tmp" \
        ./gradlew cucumber -Pboard="$board" -Ptags="$tags" -x buildNativeLib

    if [ -f "$profraw_tmp" ]; then
        mkdir -p "$(dirname "$dest")"
        cp "$profraw_tmp" "$dest"
        log_ok "Profraw saved → $dest"
    else
        log_error "No profraw produced for: $label"
    fi
}

# ---------------------------------------------------------------------------
# Phase 1: General tests — scenarios with no board tag
# ---------------------------------------------------------------------------
log_info "Phase 1/4: General tests (no board tag)"

run_coverage \
    "General tests" \
    "cuatro" \
    "not @cuatro and not @tres and not @red" \
    "$PROFRAW_DIR/cuatro/general.profraw"

# ---------------------------------------------------------------------------
# Phase 2: @cuatro tests — includes combined @cuatro @tres scenarios
# ---------------------------------------------------------------------------
log_info "Phase 2/4: @cuatro-specific tests"

run_coverage \
    "@cuatro tests" \
    "cuatro" \
    "@cuatro" \
    "$PROFRAW_DIR/cuatro/cuatro_specific.profraw"

# ---------------------------------------------------------------------------
# Phase 3: @tres-only — excludes scenarios already covered by @cuatro run
# ---------------------------------------------------------------------------
log_info "Phase 3/4: @tres-only tests"

run_coverage \
    "@tres tests" \
    "tres" \
    "@tres and not @cuatro" \
    "$PROFRAW_DIR/tres/tres_specific.profraw"

# ---------------------------------------------------------------------------
# Phase 4: @red-only — excludes scenarios already covered
# ---------------------------------------------------------------------------
log_info "Phase 4/4: @red-only tests"

run_coverage \
    "@red tests" \
    "red" \
    "@red and not @cuatro and not @tres" \
    "$PROFRAW_DIR/red/red_specific.profraw"

# ===========================================================================
# Coverage Merge Phase
# ===========================================================================

IGNORE_REGEX='\.venv/|fake_stm\.h|libpanda\.c|stm32h7_config\.h|harness\.h|interrupts\.h|uart\.h'

# ---------------------------------------------------------------------------
# Phase 5: Per-board profraw → profdata → lcov
# ---------------------------------------------------------------------------
log_step "Phase 5: Per-board coverage merge (profraw → lcov)"

ALL_LCOV=()

for BOARD in cuatro tres red; do
    BOARD_PROFRAW_DIR="$PROFRAW_DIR/$BOARD"
    PROFDATA="$COVERAGE_DIR/${BOARD}.profdata"
    LCOV_FILE="$COVERAGE_DIR/${BOARD}.lcov"
    DYLIB="$C_DIR/libpanda_${BOARD}.dylib"

    # Collect profraw files
    PROFRAW_FILES=()
    if [ -d "$BOARD_PROFRAW_DIR" ]; then
        while IFS= read -r -d '' f; do
            PROFRAW_FILES+=("$f")
        done < <(find "$BOARD_PROFRAW_DIR" -name '*.profraw' -print0)
    fi

    if [ ${#PROFRAW_FILES[@]} -eq 0 ]; then
        log_warn "No profraw files for board=$BOARD, skipping."
        continue
    fi

    log_info "Board=$BOARD: merging ${#PROFRAW_FILES[@]} profraw files..."
    xcrun llvm-profdata merge "${PROFRAW_FILES[@]}" -o "$PROFDATA"

    log_info "Board=$BOARD: exporting lcov..."
    xcrun llvm-cov export "$DYLIB" \
        -instr-profile="$PROFDATA" \
        -format=lcov \
        -ignore-filename-regex="$IGNORE_REGEX" \
        > "$LCOV_FILE"

    ALL_LCOV+=("$LCOV_FILE")
    log_ok "Board=$BOARD lcov written ($(wc -l < "$LCOV_FILE") lines)"
done

# ---------------------------------------------------------------------------
# Phase 6: Merge all per-board lcov → merged.lcov
# ---------------------------------------------------------------------------
log_step "Phase 6: Merging per-board LCOV files"

if [ ${#ALL_LCOV[@]} -eq 0 ]; then
    log_error "No LCOV files produced. Aborting."
    exit 1
fi

MERGED_LCOV="$COVERAGE_DIR/merged.lcov"
python3 "$SCRIPT_DIR/scripts/merge_lcov.py" merge "$MERGED_LCOV" "${ALL_LCOV[@]}"
log_ok "Merged LCOV → $MERGED_LCOV"

# ---------------------------------------------------------------------------
# Phase 7: Combined HTML report
# ---------------------------------------------------------------------------
log_step "Phase 7: Generating combined HTML report"

HTML_DIR="$COVERAGE_DIR/html"
python3 "$SCRIPT_DIR/scripts/merge_lcov.py" html "$MERGED_LCOV" "$HTML_DIR" "$PROJECT_ROOT"
log_ok "HTML report → $HTML_DIR/index.html"

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  All E2E Tests + Combined Coverage — Complete${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "  Profraw files:   $PROFRAW_DIR/"
echo -e "  Per-board LCOV:  $COVERAGE_DIR/{cuatro,tres,red}.lcov"
echo -e "  Merged LCOV:     $MERGED_LCOV"
echo -e "  HTML Report:     $HTML_DIR/index.html"
echo ""

# Print combined summary line from merged lcov
python3 -c "
from pathlib import Path
import sys
sys.path.insert(0, '$SCRIPT_DIR/scripts')
from merge_lcov import parse_lcov
r = parse_lcov('$MERGED_LCOV')
total_lf = sum(len(v) for v in r.values())
total_lh = sum(sum(1 for c in v.values() if c > 0) for v in r.values())
pct = (total_lh / total_lf * 100) if total_lf > 0 else 0
print(f'  Combined: {total_lh}/{total_lf} lines covered ({pct:.1f}%) across {len(r)} files')
"
echo ""
log_ok "Done."
