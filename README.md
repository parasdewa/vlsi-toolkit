# VLSI Toolkit

The VLSI Toolkit helps you check and install open-source EDA tools, run
simulation and synthesis flows, and analyze timing with OpenSTA. This README is
organized as a four-phase path: check the tools, exercise toolkit fixtures,
run the separate demo project, then create your own project.

## Four-phase workflow

1. **Check and smoke-test the tools** in this toolkit repository.
2. **Run toolkit fixtures manually** with Icarus, Verilator, UVM, Yosys, and
   OpenSTA.
3. **Run the same flows on the demo RTL repository.**
4. **Create and configure your own RTL project.**

Commands in Phases 1 and 2 assume the current directory is the root of
`vlsi-toolkit`, unless a command says otherwise.

For shorter commands, the root Makefile provides targets for tool setup,
simulation, synthesis, timing, project initialization, cleanup, waveform
viewing, and Liberty validation. It selects fixture manifests from `DESIGN`
when available; `CONFIG=path/to/manifest.toml` remains an override. Run
`make help` for its targets.

## Phase 1: Check, install, and smoke-test the tools

### 1. Check which tools are available

This read-only command reports the toolkit's tools and suggests setup steps
when a required executable is missing:

```bash
./vlsi doctor
```

For a fuller setup check, use `--check-only`. It does not install tools or
compile anything; it reports missing packages and available installation
guidance:

```bash
scripts/tool_setup_and_check.sh --check-only
```

### 2. Install missing tools, then run the smoke suite

On supported Ubuntu or WSL, the default setup command checks dependencies,
installs missing Ubuntu packages, builds the supported Verilator/UVM and
OpenSTA tools when needed, and then runs the smoke suite:

```bash
scripts/tool_setup_and_check.sh
```

The setup may use `sudo` to install packages. If the tools are already
installed and you only want the smoke suite, run:

```bash
scripts/tool_setup_and_check.sh --smoke-only
```

The smoke suite checks these flows:

| Check | Smoke coverage |
| --- | --- |
| Icarus Verilog | Compile and run the counter RTL with its non-UVM testbench |
| Verilator | Compile and run that counter RTL and testbench |
| Verilator UVM | Run the AND-gate UVM scoreboard test |
| Yosys | Synthesize the counter and verify its netlists |
| OpenSTA | Run timing analysis on a small synthetic Liberty/netlist fixture |
| GTKWave | Confirm the executable is available; the GUI is not launched |

The OpenSTA smoke check verifies that the timing tool runs. It does not time
the counter RTL or install a PDK. Real RTL timing analysis with a selected
Liberty library is covered in Phases 2 and 3. Setup logs and generated smoke
outputs are stored under `build/tool_setup/`.

For setup options, supported versions, and failure guidance, see
[Installation and tool setup](docs/INSTALLATION.md) and
[Troubleshooting](docs/TROUBLESHOOTING.md).

## Phase 2: Run toolkit fixtures manually

This phase runs individual commands so you can see each compile, simulation,
synthesis, and timing result. The directed counter fixture is used for both
simulators and for synthesis/timing. The separate AND-gate fixture provides
the toolkit's UVM testbench.

### 1. Simulate with Icarus Verilog

Direct command:

```bash
./vlsi run --sim iverilog \
  --project tests/rtl/counter \
  --top counter_tb \
  --rtl counter.sv \
  --tb counter_tb.sv \
  --waveform-file waveforms/counter.vcd \
  --build-dir "$PWD/build/phase-2/counter-iverilog"
```

Manifest command:

```bash
./vlsi run --config tests/rtl/counter/vlsi.toml \
  --build-dir "$PWD/build/phase-2/counter-iverilog"
```

### 2. Simulate with Verilator

Direct command:

```bash
./vlsi run --sim verilator \
  --project tests/rtl/counter \
  --top counter_tb \
  --rtl counter.sv \
  --tb counter_tb.sv \
  --waveform-file waveforms/counter.vcd \
  --build-dir "$PWD/build/phase-2/counter-verilator"
```

Manifest command:

```bash
./vlsi run --config tests/rtl/counter/vlsi.toml --sim verilator \
  --build-dir "$PWD/build/phase-2/counter-verilator"
```

