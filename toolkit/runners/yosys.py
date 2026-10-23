"""Generic Yosys synthesis backend."""

from __future__ import annotations

import json
import re
import shutil
import sys
from pathlib import Path

from .common import execute


def run_yosys(
    *,
    project: Path,
    top: str,
    sources: list[Path],
    include_dirs: list[Path],
    defines: list[str],
    build_dir: Path,
    liberty: Path | None = None,
    abc_constraints: Path | None = None,
    delay_ps: int | None = None,
) -> int:
    yosys = shutil.which("yosys")
    if yosys is None:
        print("vlsi: required tool not found: yosys (run './vlsi doctor')", file=sys.stderr)
        return 127

    build_dir.mkdir(parents=True, exist_ok=True)
    script_path = build_dir / "synth.ys"
    json_path = build_dir / "netlist.json"
    verilog_path = build_dir / "netlist.v"

    # Source/output paths are quoted for Yosys. Its read_verilog frontend
    # expects include paths attached directly to -I, without embedded quotes.
    read_args = ["read_verilog", "-sv"]
    read_args.extend(f"-I{path}" for path in include_dirs)
    read_args.extend(f"-D{define}" for define in defines)
    read_args.extend(json.dumps(str(source)) for source in sources)
    script = [" ".join(read_args)]
    liberty_arg = None
    if liberty is not None:
        liberty_arg = json.dumps(str(liberty))
        script.append(f"read_liberty -lib {liberty_arg}")
    script.append(f"hierarchy -check -top {top}")
    if liberty is None:
        script.extend([f"synth -top {top}", "check", "stat"])
    else:
        script.extend([
            f"synth -top {top} -noabc",
            f"dfflibmap -liberty {liberty_arg}",
        ])
        abc_command = f"abc -liberty {liberty_arg}"
        if abc_constraints is not None:
            abc_command += f" -constr {json.dumps(str(abc_constraints))}"
        if delay_ps is not None:
            abc_command += f" -D {delay_ps}"
        script.extend([
            abc_command,
            "clean",
            "check",
            f"stat -liberty {liberty_arg}",
        ])
    script.extend([
        f"write_json {json.dumps(str(json_path))}",
        f"write_verilog -noattr {json.dumps(str(verilog_path))}",
    ])
    script_path.write_text("\n".join(script) + "\n", encoding="utf-8")

    result = execute([yosys, "-s", str(script_path)], project, build_dir / "synth.log")
    if result:
        return result

    abc_report_path = build_dir / "abc_timing_report.txt"
    synth_log = (build_dir / "synth.log").read_text(encoding="utf-8", errors="replace")
    delay_lines = [
        line for line in synth_log.splitlines()
        if re.search(r"^ABC: .*\bDelay\s*=\s*[0-9]+(?:\.[0-9]+)?\s*ps\b", line)
    ]
    path_lines = [
        line for line in synth_log.splitlines()
        if line.startswith("ABC: Path ") or line.startswith("ABC: Start-point = ")
    ]
    abc_report = [
        "ABC synthesis-time delay estimate",
        "This is an ABC mapping estimate, not an OpenSTA static timing report.",
        f"Liberty: {liberty if liberty is not None else 'not selected'}",
        f"ABC constraints: {abc_constraints if abc_constraints is not None else 'not selected'}",
        f"ABC delay target: {delay_ps} ps" if delay_ps is not None else "ABC delay target: not selected",
        "",
    ]
    if delay_lines:
        for line in delay_lines:
            match = re.search(r"\bDelay\s*=\s*([0-9]+(?:\.[0-9]+)?)\s*ps\b", line)
            if match:
                abc_report.append(f"ABC_DELAY_ESTIMATE_PS={match.group(1)}")
            abc_report.append(line)
        abc_report.extend(path_lines)
    elif liberty is None:
        abc_report.append(
            "No technology-specific delay estimate was emitted because no Liberty "
            "library was selected. Select both liberty and abc_constraints to request one."
        )
    elif abc_constraints is None:
        abc_report.append(
            "No ABC delay estimate was emitted. Set abc_constraints to provide "
            "the input driver and output load required by ABC's stime report."
        )
    else:
        abc_report.append(
            "No ABC delay estimate was emitted for this design. Inspect synth.log; "
            "the mapped logic may not contain a reportable combinational path."
        )
    abc_report_path.write_text("\n".join(abc_report) + "\n", encoding="utf-8")

    missing = [path.name for path in (json_path, verilog_path) if not path.is_file()]
    if missing:
        print(
            "vlsi: synthesis returned success but did not create: " + ", ".join(missing),
            file=sys.stderr,
        )
        return 1
    print(f"SYNTHESIS_OUTPUTS {json_path} {verilog_path}")
    print(f"ABC_TIMING_REPORT {abc_report_path}")
    return 0
