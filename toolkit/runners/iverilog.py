"""Icarus Verilog compile and simulation backend."""

from __future__ import annotations

import shutil
import sys
from pathlib import Path

from .common import execute


def run_iverilog(
    *,
    project: Path,
    top: str,
    sources: list[Path],
    include_dirs: list[Path],
    defines: list[str],
    sim_args: list[str],
    build_dir: Path,
    waveform_path: Path | None,
) -> int:
    compiler = shutil.which("iverilog")
    runtime = shutil.which("vvp")
    if compiler is None or runtime is None:
        missing = " and ".join(name for name, path in (("iverilog", compiler), ("vvp", runtime)) if path is None)
        print(f"vlsi: required tool not found: {missing} (run './vlsi doctor')", file=sys.stderr)
        return 127

    build_dir.mkdir(parents=True, exist_ok=True)
    if waveform_path is not None:
        waveform_path.parent.mkdir(parents=True, exist_ok=True)
    executable = build_dir / f"{top}.vvp"
    compile_command = [compiler, "-g2012", "-s", top, "-o", str(executable)]
    if waveform_path is not None:
        compile_command.append("-DVLSI_WAVEFORM")
    for include_dir in include_dirs:
        compile_command.extend(("-I", str(include_dir)))
    compile_command.extend(f"-D{define}" for define in defines)
    compile_command.extend(str(source) for source in sources)

    compile_log = build_dir / "compile.log"
    result = execute(compile_command, project, compile_log)
    if result:
        return result
    if not executable.is_file():
        print(f"vlsi: compiler returned success but did not create {executable}", file=sys.stderr)
        return 1

    run_log = build_dir / "run.log"
    runtime_args = [runtime, str(executable), *sim_args]
    if waveform_path is not None:
        runtime_args.append(f"+VLSI_WAVEFORM={waveform_path}")
    result = execute(runtime_args, project, run_log)
    if result == 0 and waveform_path is not None and not waveform_path.is_file():
        print(f"vlsi: waveform was requested but not created: {waveform_path}", file=sys.stderr)
        return 1
    return result
