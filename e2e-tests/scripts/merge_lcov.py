#!/usr/bin/env python3
"""Merge multiple LCOV trace files into a single combined report.

For overlapping source files, takes the max execution count per line.
Recalculates LF (lines found) and LH (lines hit) for each merged file.

Usage:
  merge_lcov.py merge <output.lcov> <input1.lcov> [input2.lcov ...]
  merge_lcov.py html <input.lcov> <output_dir>
"""

import sys
import re
import html as html_mod
from collections import defaultdict
from pathlib import Path


def parse_lcov(path: str) -> dict:
    """Parse an LCOV file into {source_file: {line_no: exec_count}}."""
    records = {}
    current_sf = None
    current_data = {}
    with open(path) as f:
        for line in f:
            line = line.strip()
            if line.startswith("SF:"):
                current_sf = line[3:]
                current_data = {}
            elif line.startswith("DA:"):
                parts = line[3:].split(",")
                lineno = int(parts[0])
                count = int(parts[1])
                current_data[lineno] = count
            elif line == "end_of_record":
                if current_sf:
                    records[current_sf] = current_data
                current_sf = None
                current_data = {}
    return records


def merge_records(all_records: list[dict]) -> dict:
    """Merge multiple record dicts, taking max exec count per line."""
    merged = defaultdict(lambda: defaultdict(int))
    for records in all_records:
        for sf, lines in records.items():
            for lineno, count in lines.items():
                if count > merged[sf][lineno]:
                    merged[sf][lineno] = count
    return dict(merged)


def write_lcov(records: dict, output_path: str) -> None:
    """Write merged records to LCOV file."""
    with open(output_path, "w") as f:
        f.write("TN:merged\n")
        for sf in sorted(records.keys()):
            lines = records[sf]
            f.write(f"SF:{sf}\n")
            for lineno in sorted(lines.keys()):
                f.write(f"DA:{lineno},{lines[lineno]}\n")
            lf = len(lines)
            lh = sum(1 for c in lines.values() if c > 0)
            f.write(f"LF:{lf}\n")
            f.write(f"LH:{lh}\n")
            f.write("end_of_record\n")


