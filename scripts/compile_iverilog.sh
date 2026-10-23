#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_ROOT="$ROOT/build/tool_setup/iverilog"
mkdir -p "$BUILD_ROOT/logs"

run_project() {
    local name="$1" config="$2" top="$3"
    local log="$BUILD_ROOT/logs/${name}.log"
    echo "== Icarus: $name =="
    if [[ "$name" == and_gate ]]; then
        (cd "$ROOT" && ./vlsi run --project tests/rtl/and_gate --top "$top" \
            --rtl and_gate.sv --tb and_gate_tb.sv --sim iverilog \
            --build-dir "$BUILD_ROOT/$name") 2>&1 | tee "$log"
    else
        if [[ "$name" == counter ]]; then
            (cd "$ROOT" && ./vlsi run --config "$config" --sim iverilog \
                --build-dir "$BUILD_ROOT/$name" --waveform \
                --waveform-file waveform.vcd) 2>&1 | tee "$log"
        else
            (cd "$ROOT" && ./vlsi run --config "$config" --sim iverilog \
                --build-dir "$BUILD_ROOT/$name") 2>&1 | tee "$log"
        fi
    fi
    echo "PASS Icarus: $name"
}

run_project counter tests/rtl/counter/vlsi.toml counter_tb
run_project and_gate tests/rtl/and_gate_synthesis/vlsi.toml and_gate_tb
run_project sync_fifo tests/rtl/sync_fifo/vlsi.toml sync_fifo_tb
echo "All Icarus RTL/testbench builds and runs passed. Logs: $BUILD_ROOT/logs"
