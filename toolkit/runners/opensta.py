"""OpenSTA gate-level static timing analysis backend."""

from __future__ import annotations

import re
import shutil
import sys
from pathlib import Path

from .common import execute


def _tcl_quote(value: str) -> str:
    """Quote a path as a Tcl word without allowing substitutions."""
    escaped = value.replace("\\", "\\\\").replace('"', '\\"')
    escaped = escaped.replace("$", "\\$").replace("[", "\\[").replace("]", "\\]")
    escaped = escaped.replace("\n", "\\n").replace("\r", "\\r")
    return f'"{escaped}"'


def run_opensta(
    *,
    project: Path,
    top: str,
    netlist: Path,
    liberty: Path,
    sdc: Path,
    spef: Path | None,
    build_dir: Path,
) -> int:
    sta = shutil.which("sta")
    if sta is None:
        print(
            "vlsi: required timing tool not found: sta (OpenSTA); see docs/TIMING_ANALYSIS.md",
            file=sys.stderr,
        )
        return 127

    build_dir.mkdir(parents=True, exist_ok=True)
    script_path = build_dir / "timing.tcl"
    report_path = build_dir / "timing_report.txt"
    setup_path = build_dir / "setup_check.txt"

    script = [
        f"read_liberty {_tcl_quote(str(liberty))}",
        f"read_verilog {_tcl_quote(str(netlist))}",
        f"link_design {_tcl_quote(top)}",
        f"read_sdc {_tcl_quote(str(sdc))}",
    ]
    if spef is not None:
        script.append(f"read_spef {_tcl_quote(str(spef))}")
    script.extend([
        "report_units",
        f"check_setup -verbose > {_tcl_quote(str(setup_path))}",
        "report_checks -path_delay max -group_path_count 10 "
        f"-format full_clock_expanded -digits 3 >> {_tcl_quote(str(report_path))}",
        "report_checks -path_delay min -group_path_count 10 "
        f"-format full_clock_expanded -digits 3 >> {_tcl_quote(str(report_path))}",
        f"report_worst_slack -max -digits 3 >> {_tcl_quote(str(report_path))}",
        f"report_worst_slack -min -digits 3 >> {_tcl_quote(str(report_path))}",
        f"report_tns -max -digits 3 >> {_tcl_quote(str(report_path))}",
        f"report_tns -min -digits 3 >> {_tcl_quote(str(report_path))}",
    ])
    script_path.write_text("\n".join(script) + "\n", encoding="utf-8")

    result = execute(
        [sta, "-no_init", "-no_splash", "-threads", "1", "-exit", str(script_path)],
        project,
        build_dir / "timing.log",
    )
    if result:
        return result
    if not report_path.is_file() or report_path.stat().st_size == 0:
        print(
            "vlsi: OpenSTA completed without writing a timing report; inspect "
            f"{build_dir / 'timing.log'}",
            file=sys.stderr,
        )
        return 1
    print(f"TIMING_REPORT {report_path}")
    print(f"TIMING_SETUP_CHECK {setup_path}")
    report = report_path.read_text(encoding="utf-8")
    slack_values = re.findall(
        r"^worst slack (?:max|min) (-?(?:\d+(?:\.\d*)?|\.\d+))\s*$",
        report,
        re.MULTILINE,
    )
    if len(slack_values) < 2:
        print(
            "vlsi: could not determine max/min slack from the OpenSTA report; "
            f"inspect {report_path}",
            file=sys.stderr,
        )
        print("TIMING_STATUS UNKNOWN")
        return 1

    worst_slack = min(float(value) for value in slack_values)
    if worst_slack < 0:
        print(f"TIMING_STATUS FAIL (negative slack: {worst_slack:g})")
        print("vlsi: timing constraints are violated; inspect the report above", file=sys.stderr)
        return 1
    print(f"TIMING_STATUS PASS (worst slack: {worst_slack:g})")
    return 0
