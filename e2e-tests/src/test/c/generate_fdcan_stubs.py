#!/usr/bin/env python3
"""
Generate e2e-adapted FDCAN stubs from real firmware source.

Extracts can_init(), can_set_speed() from board/drivers/fdcan.h
and their callees from board/stm32h7/llfdcan.h, then applies
host-environment transforms:

  1. Strip while(…) polling loops (hardware status bits never change)
  2. Strip REGISTER_INTERRUPT macros
  3. Rename function calls: llcan_* → e2e_llcan_*, fdcan_* → e2e_fdcan_*
  4. Replace CANIF_FROM_CAN_NUM → &fake_fdcan[] pointer arithmetic
  5. Replace FDCAN_START_ADDRESS arithmetic → fake_fdcan_sram offset
  6. fdcan_exit_init: also clear CCE bit (HW does this, we must too)
  7. Prefix all functions with static e2e_
  8. Strip process_can() call

Usage: python3 generate_fdcan_stubs.py > fdcan_e2e.gen.c
"""

import re
import sys

PROJECT_ROOT = "/Users/joseph/Documents/opensource_workspace/panda"

# ── source files ──────────────────────────────────────────────
LLFDCAN_H = f"{PROJECT_ROOT}/board/stm32h7/llfdcan.h"
FDCAN_H   = f"{PROJECT_ROOT}/board/drivers/fdcan.h"

# ── functions to extract (source_file, function_name) ─────────
EXTRACT = [
    (LLFDCAN_H, "fdcan_request_init"),
    (LLFDCAN_H, "fdcan_exit_init"),
    (LLFDCAN_H, "llcan_set_speed"),
    (LLFDCAN_H, "llcan_init"),
    (LLFDCAN_H, "llcan_clear_send"),
    (FDCAN_H, "can_set_speed"),
    (FDCAN_H, "can_init"),
    (FDCAN_H, "can_clear_send"),
]

# Functions that keep their original name (public API — called by can_init_all() etc.)
KEEP_ORIGINAL_NAME = {"can_init", "can_clear_send"}


def read_file(path):
    with open(path) as f:
        return f.read()


def find_functions(source, func_name):
    """Find all occurrences of func_name in source, return list of (start_line, end_line)."""
    lines = source.split("\n")
    pattern = re.compile(
        r"^\s*(?:static\s+)?(?:bool|void)\s+" + re.escape(func_name) + r"\s*\("
    )
    results = []
    i = 0
    while i < len(lines):
        if pattern.match(lines[i]):
            # found function start — now find the opening brace
            j = i
            while j < len(lines) and "{" not in lines[j]:
                j += 1
            if j >= len(lines):
                break
            # count braces from the opening brace line
            depth = 0
            for k in range(j, len(lines)):
                for ch in lines[k]:
                    if ch == "{":
                        depth += 1
                    elif ch == "}":
                        depth -= 1
                        if depth == 0:
                            results.append((i, k))
                            i = k  # advance past this function
                            break
                if depth == 0:
                    break
            else:
                i = j + 1  # no closing brace found, skip
                continue
        i += 1
    return results


def extract_lines(source, start, end):
    return source.split("\n")[start:end + 1]


