#!/usr/bin/env python3
"""Batch-update test design docs with coverage sections.

Reads each design doc, appends a coverage section with relevant source
file coverage data from the merged LCOV report.
"""

import re
import sys
from pathlib import Path
from collections import OrderedDict

sys.path.insert(0, str(Path(__file__).parent))
from merge_lcov import parse_lcov

# ── Coverage data from merged.lcov ──
LCOV_PATH = Path(__file__).parent.parent / "build" / "coverage" / "merged.lcov"
PROJECT_ROOT = Path(__file__).parent.parent.parent
DESIGN_DIR = Path(__file__).parent.parent / "src" / "test" / "resources" / "test-design"

# Short names for source files
FILE_SHORT = {
    "board/main_comms.h": ("main_comms.h", "USB 命令处理"),
    "board/main.c": ("main.c", "主循环 + 初始化"),
    "board/drivers/can_common.h": ("can_common.h", "CAN 通用操作"),
    "board/drivers/gpio.h": ("gpio.h", "GPIO 控制"),
    "board/drivers/fan.h": ("fan.h", "风扇 PWM + 冷却"),
    "board/drivers/clock_source.h": ("clock_source.h", "时钟源选择"),
    "board/can_comms.h": ("can_comms.h", "CAN 通信处理"),
    "board/sys/faults.h": ("faults.h", "故障设置"),
    "board/libc.h": ("libc.h", "最小化 libc 替代"),
    "board/boards/board_declarations.h": ("board_declarations.h", "板级声明"),
    "board/config.h": ("config.h", "构建配置"),
    "board/drivers/drivers.h": ("drivers.h", "驱动初始化"),
    "board/sys/sys.h": ("sys.h", "系统初始化"),
    "board/utils.h": ("utils.h", "工具函数"),
}

# ── Feature → related source files mapping ──
# Each feature primarily exercises main_comms.h for its USB handler,
# plus optional driver files for hardware-specific operations.
FEATURE_FILES = {
    # Core: USB command in main_comms.h
    "alternative-experience":   ["board/main_comms.h"],
    "bootloader":               ["board/main_comms.h"],
    "get-version":              ["board/main_comms.h"],
    "hw-type":                  ["board/main_comms.h"],
    "interrupt-rate":           ["board/main_comms.h"],
    "mcu-uid":                  ["board/main_comms.h"],
    "microsecond-timer":        ["board/main_comms.h"],
    "packet-versions":          ["board/main_comms.h"],
    "reset-st":                 ["board/main_comms.h"],
    "serial":                   ["board/main_comms.h"],
    "som-gpio":                 ["board/main_comms.h"],
    "uart-read":                ["board/main_comms.h"],
    # USB + CAN driver
    "can-bitrate":              ["board/main_comms.h", "board/drivers/can_common.h"],
    "can-comms-reset":          ["board/main_comms.h", "board/drivers/can_common.h"],
    "can-fd-auto":              ["board/main_comms.h", "board/drivers/can_common.h"],
    "can-fd-data-bitrate":      ["board/main_comms.h", "board/drivers/can_common.h"],
    "can-fd-non-iso":           ["board/main_comms.h", "board/drivers/can_common.h"],
    "can-health":               ["board/main_comms.h", "board/drivers/can_common.h"],
    "can-loopback":             ["board/main_comms.h", "board/drivers/can_common.h"],
    "can-ring-clear":           ["board/main_comms.h", "board/drivers/can_common.h"],
    # USB + GPIO
    "relay":                    ["board/main_comms.h", "board/drivers/gpio.h"],
    # USB + main loop
    "alternative-experience":   ["board/main_comms.h"],
    # USB + main loop + hardware
    "health-packet":            ["board/main_comms.h", "board/main.c"],
    "heartbeat":                ["board/main_comms.h", "board/main.c"],
    "signature":                ["board/main_comms.h"],
    "siren":                    ["board/main_comms.h", "board/drivers/gpio.h", "board/main.c"],
    # Multi-driver features
    "safety-mode":              ["board/main_comms.h", "board/main.c", "board/drivers/can_common.h"],
    "deep-sleep":               ["board/main_comms.h", "board/main.c", "board/drivers/gpio.h", "board/sys/sys.h"],
    "power-save":               ["board/main_comms.h", "board/main.c", "board/drivers/gpio.h"],
    "can-mode":                 ["board/main_comms.h", "board/drivers/gpio.h", "board/boards/board_declarations.h"],
    # Clock / Fan / IR
    "clock-source":             ["board/main_comms.h", "board/drivers/clock_source.h"],
    "fan-power":                ["board/main_comms.h", "board/drivers/fan.h"],
    "timer-fan":                ["board/main_comms.h", "board/drivers/fan.h"],
    "ir-power":                 ["board/main_comms.h", "board/drivers/fan.h"],
    # Main loop tick behaviors
    "bootkick":                 ["board/main.c", "board/drivers/gpio.h"],
    "relay-malfunction":        ["board/main.c"],
}

