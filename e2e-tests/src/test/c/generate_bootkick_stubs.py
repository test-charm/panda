#!/usr/bin/env python3
"""Generate e2e-adapted bootkick stub from real firmware source.

Extracts bootkick_tick() from board/drivers/bootkick.h and transforms:
  - static locals → file-scope e2e_* globals (accessible by JNA)
  - set_bootkick() call → commented out (fake GPIO writes corrupt memory)
  - Generates e2e_tick_handler_1hz() mirroring main.c's 1Hz block
  - Generates JNA accessor/reset functions

Usage: python3 generate_bootkick_stubs.py > bootkick_e2e.gen.c
"""

import re
import sys

PROJECT_ROOT = "/Users/joseph/Documents/opensource_workspace/panda"

BOOTKICK_H = f"{PROJECT_ROOT}/board/drivers/bootkick.h"
MAIN_C = f"{PROJECT_ROOT}/board/main.c"

FUNC_NAME = "bootkick_tick"

# static-local → e2e_* global name mapping
STATIC_RENAMES = {
    "bootkick_last_serial_ptr":    "e2e_bootkick_last_serial_ptr",
    "waiting_to_boot_countdown":   "e2e_waiting_countdown",
    "boot_reset_countdown":        "e2e_boot_reset_countdown",
    "bootkick_harness_status_prev":"e2e_bootkick_harness_prev",
    "bootkick_ign_prev":           "e2e_bootkick_ign_prev",
    "boot_state":                  "e2e_boot_state",
}


def read_file(path):
    with open(path) as f:
        return f.read()


def find_function(source, func_name):
    lines = source.split("\n")
    pattern = re.compile(r"^\s*void\s+" + re.escape(func_name) + r"\s*\(")
    for i, line in enumerate(lines):
        if pattern.match(line):
            j = i
            while j < len(lines) and "{" not in lines[j]:
                j += 1
            if j >= len(lines):
                break
            depth = 0
            for k in range(j, len(lines)):
                for ch in lines[k]:
                    if ch == "{":
                        depth += 1
                    elif ch == "}":
                        depth -= 1
                        if depth == 0:
                            return i, k
            break
    return None, None


def transform_body(lines):
    """Apply transformations to the function body."""
    result = []
    promoted_new_names = set(STATIC_RENAMES.values())
    for line in lines:
        # Rename static local references
        for old, new in STATIC_RENAMES.items():
            line = re.sub(r"\b" + re.escape(old) + r"\b", new, line)
        # Remove promoted declarations from function body
        stripped = line.strip().replace("static ", "")
        if not stripped.startswith("//") and not stripped.startswith("/*"):
            tokens = stripped.replace("=", " ").replace(";", " ").split()
            if len(tokens) >= 2 and tokens[0] in ("uint16_t", "uint8_t", "bool", "BootState"):
                if tokens[1] in promoted_new_names:
                    continue
        # Comment out set_bootkick call
        if "current_board->set_bootkick" in line:
            result.append(f"  // {line.strip()}  // commented: fake GPIO writes corrupt e2e globals")
            continue
        # Remove 'static' keyword from the renamed variables
        line = re.sub(r"\bstatic\s+(uint16_t|uint8_t|bool|BootState)\s+e2e_", r"\1 e2e_", line)
        result.append(line)
    return result


def find_1hz_block(source):
    """Find the 1Hz block in main.c that calls bootkick_tick."""
    lines = source.split("\n")
    # Look for lines around bootkick_tick call in main.c
    for i, line in enumerate(lines):
        if FUNC_NAME + "(" in line and ("started" in line or "recent_heartbeat" in line):
            # Found the call site. Look backwards for 'started' and 'recent_heartbeat' assignments
            started_line = None
            heartbeat_line = None
            for j in range(max(0, i - 15), i):
                if "bool started" in lines[j] or "started =" in lines[j]:
                    started_line = lines[j].strip()
                if "recent_heartbeat" in lines[j] and ("bool" in lines[j] or "=" in lines[j]):
                    heartbeat_line = lines[j].strip()
            return started_line, heartbeat_line, line.strip()
    return None, None, None


def extract_declarations(body_lines):
    """Extract the static local declarations from the body to promote to file scope."""
    decls = []
    for line in body_lines:
        stripped = line.strip()
        if stripped.startswith("static ") and any(
            name in stripped for name in STATIC_RENAMES
        ):
            # Extract: static TYPE NAME = VALUE;
            decls.append(line)
    return decls