def generate_html(records: dict, output_dir: str, project_root: str = "") -> None:
    """Generate a single-page HTML coverage report.

    Outputs index.html plus per-file HTML in the output directory.
    """
    out = Path(output_dir)
    out.mkdir(parents=True, exist_ok=True)

    # Per-file coverage pages
    file_pages = []
    for sf in sorted(records.keys()):
        lines_data = records[sf]
        lf = len(lines_data)
        lh = sum(1 for c in lines_data.values() if c > 0)
        pct = (lh / lf * 100) if lf > 0 else 0

        safe_name = sf.replace("/", "_").replace(".", "_")
        file_html = out / f"{safe_name}.html"

        # Read source file to show annotated lines
        source_lines = {}
        sf_path = Path(project_root) / sf if project_root else Path(sf)
        if sf_path.exists():
            with open(sf_path) as src:
                for i, line in enumerate(src, 1):
                    source_lines[i] = line.rstrip()

        # Build annotated HTML
        rows = []
        max_line = max(max(lines_data.keys(), default=0),
                       max(source_lines.keys(), default=0))
        for lineno in range(1, max_line + 1):
            count = lines_data.get(lineno, -1)
            if count >= 0:
                css_class = "hit" if count > 0 else "miss"
                count_str = str(count)
            else:
                css_class = "nocode"
                count_str = ""
            src = html_mod.escape(source_lines.get(lineno, ""))
            rows.append(
                f'<tr class="{css_class}">'
                f'<td class="lineno">{lineno}</td>'
                f'<td class="count">{count_str}</td>'
                f'<td class="code"><pre>{src}</pre></td>'
                f"</tr>"
            )

        title = sf
        html_content = f"""<!DOCTYPE html>
<html><head><meta charset="utf-8"><title>{title}</title>
<link rel="stylesheet" href="coverage.css"></head>
<body><h1>{title}</h1>
<div class="file-summary"><strong>{pct:.1f}%</strong> — {lh}/{lf} lines covered</div>
<table class="coverage">
<tr><th>Line</th><th>Count</th><th>Source</th></tr>
{''.join(rows)}
</table>
<p><a href="index.html">← Back to index</a></p>
</body></html>"""

        file_html.write_text(html_content)
        file_pages.append((sf, pct, lf, lh, safe_name))

    # Build index page
    total_lf = sum(f[2] for f in file_pages)
    total_lh = sum(f[3] for f in file_pages)
    total_pct = (total_lh / total_lf * 100) if total_lf > 0 else 0

    rows = []
    for sf, pct, lf, lh, safe_name in file_pages:
        bar_color = "#4c1" if pct >= 80 else ("#ca0" if pct >= 50 else "#e44")
        rows.append(
            f'<tr><td class="file-name"><a href="{safe_name}.html">{sf}</a></td>'
            f'<td class="pct">{pct:.1f}%</td>'
            f'<td>{lh}/{lf}</td>'
            f'<td><div class="bar"><div class="bar-fill" style="width:{pct:.1f}%;background:{bar_color}"></div></div></td>'
            f"</tr>"
        )

    index_html = f"""<!DOCTYPE html>
<html><head><meta charset="utf-8"><title>Coverage Report</title>
<link rel="stylesheet" href="coverage.css"></head>
<body>
<h1>Panda Firmware E2E Coverage (All Boards)</h1>
<div class="summary"><strong>{total_pct:.1f}%</strong> — {total_lh}/{total_lf} lines covered across {len(file_pages)} files</div>
<table class="index">
<tr><th>File</th><th>Coverage</th><th>Lines</th><th>Bar</th></tr>
{''.join(rows)}
</table>
</body></html>"""

    (out / "index.html").write_text(index_html)

    # CSS
    css = """body{font-family:-apple-system,BlinkMacSystemFont,sans-serif;margin:20px;color:#333}
h1{font-size:1.4em;border-bottom:2px solid #4c1;padding-bottom:8px}
.summary,.file-summary{font-size:1.2em;margin:16px 0}
table{border-collapse:collapse;width:100%}
th{text-align:left;background:#f5f5f5;padding:6px 10px}
td{padding:4px 10px;border-bottom:1px solid #eee}
.file-name{font-family:monospace;font-size:0.9em}
.pct{font-weight:bold;text-align:right}
.bar{width:120px;height:16px;background:#eee;border-radius:3px;overflow:hidden}
.bar-fill{height:100%;border-radius:3px}
/* source line styles */
tr.hit{background:#e8f5e9}tr.miss{background:#ffebee}tr.nocode{background:#fafafa}
td.lineno{color:#999;text-align:right;min-width:40px;user-select:none}
td.count{text-align:right;min-width:50px;font-weight:bold;color:#666}
td.code pre{margin:0;white-space:pre-wrap;font-family:monospace;font-size:0.85em}
a{color:#4c1;text-decoration:none}a:hover{text-decoration:underline}
"""
    (out / "coverage.css").write_text(css)


def cmd_merge(args):
    if len(args) < 2:
        print("Usage: merge_lcov.py merge <output.lcov> <input1.lcov> [input2.lcov ...]")
        sys.exit(1)
    output = args[0]
    inputs = args[1:]
    all_records = []
    for path in inputs:
        if not Path(path).exists():
            print(f"Warning: {path} not found, skipping", file=sys.stderr)
            continue
        all_records.append(parse_lcov(path))
    if not all_records:
        print("Error: no valid input files", file=sys.stderr)
        sys.exit(1)
    merged = merge_records(all_records)
    write_lcov(merged, output)
    total_lf = sum(len(v) for v in merged.values())
    total_lh = sum(sum(1 for c in v.values() if c > 0) for v in merged.values())
    pct = (total_lh / total_lf * 100) if total_lf > 0 else 0
    print(f"Merged {len(inputs)} files → {output} ({len(merged)} source files, {pct:.1f}%)")


def cmd_html(args):
    if len(args) < 2:
        print("Usage: merge_lcov.py html <input.lcov> <output_dir> [project_root]")
        sys.exit(1)
    lcov_file = args[0]
    output_dir = args[1]
    project_root = args[2] if len(args) > 2 else ""
    records = parse_lcov(lcov_file)
    generate_html(records, output_dir, project_root)
    print(f"HTML report generated in {output_dir}/index.html")


def main():
    if len(sys.argv) < 2:
        print("Usage: merge_lcov.py <merge|html> ...")
        sys.exit(1)
    cmd = sys.argv[1]
    if cmd == "merge":
        cmd_merge(sys.argv[2:])
    elif cmd == "html":
        cmd_html(sys.argv[2:])
    else:
        print(f"Unknown command: {cmd}")
        sys.exit(1)


if __name__ == "__main__":
    main()
