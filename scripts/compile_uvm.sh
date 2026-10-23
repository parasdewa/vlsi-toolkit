#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_ROOT="${VLSI_UVM_BUILD_ROOT:-$ROOT/build/tool_setup/uvm}"
TB_ROOT="$ROOT/tests/uvm/and_gate/tb"
RTL="$ROOT/tests/uvm/and_gate/rtl/and_gate.sv"
mkdir -p "$BUILD_ROOT/logs" "$BUILD_ROOT/run/build"

if [[ -n "${VERILATOR_UVM_DIR:-}" ]]; then
    UVM_DIR="$VERILATOR_UVM_DIR"
else
    VERILATOR_BIN="$(command -v verilator || true)"
    VERILATOR_ROOT="${VERILATOR_ROOT:-}"
    if [[ -z "$VERILATOR_ROOT" && -n "$VERILATOR_BIN" ]]; then
        VERILATOR_ROOT="$(cd -- "$(dirname -- "$(readlink -f "$VERILATOR_BIN")")/.." && pwd)"
    fi
    UVM_DIR="${VERILATOR_ROOT:+$VERILATOR_ROOT/test_regress/t/uvm}"
fi
UVM_PACKAGE="$UVM_DIR/uvm_pkg_all_v2020_3_2_nodpi.svh"
if [[ ! -f "$UVM_PACKAGE" ]]; then
    echo "ERROR: Verilator UVM 2020.3.2 source not found." >&2
    echo "Set VERILATOR_UVM_DIR to the directory containing uvm_pkg_all_v2020_3_2_nodpi.svh." >&2
    echo "Current selection: ${UVM_DIR:-<unset>}" >&2
    exit 2
fi

VERILATOR_VERSION="$(verilator --version)"
echo "Using $VERILATOR_VERSION"
echo "Using UVM source: $UVM_PACKAGE"
LOG="$BUILD_ROOT/logs/and_gate_uvm.log"
verilator --binary --timing --trace -Wall -Wno-fatal \
    --Mdir "$BUILD_ROOT/obj_dir" --top-module and_gate_tb_top \
    "+incdir+$UVM_DIR" "+incdir+$TB_ROOT" \
    "$UVM_PACKAGE" "$RTL" \
    "$TB_ROOT/and_gate_if.sv" "$TB_ROOT/and_gate_pkg.sv" \
    "$TB_ROOT/and_gate_tb_top.sv" --build-jobs 1 2>&1 | tee "$LOG"

RUN_LOG="$BUILD_ROOT/logs/and_gate_uvm_run.log"
(cd "$BUILD_ROOT/run" && "$BUILD_ROOT/obj_dir/Vand_gate_tb_top") 2>&1 | tee "$RUN_LOG"
grep -q 'AND_GATE_UVM_SCOREBOARD_PASSED' "$RUN_LOG"
grep -Eq 'SCOREBOARD: checked=4 errors=0' "$RUN_LOG"
if grep -Eqi 'UVM_(ERROR|FATAL) *: *[1-9]' "$RUN_LOG"; then
    echo "ERROR: UVM reported errors or fatals; see $RUN_LOG" >&2
    exit 1
fi
if [[ ! -s "$BUILD_ROOT/run/build/and_gate_uvm.vcd" ]]; then
    echo "ERROR: UVM test passed but its VCD was not generated." >&2
    exit 1
fi
echo "PASS Verilator UVM AND-gate: scoreboard and VCD verified"
echo "Logs: $BUILD_ROOT/logs"
