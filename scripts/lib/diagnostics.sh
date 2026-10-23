#!/usr/bin/env bash

ts_diagnose() {
    case "${1:-}" in
        install)
            ts_info "Resolution: read the apt error above, confirm network access, then rerun scripts/tool_setup_and_check.sh."
            ts_info "If sudo is unavailable, run the installer from an administrator account or install the listed apt packages manually."
            ;;
        tools)
            ts_missing_packages
            if ((${#MISSING_PACKAGES[@]})); then
                ts_info "Install the missing Ubuntu packages with:"
                ts_info "  sudo apt-get update && sudo apt-get install -y ${MISSING_PACKAGES[*]}"
                ts_info "Or let the toolkit install only missing packages: scripts/tool_setup_and_check.sh"
            fi
            if ! ts_opensta_is_usable; then
                ts_info "OpenSTA is not available: run scripts/tool_setup_and_check.sh to install its missing build dependencies and build the pinned tool."
            fi
            ts_info "The toolkit CLI needs Python 3.10 or newer; Python 3.10 also needs the Ubuntu python3-tomli package. Check with python3 --version."
            if ! ts_verilator_is_supported; then
                ts_info "For Verilator 5.052 or newer plus its matching UVM package, run: scripts/tool_setup_and_check.sh"
            fi
            ;;
        uvm)
            ts_info "Resolution: locate Verilator's UVM test package and export VERILATOR_UVM_DIR to its directory, then rerun this command."
            ;;
        opensta)
            ts_info "OpenSTA build failed. Inspect build/tool_setup/logs/tool_setup_install.log; verify network access and the CMake, SWIG, Tcl, and Eigen development dependencies."
            ts_info "Retry with scripts/tool_setup_and_check.sh. The installer uses one build job and pins OpenSTA and CUDD source revisions."
            ;;
        smoke)
            local root="${2:-.}"
            if [[ ! -s "$root/build/tool_setup/iverilog/counter/waveform.vcd" || ! -s "$root/build/tool_setup/verilator/counter/waveform.vcd" ]]; then
                ts_info "Waveform resolution: rerun the counter compile script with trace enabled; inspect its simulator log and confirm the testbench has the VLSI_WAVEFORM dump hook."
            fi
            if [[ ! -s "$root/build/tool_setup/uvm/run/build/and_gate_uvm.vcd" ]]; then
                ts_info "UVM waveform resolution: confirm --trace is present in scripts/compile_uvm.sh and that the UVM test completes."
            fi
            if [[ ! -s "$root/build/tool_setup/yosys/counter/netlist.json" || ! -s "$root/build/tool_setup/yosys/counter/netlist.v" ]]; then
                ts_info "Yosys resolution: inspect build/tool_setup/yosys/counter/synth.log for frontend, hierarchy, or check errors."
            fi
            if ! grep -Rqs 'TIMING_STATUS PASS' "$root/build/tool_setup/opensta" 2>/dev/null; then
                ts_info "OpenSTA resolution: confirm 'sta -version' works, then inspect the newest build/tool_setup/opensta/smoke.*/run.log and build/timing.log for Liberty, SDC, or constraint errors."
            fi
            ts_info "Resolution: inspect build/tool_setup/*/logs/*.log; rerun the matching scripts/compile_*.sh after fixing the cause."
            ts_info "GTKWave is checked as an executable and VCD files are checked for content; GUI launch requires a working desktop or WSLg display."
            ;;
        *)
            ts_info "Run scripts/tool_setup_and_check.sh --check-only for a non-installing diagnostic."
            ;;
    esac
}
