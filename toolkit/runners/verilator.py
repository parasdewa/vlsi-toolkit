"""Verilator compile and simulation backend."""

from __future__ import annotations

import re
import shutil
import sys
from pathlib import Path

from .common import execute


def run_verilator(
    *,
    project: Path,
    top: str,
    sources: list[Path],
    include_dirs: list[Path],
    defines: list[str],
    sim_args: list[str],
    build_dir: Path,
    jobs: int,
    waveform_path: Path | None,
    uvm_dir: Path | None = None,
) -> int:
    compiler = shutil.which("verilator")
    if compiler is None:
        print("vlsi: required tool not found: verilator (run './vlsi doctor')", file=sys.stderr)
        return 127

    build_dir.mkdir(parents=True, exist_ok=True)
    if uvm_dir is not None:
        (build_dir / "build").mkdir(parents=True, exist_ok=True)
    if waveform_path is not None:
        waveform_path.parent.mkdir(parents=True, exist_ok=True)
    object_dir = build_dir / "obj_dir"
    executable = object_dir / f"V{top}"
    compile_command = [
        compiler,
        "--binary",
        "--timing",
        "-Wall",
        "-Wno-fatal",
        "-j",
        str(jobs),
        "--top-module",
        top,
        "--Mdir",
        str(object_dir),
    ]
    if waveform_path is not None or uvm_dir is not None:
        compile_command.append("--trace")
    if uvm_dir is not None:
        compile_command.append(f"+incdir+{uvm_dir}")
        compile_command.append(str(uvm_dir / "uvm_pkg_all_v2020_3_2_nodpi.svh"))
    if waveform_path is not None:
        compile_command.append("-DVLSI_WAVEFORM")
    compile_command.extend(f"-I{include_dir}" for include_dir in include_dirs)
    compile_command.extend(f"-D{define}" for define in defines)
    compile_command.extend(str(source) for source in sources)

    compile_log = build_dir / "compile.log"
    result = execute(compile_command, project, compile_log)
    if result:
        return result
    if not executable.is_file():
        print(
            f"vlsi: compiler returned success but did not create {executable}",
            file=sys.stderr,
        )
        return 1

    run_log = build_dir / "run.log"
    runtime_args = [str(executable), *sim_args]
    if waveform_path is not None:
        runtime_args.append(f"+VLSI_WAVEFORM={waveform_path}")
    result = execute(runtime_args, build_dir if uvm_dir is not None else project, run_log)
    if result == 0 and uvm_dir is not None:
        run_output = run_log.read_text(encoding="utf-8", errors="replace")
        if re.search(r"(?mi)^\s*UVM_(?:ERROR|FATAL)\s*:\s*[1-9][0-9]*\s*$", run_output):
            print(f"vlsi: UVM reported errors or fatals; see {run_log}", file=sys.stderr)
            return 1
    if result == 0 and waveform_path is not None and not waveform_path.is_file():
        print(f"vlsi: waveform was requested but not created: {waveform_path}", file=sys.stderr)
        return 1
    return result
