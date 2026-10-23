#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
LIB="$ROOT/scripts/lib"
source "$LIB/common.sh"
source "$LIB/platform.sh"
source "$LIB/detect_tools.sh"
source "$LIB/check_uvm.sh"
source "$LIB/verilator_setup.sh"
source "$LIB/diagnostics.sh"

ts_check_platform || exit 1
status=0
ts_check_tools || status=1
if ! ts_check_uvm; then
    ts_diagnose uvm
    status=1
fi
if ((status == 0)); then
    ts_info "Diagnostics passed. Run scripts/tool_setup_and_check.sh --smoke-only to compile and exercise all tools."
else
    ts_info "Diagnostics found an issue. Apply the resolution above and rerun scripts/diagnose.sh."
fi
exit "$status"