### 3. Run the UVM testbench with Verilator

The UVM fixture is in `tests/uvm/and_gate/`. The run should print
`AND_GATE_UVM_SCOREBOARD_PASSED`. UVM requires Verilator 5.052 or newer and
the matching UVM 2020.3.2 sources. If the package is not discovered
automatically, set `VERILATOR_UVM_DIR` to the directory containing
`uvm_pkg_all_v2020_3_2_nodpi.svh`.

Direct command:

```bash
./vlsi run --sim verilator --uvm --jobs 1 \
  --project tests/uvm/and_gate \
  --top and_gate_tb_top \
  --rtl rtl/and_gate.sv \
  --tb tb/and_gate_if.sv \
  --tb tb/and_gate_pkg.sv \
  --tb tb/and_gate_tb_top.sv \
  --include tb \
  --build-dir "$PWD/build/phase-2/and-gate-uvm"
```

Manifest command:

```bash
./vlsi run --config tests/uvm/and_gate/vlsi.toml \
  --build-dir "$PWD/build/phase-2/and-gate-uvm"
```

The manifest normally writes under `build/uvm-and-gate/`; the override above
puts this run in the Phase 2 build directory.

### Inspect phase-2 waveforms

Open the generated VCD files with GTKWave:

```bash
gtkwave "$PWD/build/phase-2/counter-iverilog/waveforms/counter.vcd"
gtkwave "$PWD/build/phase-2/counter-verilator/waveforms/counter.vcd"
gtkwave "$PWD/build/phase-2/and-gate-uvm/build/and_gate_uvm.vcd"
```

The UVM testbench writes its VCD under a `build/` subdirectory inside the
selected UVM build directory. GTKWave needs a working WSLg or X display.

### 4. Synthesize the counter with Yosys

This is generic synthesis and does not require a technology library.

Direct command:

```bash
./vlsi synth \
  --project tests/rtl/counter \
  --top counter \
  --rtl counter.sv \
  --build-dir "$PWD/build/phase-2/counter-synth-generic"
```

Manifest command:

```bash
./vlsi synth --config tests/rtl/counter/vlsi.toml \
  --build-dir "$PWD/build/phase-2/counter-synth-generic"
```

### 5. Map the counter and run OpenSTA timing

OpenSTA analyzes a mapped gate-level netlist using a Liberty library and SDC
constraints. Set `LIBERTY` to a compatible library installed on your system.
The following path is the local Sky130 HD example on this host:

```bash
source "$HOME/opt/opensta/opensta-env.sh"
export LIBERTY="$HOME/opt/pdk/sky130hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib"
./vlsi library check --liberty "$LIBERTY"
```

Direct commands; synthesis must finish before timing analysis:

```bash
./vlsi synth \
  --project tests/rtl/counter \
  --top counter \
  --rtl counter.sv \
  --liberty "$LIBERTY" \
  --build-dir "$PWD/build/phase-2/counter-synth-sky130"

./vlsi timing \
  --project tests/rtl/counter \
  --top counter \
  --netlist "$PWD/build/phase-2/counter-synth-sky130/counter_netlist.v" \
  --liberty "$LIBERTY" \
  --sdc timing.sdc \
  --build-dir "$PWD/build/phase-2/counter-timing"
```

Manifest commands, with output paths overridden so they use the same isolated
build locations:

```bash
./vlsi synth --config tests/rtl/counter/vlsi_sky130_timing.toml \
  --build-dir "$PWD/build/phase-2/counter-synth-sky130"

./vlsi timing --config tests/rtl/counter/vlsi_sky130_timing.toml \
  --netlist "$PWD/build/phase-2/counter-synth-sky130/counter_netlist.v" \
  --build-dir "$PWD/build/phase-2/counter-timing"
```

The checked-in timing manifest uses the local Sky130 library path. Edit its
`liberty` entries if your library is elsewhere. The toolkit does not install
or select a PDK. ABC delay estimates are synthesis estimates; OpenSTA reports
use the selected Liberty and SDC. Without routed parasitics, timing reports
do not include wire delay. See [Synthesis](docs/SYNTHESIS.md) and
[Timing analysis](docs/TIMING_ANALYSIS.md) for report interpretation.

