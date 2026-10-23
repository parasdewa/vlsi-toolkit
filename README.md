# VLSI Toolkit

A command-line toolkit for setting up and checking open-source EDA tools, then
using them to simulate, synthesize, and time RTL projects. Verilator is the
default simulator; Icarus Verilog is available with an explicit option. UVM
simulation uses Verilator.

## Workflow at a glance

Follow these steps for a typical project:

1. Install or check the tools.
2. Create a project or choose an existing one.
3. Run RTL simulation, then inspect its waveform if needed.
4. Run synthesis.
5. If you have a compatible Liberty library and timing constraints, run OpenSTA.
6. Run the toolkit regression suite after toolkit changes.

Unless a step says otherwise, run commands from the toolkit repository root.
For `run`, `synth`, and `timing`, the examples show both direct options and a
TOML manifest. Use a manifest containing the matching section: for example,
`vlsi.toml` for simulation and `vlsi_sky130_timing.toml` for mapped synthesis
and timing. Setup, `doctor`, `init`, `library check`, GTKWave, regression, and
cleanup are standalone commands and do not take a project TOML file.

## 1. Install and check the tools

For a supported Ubuntu or WSL setup, run the setup script. It checks for
installed tools and installs/builds the missing supported tools:

```bash
scripts/tool_setup_and_check.sh
```

To inspect the current tool availability without installing anything:

```bash
./vlsi doctor
```

The setup script supports `--check-only` and `--smoke-only` modes. See
[Installation](docs/INSTALLATION.md) for what each mode does and the supported
tool versions.

## 2. Create or choose a project

To create an empty project scaffold beside the toolkit:

```bash
./vlsi init ../my_rtl_project
```

The command creates directories for RTL, plain and UVM testbench sources,
constraints, configuration, tests, and per-flow build outputs. It also adds
plain simulation, UVM simulation, synthesis, and timing wrapper scripts plus a
`.gitignore`. It does not create design files or TOML manifests; create those
for your project. The wrappers expect `config/plain.toml`, `config/uvm.toml`,
`config/synth.toml`, and `config/timing.toml`. To use the existing demo project,
skip initialization and use its manifests.

The toolkit accepts projects outside its own repository. Project manifests
(`vlsi.toml`) save source files, top modules, simulator settings, and build
directories so commands stay short. See [Create and run a project](docs/NEW_PROJECT.md)
and [Project configuration](docs/PROJECT_CONFIGURATION.md).

## 3. Simulate the RTL

Run the counter fixture by passing the project, top, and source files directly:

```bash
./vlsi run --sim iverilog \
  --project tests/rtl/counter \
  --top counter_tb \
  --rtl counter.sv \
  --tb counter_tb.sv \
  --waveform \
  --build-dir "$PWD/build/counter-iverilog"
```

The equivalent manifest-based command is:

```bash
./vlsi run --config tests/rtl/counter/vlsi.toml
```

The counter manifest selects Icarus. To select Verilator, either change the
direct command's `--sim` value or override the manifest:

```bash
./vlsi run --sim verilator \
  --project tests/rtl/counter \
  --top counter_tb \
  --rtl counter.sv \
  --tb counter_tb.sv \
  --waveform \
  --build-dir "$PWD/build/counter-verilator"

./vlsi run --config tests/rtl/counter/vlsi.toml --sim verilator
```

For the sibling demo project, the direct and manifest forms are:

```bash
./vlsi run --sim verilator \
  --project ../vlsi-toolkit-demo-rtl \
  --top and_gate_tb \
  --rtl rtl/and_gate.sv \
  --tb tb/and_gate_tb.sv \
  --waveform \
  --build-dir "$PWD/build/demo-run"

./vlsi run --config ../vlsi-toolkit-demo-rtl/vlsi.toml
./vlsi run --config ../vlsi-toolkit-demo-rtl/vlsi.toml --sim iverilog
./vlsi run --config ../vlsi-toolkit-demo-rtl/vlsi_uvm.toml
```

For UVM without loading the demo's manifest, list all UVM source files:

```bash
./vlsi run --sim verilator --uvm --jobs 1 \
  --project ../vlsi-toolkit-demo-rtl \
  --top and_gate_tb_top \
  --rtl rtl/and_gate.sv \
  --tb tb/and_gate_if.sv \
  --tb tb/and_gate_pkg.sv \
  --tb tb/and_gate_tb_top.sv \
  --include tb \
  --build-dir "$PWD/build/demo-uvm"
```

The project created in the previous step is an empty scaffold. After adding
your RTL, testbench, and `config/plain.toml`, run its plain flow with:

```bash
cd ../my_rtl_project
./scripts/run_plain.sh
```

Create `config/uvm.toml` for the UVM flow and run `./scripts/run_uvm.sh`.
See [Create and run a project](docs/NEW_PROJECT.md) for the directory layout,
manifest path settings, and direct CLI examples.

## 4. View a waveform

When the testbench produces a VCD, open the generated file with GTKWave:

```bash
gtkwave /path/to/waveform.vcd
```

The simulation output reports the waveform path. You can also pass
`--waveform-file FILE` to choose its path. See [Waveforms](docs/WAVEFORMS.md)
for waveform options and examples.

## 5. Synthesize the design

