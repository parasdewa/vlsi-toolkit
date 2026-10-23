"""Validate a user-selected Liberty library with OpenSTA."""

from __future__ import annotations

import shutil
import sys
from pathlib import Path

from .common import execute


def _tcl_quote(value: str) -> str:
    escaped = value.replace("\\", "\\\\").replace('"', '\\"')
    escaped = escaped.replace("$", "\\$").replace("[", "\\[").replace("]", "\\]")
    escaped = escaped.replace("\n", "\\n").replace("\r", "\\r")
    return f'"{escaped}"'


def check_liberty(*, liberty: Path, build_dir: Path) -> int:
    sta = shutil.which("sta")
    if sta is None:
        print(
            "vlsi: required tool not found: sta (OpenSTA); run scripts/tool_setup_and_check.sh",
            file=sys.stderr,
        )
        return 127
    if not liberty.is_file():
        print(f"vlsi: Liberty file does not exist or is not a file: {liberty}", file=sys.stderr)
        return 2

    build_dir.mkdir(parents=True, exist_ok=True)
    script_path = build_dir / "liberty_check.tcl"
    log_path = build_dir / "liberty_check.log"
    script_path.write_text(
        "\n".join([
            f"read_liberty {_tcl_quote(str(liberty.resolve()))}",
            "set libraries [get_libs *]",
            "set library_count [llength $libraries]",
            "set cell_count [llength [get_lib_cells */*]]",
            "if {$library_count == 0} { error {No Liberty libraries were parsed} }",
            "if {$cell_count == 0} { error {The Liberty file contains no library cells} }",
            "puts \"LIBERTY_CHECK_PASS\"",
            "puts \"LIBERTY_LIBRARY_NAMES [get_name $libraries]\"",
            "puts \"LIBERTY_LIBRARY_COUNT $library_count\"",
            "puts \"LIBERTY_CELL_COUNT $cell_count\"",
            "report_units",
            "",
        ]),
        encoding="utf-8",
    )

    result = execute(
        [sta, "-no_init", "-no_splash", "-threads", "1", "-exit", str(script_path)],
        Path.cwd(),
        log_path,
    )
    if result:
        return result
    if "LIBERTY_CHECK_PASS" not in log_path.read_text(encoding="utf-8", errors="replace"):
        print(
            f"vlsi: OpenSTA did not confirm Liberty parsing; inspect {log_path}",
            file=sys.stderr,
        )
        return 1

    print(f"LIBERTY_FILE {liberty.resolve()}")
    print(f"LIBERTY_CHECK_LOG {log_path}")
    return 0