## Phase 3: Run the demo RTL project

The separate [`vlsi-toolkit-demo-rtl`](../vlsi-toolkit-demo-rtl/) repository
contains one AND-gate RTL design with directed and UVM testbenches, constraints,
manifests, and flow scripts. Change into that repository before running the
commands below:

```bash
cd ../vlsi-toolkit-demo-rtl
```

### 1. Plain simulation with Icarus Verilog

Direct command:

```bash
../vlsi-toolkit/vlsi run --sim iverilog \
  --project . --top and_gate_tb \
  --rtl rtl/and_gate.sv --tb tb/directed/and_gate_tb.sv \
  --waveform-file waveforms/and_gate.vcd \
  --build-dir "$PWD/build/phase-3/plain-iverilog"
```

Manifest command:

```bash
../vlsi-toolkit/vlsi run --config config/simulation/directed/and_gate.toml --sim iverilog \
  --build-dir "$PWD/build/phase-3/plain-iverilog"
```

### 2. Plain simulation with Verilator

Direct command:

```bash
../vlsi-toolkit/vlsi run --sim verilator \
  --project . --top and_gate_tb \
  --rtl rtl/and_gate.sv --tb tb/directed/and_gate_tb.sv \
  --waveform-file waveforms/and_gate.vcd \
  --build-dir "$PWD/build/phase-3/plain-verilator"
```

Manifest command:

```bash
../vlsi-toolkit/vlsi run --config config/simulation/directed/and_gate.toml --sim verilator \
  --build-dir "$PWD/build/phase-3/plain-verilator"
```

### 3. UVM simulation with Verilator

Direct command:

```bash
../vlsi-toolkit/vlsi run --sim verilator --uvm --jobs 1 \
  --project . --top and_gate_tb_top \
  --rtl rtl/and_gate.sv \
  --tb tb/uvm/interfaces/and_gate_if.sv \
  --tb tb/uvm/packages/and_gate_pkg.sv \
  --tb tb/uvm/top/and_gate_tb_top.sv \
  --include tb/uvm \
  --waveform-file waveforms/and_gate_uvm.vcd \
  --build-dir "$PWD/build/phase-3/uvm-verilator"
```

Manifest command:

```bash
../vlsi-toolkit/vlsi run --config config/simulation/uvm/and_gate.toml \
  --build-dir "$PWD/build/phase-3/uvm-verilator"
```

### Inspect phase-3 waveforms

Open the plain and UVM simulation VCDs with GTKWave:

```bash
gtkwave "$PWD/build/phase-3/plain-iverilog/waveforms/and_gate.vcd"
gtkwave "$PWD/build/phase-3/plain-verilator/waveforms/and_gate.vcd"
gtkwave "$PWD/build/phase-3/uvm-verilator/waveforms/and_gate_uvm.vcd"
```

GTKWave needs a working WSLg or X display. Simulation logs also print output
paths; use those if you choose different build directories.

### 4. Generic synthesis with Yosys

Direct command:

```bash
../vlsi-toolkit/vlsi synth --project . --top and_gate \
  --rtl rtl/and_gate.sv \
  --build-dir "$PWD/build/phase-3/synth-generic"
```

Manifest command:

```bash
../vlsi-toolkit/vlsi synth --config config/synthesis/and_gate.toml \
  --build-dir "$PWD/build/phase-3/synth-generic"
```

### 5. Mapped synthesis and OpenSTA timing

Select a compatible Liberty library. This example uses the local Sky130 HD
library; change the path if your installation differs:

```bash
source "$HOME/opt/opensta/opensta-env.sh"
export LIBERTY="$HOME/opt/pdk/sky130hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib"
../vlsi-toolkit/vlsi library check --liberty "$LIBERTY"
```

Direct commands:

