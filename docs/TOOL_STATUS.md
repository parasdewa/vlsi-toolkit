# Tool status

Status as checked in this WSL environment:

| Tool | Detection | Toolkit runner |
| --- | --- | --- |
| Icarus Verilog (`iverilog`) | Version query works | Implemented on the counter, including VCD output |
| `vvp` | Version query works | Used by the Icarus runner |
| Verilator | Version query works | Implemented on the counter with one build job, including VCD output |
| Verilator UVM | Verilator 5.052+ and UVM 2020.3.2 source required | `vlsi run --uvm` compiles and runs UVM projects |
| Yosys | Version query works | `synth` command exercised on the counter; JSON and Verilog netlists generated, zero `check` problems |
| GTKWave | Executable found | GUI launch is not checked by `doctor` |

`./vlsi doctor` checks executable availability and gives Ubuntu install
commands for missing tools. It does not claim that every feature of each
installed EDA tool has been tested. Use `scripts/tool_setup_and_check.sh` for
the complete version, UVM source, and smoke-test validation.