# Legacy names (snake_case in design dir)
FEATURE_ALIASES = {
    "can_loopback": "can-loopback",
    "can_mode": "can-mode",
}


def read_lcov() -> dict:
    """Parse merged.lcov, return {short_path: {line_coverage_pct, func_coverage}}."""
    raw = parse_lcov(str(LCOV_PATH))
    result = {}
    for full_path, lines in raw.items():
        # Find matching short key
        for key, (short, desc) in FILE_SHORT.items():
            if full_path.endswith(key):
                lf = len(lines)
                lh = sum(1 for c in lines.values() if c > 0)
                pct = (lh / lf * 100) if lf > 0 else 0
                result[key] = f"{pct:.1f}% ({lh}/{lf})"
                break
    return result


def get_feature_key(doc_name: str) -> str:
    """Map a design doc filename stem to a feature key."""
    stem = doc_name.replace(".md", "")
    if stem in FEATURE_ALIASES:
        stem = FEATURE_ALIASES[stem]
    return stem


def generate_coverage_section(feature_key: str, lcov_data: dict) -> str:
    """Generate a coverage section for a feature."""
    files = FEATURE_FILES.get(feature_key, ["board/main_comms.h"])
    lines = []
    lines.append("## 覆盖率")
    lines.append("")
    lines.append(f"> 数据来源: `run_all_coverage.sh` 合并报告 (cuatro + tres + red)")
    lines.append(f"> 综合行覆盖率: **65.1%** (全量), 本功能涉及以下源文件:")
    lines.append("")
    lines.append("| 源文件 | 行覆盖 | 说明 |")
    lines.append("|--------|--------|------|")

    for f in files:
        short, desc = FILE_SHORT.get(f, (f, ""))
        cov = lcov_data.get(f, "—")
        lines.append(f"| `{short}` | {cov} | {desc} |")

    lines.append("")
    return "\n".join(lines)


def update_doc(doc_path: Path, feature_key: str, lcov_data: dict) -> bool:
    """Append coverage section to a design doc. Returns True if updated."""
    content = doc_path.read_text()

    # Check if already has a coverage section
    if re.search(r'^##\s+覆盖率', content, re.MULTILINE):
        # Replace existing coverage section
        content = re.sub(
            r'^##\s+覆盖率.*$(?:\n.*$)*',
            '',
            content,
            flags=re.MULTILINE
        ).rstrip() + "\n\n"

    section = generate_coverage_section(feature_key, lcov_data)
    new_content = content.rstrip() + "\n\n" + section + "\n"
    doc_path.write_text(new_content)
    return True


def main():
    lcov_data = read_lcov()
    print(f"Loaded coverage data for {len(lcov_data)} source files")

    updated = 0
    skipped = 0

    for doc_path in sorted(DESIGN_DIR.glob("*.md")):
        if doc_path.name == "uncovered-features.md":
            continue

        feature_key = get_feature_key(doc_path.name)
        if feature_key not in FEATURE_FILES and feature_key not in FEATURE_ALIASES:
            print(f"  SKIP {doc_path.name}: no feature mapping")
            skipped += 1
            continue

        if update_doc(doc_path, feature_key, lcov_data):
            print(f"  OK   {doc_path.name} → {feature_key}")
            updated += 1

    print(f"\nUpdated: {updated}, Skipped: {skipped}")


if __name__ == "__main__":
    main()