```bash
../vlsi-toolkit/vlsi synth --project . --top and_gate \
  --rtl rtl/and_gate.sv \
  --liberty "$LIBERTY" \
  --abc-constraints constraints/abc/and_gate.abc \
  --delay-ps 10000 \
  --build-dir "$PWD/build/phase-3/synth-sky130"

../vlsi-toolkit/vlsi timing --project . --top and_gate \
  --netlist "$PWD/build/phase-3/synth-sky130/and_gate_netlist.v" \
  --liberty "$LIBERTY" \
  --sdc constraints/sdc/and_gate.sdc \
  --build-dir "$PWD/build/phase-3/timing-sky130"
```

Manifest commands:

```bash
../vlsi-toolkit/vlsi synth --config config/timing/and_gate.toml \
  --build-dir "$PWD/build/phase-3/synth-sky130"

../vlsi-toolkit/vlsi timing --config config/timing/and_gate.toml \
  --netlist "$PWD/build/phase-3/synth-sky130/and_gate_netlist.v" \
  --build-dir "$PWD/build/phase-3/timing-sky130"
```

The demo timing manifest also contains the host's example Liberty path. Update its
`liberty` entries on another system. The demo's SDC values are examples, not
design signoff constraints. See the
[demo README](../vlsi-toolkit-demo-rtl/README.md) for waveform, output, and
constraint details.

## Phase 4: Create and configure your own project

Return to the toolkit root and initialize a new, empty directory beside it:

```bash
cd ../vlsi-toolkit
./vlsi init ../my_rtl_project
```

`vlsi init` creates this structure and adds the helper scripts, `.gitignore`,
and an `initial-start.md` guide with first steps for adding sources and running
the flows:

```text
my_rtl_project/
├── Makefile
├── initial-start.md
├── config/
│   ├── simulation/
│   │   ├── directed/directed.toml
│   │   └── uvm/uvm.toml
│   ├── synthesis/synth.toml
│   └── timing/timing.toml
├── rtl/include/
├── constraints/
│   ├── abc/
│   └── sdc/
├── tb/
│   ├── directed/
│   └── uvm/
│       ├── interfaces/
│       ├── packages/
│       ├── agents/
│       ├── env/
│       ├── sequences/
│       ├── tests/
│       └── top/
├── scripts/
│   ├── _common.sh
│   ├── simulation/
│   │   ├── directed/run_directed.sh
│   │   └── uvm/run_uvm.sh
│   ├── synthesis/synth.sh
│   └── timing/timing.sh
├── tests/
│   ├── unit/
│   └── regression/
└── build/
    ├── sim/
    ├── synth/
    └── timing/
```

### What `vlsi init` creates

- Project directories for RTL, directed and UVM testbench code, constraints,
  configuration, tests, and separated build flows.
- A root Makefile with shortcuts for simulation, synthesis, timing, cleanup,
  tool checks, Liberty validation, and waveform viewing.
- Wrapper scripts grouped under `scripts/simulation/{directed,uvm}/`,
  `scripts/synthesis/`, and `scripts/timing/`.
- Starter manifests for directed simulation, UVM simulation, synthesis, and
  timing under `config/`.
- `initial-start.md`, which explains source placement, manifest edits, simulation, waveforms, synthesis, and timing.
- A `.gitignore` for generated build, log, and report output.

The wrappers find the toolkit CLI from `PATH`, from the adjacent
`../vlsi-toolkit/vlsi`, or from an executable set in `VLSI_CLI`.

Use the generated Makefile for shorter commands. It selects a matching
per-design manifest from `DESIGN`:

```bash
cd ../my_rtl_project
make help
make sim
make sim DESIGN=counter_4bit SIM=iverilog
make uvm DESIGN=my_uvm_design
make synth DESIGN=counter_4bit
make synth-mapped DESIGN=counter_4bit
make timing DESIGN=counter_4bit
make wave DESIGN=counter_4bit
make clean-dry-run
```

The default manifests are placeholders in an empty scaffold. For each added
design, create matching TOMLs under the corresponding `config/` subdirectory.
The Makefile follows the waveform convention
`build/sim/<design>-<simulator>/waveforms/<design>.vcd`; pass `WAVEFORM=...` if
your manifest uses another output path. `CONFIG=...` can override the selected
manifest for any one flow.

### What you create and configure

`vlsi init` creates starter TOML manifests, but does not create project RTL,
testbench source, or constraint contents. Replace the example top names and
source paths in the manifests with your project files before running the
wrappers:

