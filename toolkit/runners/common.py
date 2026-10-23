"""Shared subprocess handling for simulator backends."""

from __future__ import annotations

import shlex
import subprocess
import sys
from pathlib import Path


def execute(command: list[str], cwd: Path, log_path: Path) -> int:
    display_command = shlex.join(command)
    print("$ " + display_command)
    try:
        result = subprocess.run(
            command,
            cwd=cwd,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            check=False,
        )
    except OSError as exc:
        print(f"vlsi: could not start {command[0]}: {exc}", file=sys.stderr)
        return 127

    output = result.stdout or ""
    log_path.write_text("$ " + display_command + "\n" + output, encoding="utf-8")
    if output:
        print(output, end="" if output.endswith("\n") else "\n")
    if result.returncode:
        print(
            f"vlsi: command failed with exit code {result.returncode}; log: {log_path}",
            file=sys.stderr,
        )
    return result.returncode
