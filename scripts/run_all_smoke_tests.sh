#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
"$ROOT/scripts/compile_iverilog.sh"
"$ROOT/scripts/compile_verilator.sh"
"$ROOT/scripts/compile_uvm.sh"
echo "All RTL and UVM compile/smoke checks passed."