| Manifest | Toolkit command | Required settings |
| --- | --- | --- |
| `config/simulation/directed/directed.toml` | `vlsi run` | RTL, directed testbench, top, simulator, build directory |
| `config/simulation/uvm/uvm.toml` | `vlsi run` | RTL, UVM source list/include, top, Verilator, build directory |
| `config/synthesis/synth.toml` | `vlsi synth` | Synthesizable RTL, top, build directory |
| `config/timing/timing.toml` | `vlsi timing` | Mapped netlist, Liberty, SDC, top, build directory |

The starter manifests set `[project] root = "../../.."` for simulation configs
and `"../.."` for synthesis and timing configs, so source paths resolve from
the project root. Put ABC synthesis assumptions
under `constraints/abc/` and SDC timing constraints under `constraints/sdc/`,
separate from the RTL sources. Choose and install a compatible Liberty library
yourself; the toolkit does not download a PDK. For UVM, install a supported
Verilator/UVM package or set `VERILATOR_UVM_DIR` if automatic discovery fails.

Once you have created the sources and updated their manifest entries, run the
flows from your project root. Each wrapper uses its starter manifest by
default; pass a design-specific manifest as the first argument to select a
different design:

```bash
cd ../my_rtl_project
./scripts/simulation/directed/run_directed.sh
./scripts/simulation/directed/run_directed.sh --sim iverilog
./scripts/simulation/directed/run_directed.sh config/simulation/directed/counter_4bit.toml
./scripts/simulation/directed/run_directed.sh config/simulation/directed/counter_4bit.toml --sim iverilog
./scripts/simulation/uvm/run_uvm.sh
./scripts/simulation/uvm/run_uvm.sh config/simulation/uvm/my_uvm_design.toml
./scripts/synthesis/synth.sh
./scripts/synthesis/synth.sh config/synthesis/counter_4bit.toml
./scripts/timing/timing.sh config/timing/counter_4bit.toml
```

The equivalent `--config MANIFEST.toml` form is also accepted by each wrapper.
Create one TOML manifest per design and give each simulation a unique
`build_dir` so compile logs, run logs, and waveforms stay separate.

For mapped timing, add your Liberty and ABC constraint paths to
`config/synthesis/synth.toml`, set its build directory to the technology-mapped
output, and make `config/timing/timing.toml` point to that output's
`<top>_netlist.v`.
Run `./scripts/synthesis/synth.sh` first, then `./scripts/timing/timing.sh`.
The timing wrapper only analyzes the configured netlist; it does not synthesize it.

See [Create and run a project](docs/NEW_PROJECT.md) and
[Project configuration](docs/PROJECT_CONFIGURATION.md) for manifest examples
and path resolution.

## Cleanup and further documentation

From a project's root, preview and remove its generated output directories
with:

```bash
../vlsi-toolkit/vlsi clean --dry-run
../vlsi-toolkit/vlsi clean
```

The cleanup command removes that project's `build/`, `logs/`, and `log/`
directories. To run the toolkit's automated regression suite after changing
toolkit code:

```bash
cd ../vlsi-toolkit
python3 -m unittest discover -s tests/toolkit -v
```

| Guide | Topic |
| --- | --- |
| [Installation](docs/INSTALLATION.md) | Supported tools, setup modes, and diagnostics |
| [Create and run a project](docs/NEW_PROJECT.md) | Project layout and first runs |
| [Compile and simulate](docs/COMPILATION_AND_SIMULATION.md) | Simulator options, UVM, and waveforms |
| [Project configuration](docs/PROJECT_CONFIGURATION.md) | TOML fields and path resolution |
| [Synthesis](docs/SYNTHESIS.md) | Yosys, Liberty mapping, and ABC estimates |
| [Timing analysis](docs/TIMING_ANALYSIS.md) | OpenSTA, SDC, reports, and limitations |
| [Waveforms](docs/WAVEFORMS.md) | VCD generation and GTKWave |
| [Regression checks](docs/TESTING.md) | Toolkit automated tests |
| [Troubleshooting](docs/TROUBLESHOOTING.md) | Setup and flow failures |