For generic synthesis, either pass the project and RTL directly:

```bash
./vlsi synth \
  --project tests/rtl/counter \
  --top counter \
  --rtl counter.sv \
  --build-dir "$PWD/build/counter-generic"
```

or load its project manifest:

```bash
./vlsi synth --config tests/rtl/counter/vlsi.toml
```

This checks the synthesis flow and writes netlists and reports under the build
directory. To map the design to a target standard-cell library, supply a
compatible Liberty file. ABC's synthesis-time delay estimate can also be
enabled with ABC driver/load constraints. See [Synthesis](docs/SYNTHESIS.md)
for the generic and mapped flows.

## 6. Run static timing analysis

OpenSTA analyzes a mapped gate-level netlist using the same target Liberty
library and an SDC constraints file. The toolkit does not bundle a PDK or
select a target library. This host has a Sky130 HD Liberty file at the path
below; set `LIBERTY` to your own installed library on other systems, then
validate it:

```bash
source "$HOME/opt/opensta/opensta-env.sh"
export LIBERTY="$HOME/opt/pdk/sky130hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib"
./vlsi library check --liberty "$LIBERTY"
```

Use direct options for mapped synthesis and OpenSTA timing:

```bash
./vlsi synth \
  --project tests/rtl/counter \
  --top counter \
  --rtl counter.sv \
  --liberty "$LIBERTY" \
  --build-dir "$PWD/build/counter-synth"

./vlsi timing \
  --project tests/rtl/counter \
  --top counter \
  --netlist "$PWD/build/counter-synth/netlist.v" \
  --liberty "$LIBERTY" \
  --sdc timing.sdc \
  --build-dir "$PWD/build/counter-timing"
```

The equivalent commands load synthesis and timing settings from the same
manifest:

```bash
./vlsi synth --config tests/rtl/counter/vlsi_sky130_timing.toml
./vlsi timing --config tests/rtl/counter/vlsi_sky130_timing.toml
```

The [timing manifest](tests/rtl/counter/vlsi_sky130_timing.toml) contains the
RTL top and source, Liberty path, synthesis output directory, mapped netlist
path, SDC path, and timing output directory. It uses the local Sky130 path
shown above; edit both `liberty` entries in the TOML if your library is
installed elsewhere. The mapped netlist, synthesis outputs, OpenSTA reports,
and logs stay under `build/counter-synth/` and `build/counter-timing/` in this
repository. These are example constraints, and without routed parasitics the
report does not include wire delay. See [Timing analysis](docs/TIMING_ANALYSIS.md)
for ABC delay estimates, report details, and the limits of this flow.

## 7. Run the toolkit regression suite

After changing toolkit code, run the automated regression suite from the
repository root:

```bash
python3 -m unittest discover -s tests/toolkit -v
```

Integration tests run when their EDA tools are available and use temporary
build directories. The Verilator/UVM test can take several minutes. See
[Regression checks](docs/TESTING.md) for coverage and build isolation.

## Build outputs and cleanup

Generated files are kept under each project's `build/`, `logs/`, or `log/`
directory. `vlsi clean` targets the current working directory, so you can run
the toolkit command from the RTL project to clean that project's outputs. For
example, from the demo project:

```bash
cd ../vlsi-toolkit-demo-rtl
../vlsi-toolkit/vlsi clean --dry-run
../vlsi-toolkit/vlsi clean
```

From the toolkit root, specify the demo path explicitly:

```bash
./vlsi clean --project ../vlsi-toolkit-demo-rtl --dry-run
./vlsi clean --project ../vlsi-toolkit-demo-rtl
```

Review the dry-run paths before cleaning. Only `build/`, `logs/`, and `log/`
inside the selected project root are removed; custom build directories outside
those paths are left alone. Running `./vlsi clean` from the toolkit root cleans
the toolkit outputs.

## Detailed guides

| Guide | Topic |
| --- | --- |
| [Installation](docs/INSTALLATION.md) | Ubuntu/WSL setup and tool checks |
| [Create and run a project](docs/NEW_PROJECT.md) | Starter projects and first runs |
| [Compile and simulate](docs/COMPILATION_AND_SIMULATION.md) | Simulator options, UVM, and compile scripts |
| [Project configuration](docs/PROJECT_CONFIGURATION.md) | TOML settings and CLI overrides |
| [Waveforms](docs/WAVEFORMS.md) | VCD generation and GTKWave |
| [Synthesis](docs/SYNTHESIS.md) | Yosys output, Liberty mapping, and ABC estimates |
| [Timing analysis](docs/TIMING_ANALYSIS.md) | OpenSTA, SDC, Liberty, reports, and limitations |
| [RTL examples](docs/RTL_EXAMPLES.md) | Included RTL fixtures |
| [Regression checks](docs/TESTING.md) | Toolkit automated tests |
| [Troubleshooting](docs/TROUBLESHOOTING.md) | Common setup and flow failures |
| [Tool status](docs/TOOL_STATUS.md) | Recorded host/tool integration status |
| [Setup verification report](docs/SETUP_VERIFICATION_REPORT.md) | Setup smoke-test results |
| [Tool setup plan](docs/TOOL_SETUP_PLAN.md) | Setup implementation plan and history |
