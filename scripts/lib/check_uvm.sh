#!/usr/bin/env bash

RESOLVED_UVM_DIR=

ts_check_uvm() {
    local candidate root bin
    if [[ -n "${VERILATOR_UVM_DIR:-}" ]]; then
        candidate="$VERILATOR_UVM_DIR"
    else
        candidate=
        if [[ -n "${VERILATOR_ROOT:-}" ]]; then
            candidate="$VERILATOR_ROOT/test_regress/t/uvm"
        else
            bin="$(command -v verilator 2>/dev/null || true)"
            if [[ -n "$bin" ]]; then
                root="$(cd -- "$(dirname -- "$(readlink -f "$bin")")/.." && pwd)"
                candidate="$root/test_regress/t/uvm"
            fi
        fi
    fi
    if [[ -f "$candidate/uvm_pkg_all_v2020_3_2_nodpi.svh" ]] && \
        grep -Fq 'Accellera:1800.2:UVM:2020.3.2' "$candidate/uvm_pkg_all_v2020_3_2_nodpi.svh"; then
        RESOLVED_UVM_DIR="$(cd -- "$candidate" && pwd)"
        printf '[PASS] UVM source %s/uvm_pkg_all_v2020_3_2_nodpi.svh\n' "$RESOLVED_UVM_DIR"
        return 0
    fi
    ts_error "Verilator UVM 2020.3.2 package source was not found."
    ts_error "Set VERILATOR_UVM_DIR to the directory containing the matching 2020.3.2 uvm_pkg_all_v2020_3_2_nodpi.svh."
    ts_error "For a Verilator source checkout, use: export VERILATOR_UVM_DIR=/path/to/verilator/test_regress/t/uvm"
    return 1
}
