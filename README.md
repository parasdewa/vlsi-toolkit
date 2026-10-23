# VLSI Toolkit

A small, direct command line for detecting local EDA tools and running RTL
projects with Icarus Verilog or Verilator. It accepts project source lists
directly or from a TOML project configuration.

## Quick start

From this repository:

```bash
./vlsi doctor
./vlsi run --config ../vlsi-toolkit-demo-rtl/vlsi.toml
```

The runnable RTL/UVM example is in the separate `vlsi-toolkit-demo-rtl`
project directory. This command assumes the toolkit and demo checkouts are
siblings. To create a fresh starter project instead, see
[docs/NEW_PROJECT.md](docs/NEW_PROJECT.md).

The setup helper installs missing Ubuntu packages, prepares a supported
Verilator/UVM toolchain, and runs smoke checks:

```bash
scripts/tool_setup_and_check.sh
```

See [docs/INSTALLATION.md](docs/INSTALLATION.md) for setup and
[docs/NEW_PROJECT.md](docs/NEW_PROJECT.md) for creating and running projects.

To run an existing project directly, for example:

```bash
./vlsi run \
  --project tests/rtl/counter \
  --top counter_tb \
  --rtl counter.sv \
  --tb counter_tb.sv
```

Build products and compile/run logs are written under `build/`. Relative source
and include paths are resolved from `--project`; absolute paths are also
accepted. Repeat `--rtl`, `--tb`, `--include`, `--define`, and `--sim-arg` to
pass multiple values. Verilator uses one build job by default; `--jobs 2` allows
two jobs when more build parallelism is useful.

Add `--waveform` to create `waveform.vcd` in the build directory, or use
`--waveform-file FILE` to choose a path relative to that directory. The
testbench must include a `VLSI_WAVEFORM` conditional block with `$dumpfile` and
`$dumpvars`; the included counter demonstrates this hook.

## Current scope

- `doctor`: reports whether Icarus Verilog, Verilator, Yosys, and GTKWave are
  available.
- `run`: uses Verilator by default and compiles a timed SystemVerilog testbench to a native
  executable and runs it. Build parallelism is limited to one or two jobs.
- `run --sim iverilog`: selects Icarus explicitly, then runs the result with
  `vvp`.
- `run --sim verilator --uvm`: compiles and runs a UVM testbench with the
  supported Verilator UVM package.
- `init PATH`: creates a runnable starter project with RTL, testbench, manifest,
  and README.
- `synth`: runs Yosys synthesis on RTL sources and writes a JSON netlist, a
  Verilog netlist, and a synthesis log.

The UVM source directory can be selected with `VERILATOR_UVM_DIR` or
`--uvm-dir`. See [docs/NEW_PROJECT.md](docs/NEW_PROJECT.md) for a UVM manifest
example.

## Project configuration

You do not need a manifest for a first run. Pass the project directory, module
top, and source files directly:

```bash
./vlsi run --sim verilator \
  --project /path/to/my_project \
  --top my_testbench \
  --rtl rtl/my_design.sv \
  --tb tb/my_testbench.sv
./vlsi synth \
  --project /path/to/my_project \
  --top my_design \
  --rtl rtl/my_design.sv
```

Add another `--rtl` or `--tb` for each additional source file. `run` compiles
and simulates the testbench; `synth` runs Yosys on the RTL sources.

`--config FILE` tells `vlsi` to load saved options from a TOML manifest,
typically `vlsi.toml`. It can store the project root, top modules, RTL and
testbench file lists, simulator and UVM settings, and build directories. This
lets you repeat runs without listing the options each time:

```bash
./vlsi run --config tests/rtl/counter/vlsi.toml
./vlsi synth --config tests/rtl/counter/vlsi.toml
```

Paths in the manifest are relative to its configured project root. Command-line
options override manifest values. See [docs/PROJECT_CONFIGURATION.md](docs/PROJECT_CONFIGURATION.md)
for the supported keys and [docs/NEW_PROJECT.md](docs/NEW_PROJECT.md) for
examples from inside a project directory.

## Regression checks

Run the standard-library regression suite with:

```bash
python3 -m unittest discover -s tests/toolkit -v
```

Simulator and synthesis integration checks run when the corresponding tools
are installed. See [docs/TESTING.md](docs/TESTING.md) for details.

Synthesize the included counter with:

```bash
./vlsi synth \
  --project tests/rtl/counter \
  --top counter \
  --rtl counter.sv
```

By default, synthesis artifacts go to `build/counter/counter/synthesis/`,
separate from simulation and waveform outputs. Use `--build-dir DIR` to select
another location.

The AND-gate example demonstrates multiple RTL files and an include directory:

```bash
./vlsi synth \
  --project tests/rtl/and_gate_synthesis \
  --top and_gate_top \
  --rtl ../and_gate/and_gate.sv \
  --rtl and_gate_top.sv \
  --include include
```

The parameterized synchronous FIFO is the broader RTL and verification
example. See [docs/RTL_EXAMPLES.md](docs/RTL_EXAMPLES.md) for its tested
interface behavior and run/synthesis commands.
