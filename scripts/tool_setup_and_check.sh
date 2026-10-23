#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
LIB="$ROOT/scripts/lib"
source "$LIB/common.sh"
source "$LIB/platform.sh"
source "$LIB/detect_tools.sh"
source "$LIB/install_packages.sh"
source "$LIB/check_uvm.sh"
source "$LIB/diagnostics.sh"
source "$LIB/smoke_tests.sh"
source "$LIB/verilator_setup.sh"

MODE=install
case "${1:-}" in
    "") ;;
    --check-only) MODE=check ;;
    --smoke-only) MODE=smoke ;;
    --help|-h)
        cat <<'USAGE'
Usage: scripts/tool_setup_and_check.sh [--check-only|--smoke-only]

Default: detect missing Ubuntu packages, install only those packages, verify
the tools and Verilator UVM source, then run the RTL/UVM smoke suite.
--check-only: report tool and UVM availability without installing or compiling.
--smoke-only: skip installation and run the compile/simulation smoke suite.

Set VERILATOR_UVM_DIR to the Verilator test_regress/t/uvm directory when the
UVM package is not located beneath VERILATOR_ROOT.
USAGE
        exit 0
        ;;
    *) ts_error "Unknown option: $1"; exit 2 ;;
esac

ts_check_platform
INSTALL_LOG="$ROOT/build/tool_setup/logs/tool_setup_install.log"

if [[ "$MODE" == install ]]; then
    mkdir -p "$ROOT/build/tool_setup/logs"
    ts_missing_packages
    if ((${#MISSING_PACKAGES[@]})); then
        ts_install_missing_packages "${MISSING_PACKAGES[@]}" || {
            ts_diagnose install
            exit 1
        }
    else
        ts_info "All required Ubuntu packages are already present; apt was not run."
    fi
    ts_prepare_verilator_uvm || { ts_diagnose uvm; exit 1; }
fi

if [[ "$MODE" == check ]]; then
    ts_check_tools || { ts_diagnose tools; exit 1; }
    ts_check_uvm || { ts_diagnose uvm; exit 1; }
    ts_info "Tool check passed. No packages were installed and no compilation was run."
    exit 0
fi

ts_check_tools || { ts_diagnose tools; exit 1; }
ts_check_uvm || { ts_diagnose uvm; exit 1; }
ts_info "Starting compile and simulation smoke tests. Verilator build parallelism is limited to one job."
if ! ts_run_smoke_tests "$ROOT" "$RESOLVED_UVM_DIR"; then
    exit 1
fi
ts_info "Tool setup and smoke tests passed. Detailed compile logs are under $ROOT/build/tool_setup/."