def generate():
    bootkick_source = read_file(BOOTKICK_H)
    main_source = read_file(MAIN_C)

    start, end = find_function(bootkick_source, FUNC_NAME)
    if start is None:
        print(f"ERROR: {FUNC_NAME} not found in {BOOTKICK_H}", file=sys.stderr)
        sys.exit(1)

    # Extract the full function including the signature line
    full_lines = bootkick_source.split("\n")[start:end + 1]

    # Promote static local declarations to file scope
    static_decls = extract_declarations(full_lines)

    # Transform the body (remove static from locals, rename, comment out set_bootkick)
    body_lines = transform_body(full_lines)

    # Find the 1Hz pattern in main.c
    started_line, heartbeat_line, tick_call = find_1hz_block(main_source)

    # Estimate source line numbers for documentation
    bootkick_start_line = start + 1
    bootkick_end_line = end + 1

    output = []
    output.append("// Auto-generated by generate_bootkick_stubs.py — DO NOT EDIT.")
    output.append(f"// Extracted from {BOOTKICK_H}:{bootkick_start_line}-{bootkick_end_line}")
    output.append(f"// Regenerate: python3 generate_bootkick_stubs.py > bootkick_e2e.gen.c")
    output.append("")
    output.append("// ---- Promoted globals (was static locals in bootkick_tick) ----")
    for decl in static_decls:
        transformed = decl
        for old, new in STATIC_RENAMES.items():
            transformed = re.sub(r"\b" + re.escape(old) + r"\b", new, transformed)
        transformed = re.sub(r"\bstatic\s+", "", transformed)
        output.append(transformed)
    output.append("")

    output.append("// ---- Transformed bootkick_tick (state promoted to accessible globals) ----")
    output.extend(body_lines)
    output.append("")

    output.append("// ---- e2e_tick_handler_1hz — mirrors main.c 1Hz decimated block ----")
    output.append("static void e2e_tick_handler_1hz(void) {")
    if started_line:
        output.append(f"  // Mirrors: {started_line}")
    output.append("  bool started = e2e_ignition_line;")
    if heartbeat_line:
        output.append(f"  // Mirrors: {heartbeat_line}")
    output.append("  bool recent_heartbeat = heartbeat_counter == 0U;")
    if tick_call:
        output.append(f"  // Mirrors: {tick_call}")
    output.append("  bootkick_tick(started, recent_heartbeat);")
    output.append("  if (heartbeat_counter < UINT32_MAX) {")
    output.append("    heartbeat_counter += 1U;")
    output.append("  }")
    output.append("}")
    output.append("")

    output.append("// ---- JNA entry points ----")
    output.append("void jna_tick_handler(void) { e2e_tick_handler_1hz(); }")
    output.append("")
    output.append("int jna_get_bootkick_state(void)            { return (int)e2e_boot_state; }")
    output.append("int jna_get_bootkick_reset_triggered(void)   { return (int)bootkick_reset_triggered; }")
    output.append("int jna_get_bootkick_waiting_countdown(void) { return (int)e2e_waiting_countdown; }")
    output.append("int jna_get_bootkick_reset_countdown(void)   { return (int)e2e_boot_reset_countdown; }")
    output.append("")
    output.append("void jna_reset_bootkick(void) {")
    output.append("  e2e_boot_state = BOOT_BOOTKICK;")
    output.append("  e2e_bootkick_ign_prev = false;")
    output.append("  e2e_bootkick_harness_prev = HARNESS_STATUS_NC;")
    output.append("  e2e_bootkick_last_serial_ptr = 0;")
    output.append("  e2e_waiting_countdown = 0;")
    output.append("  e2e_boot_reset_countdown = 0;")
    output.append("  bootkick_reset_triggered = false;")
    output.append("  e2e_ignition_line = false;")
    output.append("#if defined(E2E_BOARD_TRES)")
    output.append("  e2e_GPIOB.IDR &= ~(1U << 1);")
    output.append("#elif !defined(E2E_BOARD_RED)")
    output.append("  e2e_GPIOC.IDR |= (1U << 3);")
    output.append("#endif")
    output.append("}")

    return "\n".join(output)


if __name__ == "__main__":
    print(generate())