def transform_lines(lines, func_name):
    """Apply line-by-line transformations for the e2e environment."""
    result = []
    skip_while_block = False
    while_block_depth = 0

    # ── Pre-pass: special-case transformations per function ──
    if func_name == "can_clear_send":
        # Strip rate-limit guard and can_health accesses.
        # We want: e2e_llcan_clear_send(FDCANx); — the reset always happens in e2e.
        new_lines = []
        skip_guard = False
        guard_depth = 0
        for line in lines:
            if "static uint32_t last_reset" in line:
                continue
            if "microsecond_timer_get" in line:
                continue
            if "if (get_ts_elapsed" in line:
                skip_guard = True
                guard_depth = line.count("{")
                continue
            if "can_health" in line or "last_reset = time" in line:
                if "can_core_reset_cnt" in line:
                    pass  # Keep can_core_reset_cnt counter
                else:
                    continue
            if skip_guard:
                if "llcan_clear_send" in line:
                    # Keep the reset call even inside the guard block
                    pass
                elif "can_core_reset_cnt" in line:
                    pass  # Keep the reset counter
                else:
                    guard_depth += line.count("{") - line.count("}")
                    if guard_depth <= 0:
                        skip_guard = False
                    continue
            new_lines.append(line)
        lines = new_lines

    # ── Pass 1: while-loop removal ──
    pass1 = []
    for line in lines:
        # ── Remove REGISTER_INTERRUPT macros ──
        if "REGISTER_INTERRUPT" in line:
            continue

        # ── Remove process_can call ──
        if "process_can(" in line and "define" not in line and "void" not in line:
            continue

        # ── Handle while-loop removal ──
        while_match = re.match(r"^\s*while\s*\(.*\)\s*;?\s*(//.*)?$", line)
        if while_match:
            continue

        while_block_start = re.match(r"^\s*while\s*\(.*\)\s*\{?\s*(//.*)?$", line)
        if while_block_start and not skip_while_block:
            brace_count = line.count("{") - line.count("}")
            if brace_count == 0:
                continue
            skip_while_block = True
            while_block_depth = brace_count
            if while_block_depth <= 0:
                skip_while_block = False
            continue

        if skip_while_block:
            for ch in line:
                if ch == "{":
                    while_block_depth += 1
                elif ch == "}":
                    while_block_depth -= 1
            if while_block_depth <= 0:
                skip_while_block = False
            continue

        pass1.append(line)

    # ── Pass 2: RAM flush transformation ──
    # Convert FDCAN_START_ADDRESS-based flush to use fake_fdcan_sram offsets.
    text = "\n".join(pass1)
    text = re.sub(
        r"uint32_t RxFIFO0SA = FDCAN_START_ADDRESS \+ \(can_number \* FDCAN_OFFSET\);\n"
        r"\s*uint32_t TxFIFOSA = RxFIFO0SA \+ \(FDCAN_RX_FIFO_0_EL_CNT \* FDCAN_RX_FIFO_0_EL_SIZE\);",
        r"uint32_t start_offset = can_number * FDCAN_OFFSET;\n"
        r"    uint32_t end_offset = start_offset + (FDCAN_RX_FIFO_0_EL_CNT * FDCAN_RX_FIFO_0_EL_SIZE);",
        text,
    )
    text = re.sub(
        r"uint32_t EndAddress = TxFIFOSA \+ \(FDCAN_TX_FIFO_EL_CNT \* FDCAN_TX_FIFO_EL_SIZE\);\n"
        r"(\s*)for \(uint32_t RAMcounter = RxFIFO0SA; RAMcounter < EndAddress; RAMcounter \+= 4U\) \{\n"
        r"\s*\*\(uint32_t \*\)\(RAMcounter\) = 0x00000000;\n",
        r"end_offset += (FDCAN_TX_FIFO_EL_CNT * FDCAN_TX_FIFO_EL_SIZE);\n"
        r"\1for (uint32_t RAMcounter = start_offset; RAMcounter < end_offset; RAMcounter += 4U) {\n"
        r"\1    *(uint32_t *)(fake_fdcan_sram + RAMcounter) = 0x00000000;\n",
        text,
    )
    result = text.split("\n")

    # ── Pass 3: remaining substitutions ──
    final = []
    for line in result:
        line = re.sub(
            r"\bCANIF_FROM_CAN_NUM\s*\(\s*(\w+)\s*\)",
            r"&fake_fdcan[\1]",
            line,
        )
        line = re.sub(
            r"\bCAN_NUM_FROM_CANIF\s*\(\s*(\w+)\s*\)",
            r"(uint32_t)(\1 - fake_fdcan)",
            line,
        )
        if func_name == "fdcan_exit_init":
            line = line.replace(
                "FDCAN_CCCR_INIT);",
                "FDCAN_CCCR_INIT | FDCAN_CCCR_CCE);  // HW auto-clears CCE",
            )
        for callee in ["can_set_speed", "llcan_set_speed", "llcan_init", "llcan_clear_send",
                       "fdcan_request_init", "fdcan_exit_init"]:
            line = re.sub(
                rf"\b{callee}\s*\(",
                f"e2e_{callee}(",
                line,
            )
        final.append(line)

    return final


def rename_signature(line, func_name):
    """Add static and e2e_ prefix to function signature."""
    return re.sub(
        rf"^(static\s+)?(bool|void)\s+{re.escape(func_name)}\s*\(",
        rf"static \2 e2e_{func_name}(",
        line,
    )


def generate():
    header = """// Auto-generated by generate_fdcan_stubs.py — DO NOT EDIT.
// Faithful reproductions of real firmware FDCAN functions,
// adapted to write to fake FDCAN_GlobalTypeDef instances instead of MMIO.
// Regenerate: python3 generate_fdcan_stubs.py > fdcan_e2e.gen.c

"""

    all_lines = [header]

    for src_file, func_name in EXTRACT:
        source = read_file(src_file)
        occurrences = find_functions(source, func_name)
        if not occurrences:
            print(f"WARNING: {func_name} not found in {src_file}", file=sys.stderr)
            continue

        # Use the first occurrence (there should be only one)
        start, end = occurrences[0]
        raw_lines = extract_lines(source, start, end)

        # Rename signature on first line (unless it's a public API)
        if func_name not in KEEP_ORIGINAL_NAME:
            raw_lines[0] = rename_signature(raw_lines[0], func_name)
        # public API: keep original name, remove static (shadow header declares as extern)

        transformed = transform_lines(raw_lines, func_name)

        all_lines.append(f"// From {src_file}:{start+1}")
        all_lines.extend(transformed)
        all_lines.append("")

    return "\n".join(all_lines)


if __name__ == "__main__":
    print(generate())
