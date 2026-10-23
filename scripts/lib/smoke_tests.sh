#!/usr/bin/env bash

ts_run_smoke_tests() {
    local root="$1" uvm_dir="$2"
    if ! VERILATOR_UVM_DIR="$uvm_dir" "$root/scripts/run_all_smoke_tests.sh"; then
        ts_diagnose smoke "$root"
        return 1
    fi

    local synth_dir="$root/build/tool_setup/yosys/counter"
    local synth_log="$root/build/tool_setup/logs/yosys_counter.log"
    mkdir -p "$(dirname -- "$synth_log")"
    ts_info "Smoke test: Yosys counter synthesis."
    if ! (cd "$root" && ./vlsi synth --config tests/rtl/counter/vlsi.toml \
        --build-dir "$synth_dir") 2>&1 | tee "$synth_log"; then
        ts_diagnose smoke "$root"
        return 1
    fi
    if [[ ! -s "$synth_dir/netlist.json" || ! -s "$synth_dir/netlist.v" ]]; then
        ts_error "Yosys returned without its expected JSON and Verilog netlists."
        ts_diagnose smoke "$root"
        return 1
    fi
    printf '[PASS] Yosys synthesis outputs verified.\n'

    local waveform
    for waveform in \
        "$root/build/tool_setup/iverilog/counter/waveform.vcd" \
        "$root/build/tool_setup/verilator/counter/waveform.vcd" \
        "$root/build/tool_setup/uvm/run/build/and_gate_uvm.vcd"; do
        if [[ ! -s "$waveform" ]] || ! grep -q '\$enddefinitions' "$waveform"; then
            ts_error "Waveform is missing or malformed: $waveform"
            ts_diagnose smoke "$root"
            return 1
        fi
        printf '[PASS] VCD file verified: %s\n' "$waveform"
    done
    printf '[PASS] GTKWave executable is available; GUI launch is environment-dependent and was not opened.\n'

    local timing_root="$root/build/tool_setup/opensta"
    local timing_dir timing_log fixture="$root/tests/rtl/opensta_smoke"
    mkdir -p "$timing_root"
    timing_dir="$(mktemp -d "$timing_root/smoke.XXXXXX")"
    timing_log="$timing_dir/run.log"
    ts_info "Smoke test: OpenSTA constrained timing on a synthetic one-cell Liberty fixture."
    if ! (cd "$root" && ./vlsi timing --project "$fixture" --top smoke_top \
        --netlist "$fixture/smoke.v" --liberty "$fixture/smoke.lib" \
        --sdc "$fixture/timing.sdc" --build-dir "$timing_dir/build") 2>&1 | tee "$timing_log"; then
        ts_diagnose smoke "$root"
        return 1
    fi
    if ! grep -q 'TIMING_STATUS PASS' "$timing_log" || \
        [[ ! -s "$timing_dir/build/timing.log" ]]; then
        ts_error "OpenSTA did not produce a passing timing status and non-empty report log."
        ts_diagnose smoke "$root"
        return 1
    fi
    printf '[PASS] OpenSTA timing smoke report verified: %s\n' "$timing_dir/build/timing.log"
}
