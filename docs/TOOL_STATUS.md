# Tool status

This is a snapshot of the tools and flows observed in the WSL environment.
Versions and paths are host-specific; rerun `./vlsi doctor` to check the
current machine.

## Tool and runner coverage

Status as checked in this WSL environment:

| Tool | Detection | Toolkit runner |
| --- | --- | --- |
| Icarus Verilog (`iverilog`) | Version query works | Implemented on the counter, including VCD output |
| `vvp` | Version query works | Used by the Icarus runner |
| Verilator | Version query works | Implemented on the counter with one build job, including VCD output |
| Verilator UVM | Verilator 5.052+ and UVM 2020.3.2 source required | `vlsi run --uvm` compiles and runs UVM projects |
| Yosys | Version query works | `synth` command exercised on the counter; JSON and Verilog netlists generated, zero `check` problems |
| OpenSTA (`sta`) | OpenSTA 3.1.0 installed under `/home/parasdewa/opt/opensta`; found by `vlsi doctor` | Counter mapped-netlist timing report generated; CLI reports status from worst slack |
| GTKWave | Executable found | GUI launch is not checked by `doctor` |

## Interpretation

`./vlsi doctor` checks executable availability and gives Ubuntu install
commands for missing tools. It does not claim that every feature of each
installed EDA tool has been tested. OpenSTA was manually validated with the
counter fixture and a Sky130 HD Liberty library. Use
`scripts/tool_setup_and_check.sh` for the simulation/UVM/Yosys smoke checks;
OpenSTA build guidance is in [TIMING_ANALYSIS.md](TIMING_ANALYSIS.md).
