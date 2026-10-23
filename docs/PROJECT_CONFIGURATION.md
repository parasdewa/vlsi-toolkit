# Project configuration

Use a TOML manifest to save the options for simulation, synthesis, and timing
analysis. This page describes path resolution, supported fields, and CLI
overrides.

## Contents

- [Manifest structure](#manifest-structure)
- [Run a configured flow](#run-a-configured-flow)
- [Supported settings](#supported-settings)
- [Command-line overrides](#command-line-overrides)

## Manifest structure

`vlsi run`, `vlsi synth`, and `vlsi timing` accept `--config FILE` for a TOML project manifest.
The manifest's paths are resolved from `[project].root`, which is relative to
the manifest file. If `[project].root` is omitted, the manifest directory is
the project root.

```toml
[project]
root = "."

[run]
sim = "verilator"
uvm = false
top = "counter_tb"
rtl = ["counter.sv"]
tb = ["counter_tb.sv"]
include = []
defines = []
sim_args = []
waveform = false
jobs = 1

[synth]
top = "counter"
rtl = ["counter.sv"]
include = []
defines = []
build_dir = "build/synth"
# Optional technology-mapping inputs:
# liberty = "lib/standard_cells.lib"
# abc_constraints = "constraints/abc.constr"
# delay_ps = 1000

[timing]
top = "counter"
netlist = "build/synth/netlist.v"
liberty = "lib/standard_cells.lib"
sdc = "constraints/counter.sdc"
# Optional post-route parasitics:
# spef = "parasitics/counter.spef"
build_dir = "build/timing"
```

## Run a configured flow

Run a configured workflow with:

```bash
./vlsi run --config path/to/vlsi.toml
./vlsi synth --config path/to/vlsi.toml
./vlsi timing --config path/to/vlsi.toml
```

## Supported settings

The selected command requires its matching table (`[run]`, `[synth]`, or
`[timing]`). RTL and testbench files, include directories, and defines are
arrays of strings.
`[run].sim` accepts `iverilog` or `verilator` and defaults to `verilator` when
omitted; use `--sim iverilog` to select Icarus from the command line.
`[run].jobs` accepts `1` or `2`.
Set `[run].uvm = true` to compile with Verilator's UVM 2020.3.2 package; this
requires `[run].sim = "verilator"`. `[run].uvm_dir` can specify the package
directory when it cannot be found through `VERILATOR_UVM_DIR` or
`VERILATOR_ROOT`.
`[run].waveform` is a boolean. `[run].waveform_file` may specify a custom VCD
path and enables waveform generation; relative paths are resolved from the
selected build directory. `build_dir` may be set in `[run]`, `[synth]`, or
`[timing]`; a relative value is resolved from the project root. Unspecified
build directories use the normal toolkit defaults.

For synthesis, `liberty` selects a target cell library. `abc_constraints` is
Yosys ABC's two-line input-driver/output-load constraints file and requires
`liberty`; `delay_ps` is an optional positive ABC delay target and also
requires `liberty`. ABC emits its separate delay estimate in
`abc_timing_report.txt` when `abc_constraints` is set. These are not a general
SDC interface. Paths are resolved from the project root. See
[SYNTHESIS.md](SYNTHESIS.md) for details and limits.

For timing, `netlist`, `liberty`, and `sdc` are required. Optional `spef`
provides extracted parasitics. The timing command uses OpenSTA and writes
`timing_report.txt`, `setup_check.txt`, a reproducible `timing.tcl`, and the
full `timing.log` under the timing build directory. See
[TIMING_ANALYSIS.md](TIMING_ANALYSIS.md) for constraint examples and setup.

## Command-line overrides

Pass CLI options to override manifest values. Repeated CLI list options replace
the manifest list for that field. `--project` overrides the configured project
root, and relative RTL/include paths then resolve from the override. Use
`--no-waveform` to disable a manifest's waveform setting.

The included examples are `tests/rtl/counter/vlsi.toml` and
`tests/rtl/and_gate_synthesis/vlsi.toml`.
