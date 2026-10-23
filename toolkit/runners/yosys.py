"""Generic Yosys synthesis backend."""

from __future__ import annotations

import json
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
    script = [
        " ".join(read_args),
        f"hierarchy -check -top {top}",
        f"synth -top {top}",
        "check",
        "stat",
        f"write_json {json.dumps(str(json_path))}",
        f"write_verilog -noattr {json.dumps(str(verilog_path))}",
    ]
    script_path.write_text("\n".join(script) + "\n", encoding="utf-8")

    result = execute([yosys, "-s", str(script_path)], project, build_dir / "synth.log")
    if result:
        return result
    missing = [path.name for path in (json_path, verilog_path) if not path.is_file()]
    if missing:
        print(
            "vlsi: synthesis returned success but did not create: " + ", ".join(missing),
            file=sys.stderr,
        )
        return 1
    print(f"SYNTHESIS_OUTPUTS {json_path} {verilog_path}")
    return 0
