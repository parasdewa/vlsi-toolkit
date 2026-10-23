# Tool setup verification report

Checked on 2026-10-22 in Ubuntu 24.04.5 LTS under WSL by running
`scripts/tool_setup_and_check.sh`. The complete run passed.

## Setup result

- All required Ubuntu packages were already present, so `apt` was not run and
  no packages were installed.
- The setup script preserved the existing Verilator 5.052 installation at
  `/home/parasdewa/opt/verilator-5.052/bin/verilator`.
- The Verilator UVM 2020.3.2 no-DPI source package was found at
  `/home/parasdewa/projects/verilator-latest/test_regress/t/uvm`.
- The script printed the environment setup command for future shells:
  `source /home/parasdewa/opt/vlsi-toolkit/verilator-env.sh`.

## Detected tools

All listed tools passed detection in the run log:

| Tool | Observed version/status |
| --- | --- |
| Git | 2.43.0 |
| `tree` | v2.1.3 (Snap) |
| Icarus Verilog / `vvp` | 12.0 stable |
| Verilator | 5.052 (2026-09-05, rev v5.052) |
| UVM package | Verilator UVM 2020.3.2 no-DPI source found |
| Yosys | 0.33 |
| GTKWave | `/usr/bin/gtkwave` found; GUI launch not checked |
| Python | 3.12.3 |
| GNU make / g++ | 4.3 / 13.3.0 |
| Verilator build prerequisites | Autoconf 2.71, Flex 2.6.4, Bison 3.8.2, help2man 1.49.3 |

## Smoke test results

- Icarus compiled and passed counter, AND-gate, and synchronous FIFO tests.
- Verilator compiled and passed the same three tests. Both FIFO runs completed
  200 randomized cycles.
- The Verilator UVM AND-gate test passed four transactions:
  `SCOREBOARD: checked=4 errors=0` and
  `AND_GATE_UVM_SCOREBOARD_PASSED`. UVM reported zero errors and zero fatals;
  it emitted two no-DPI/name-check warnings.
- Yosys synthesized the counter, produced JSON and Verilog netlists, and
  reported zero design-check problems.
- Non-empty waveform files were verified for Icarus, Verilator, and UVM.
- GTKWave was detected, but its graphical interface was not launched.
- Final log status: `[INFO] Tool setup and smoke tests passed.`

The complete console output is preserved in [`log`](../log). Detailed compile
logs and generated smoke-test outputs are under `build/tool_setup/`.
