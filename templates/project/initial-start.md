# Initial Start Guide

This guide takes a newly initialized project from an empty scaffold to its
first directed simulation, UVM simulation, synthesis, and timing run. It assumes
you created the project with `vlsi init` and that the toolkit CLI is available
as `vlsi` or at `../vlsi-toolkit/vlsi`.

Before starting, check the installed tools from the toolkit directory:

```bash
../vlsi-toolkit/vlsi doctor
```

If tools are missing on Ubuntu, run the toolkit setup script from its
repository and follow any install prompts:

```bash
cd ../vlsi-toolkit
./scripts/tool_setup_and_check.sh
cd /path/to/your/project
```

## 1. Start with a few project habits

- Keep synthesizable design sources in `rtl/`, directed testbenches in
  `tb/directed/`, and UVM components in their matching `tb/uvm/` subdirectories.
- Keep ABC and SDC constraints in the top-level `constraints/` directory,
  separate from RTL sources.
- List source files explicitly in each TOML manifest. For UVM, list packages
  after the interfaces and before the agents, environment, tests, and top.
- Keep simulation, synthesis, and timing outputs in their separate `build/`
  subdirectories. The scaffold's `.gitignore` excludes generated build output.
- First compile and simulate a small directed test. Add UVM and technology
  mapping once the directed RTL flow works.
- Commit source, testbench, configuration, and constraint changes together
  when they describe one reproducible design state.

## 2. Put your sources in the project tree

```text
rtl/
├── include/                 # RTL headers and include files
└── *.sv                     # synthesizable design files
tb/
├── directed/                # directed/non-UVM testbenches
└── uvm/
    ├── interfaces/
    ├── packages/
    ├── agents/
    ├── env/
    ├── sequences/
    ├── tests/
    └── top/                 # simulation top module
constraints/
├── abc/                     # ABC driver/load assumptions, if mapping to Liberty
└── sdc/                     # OpenSTA timing constraints
config/
├── simulation/
│   ├── directed/
│   └── uvm/
├── synthesis/
└── timing/
scripts/
├── simulation/
│   ├── directed/
│   └── uvm/
├── synthesis/
└── timing/
build/                       # generated outputs; keep each flow in its own path
```

The generated project also includes a root `Makefile` with shortcuts for
common flows. Start with `make help`; run Make targets from the project root.
Use descriptive filenames and keep modules in a deliberate compile order.
Each file passed to `--rtl` or `--tb` must exist. Paths in manifests are
resolved from the project root, configured with `[project] root` in each
manifest. Simulation manifests are three directories below the project root,
so they use `root = "../../.."`; synthesis and timing manifests use
`root = "../.."`.
`vlsi init` creates starter manifests in `config/`; edit their example tops
and source paths to match the files you add. The placeholder paths are not
real design files, so the flows will fail until you update them.

## 3. Configure directed simulation

Edit `config/simulation/directed/directed.toml` for the default directed run.
For each additional design, create another manifest in
`config/simulation/directed/` (for example, `counter_4bit.toml`) with its own
top, source list, waveform settings, and build directory. Add one entry for
every RTL and testbench source file.

```toml
[project]
root = "../../.."

[run]
sim = "verilator"
uvm = false
top = "my_directed_tb"
rtl = ["rtl/my_design.sv"]
tb = ["tb/directed/my_directed_tb.sv"]
include = ["rtl/include"]
waveform = true
build_dir = "build/sim/plain-verilator"
```

If there are multiple files, list them in compile order. If the testbench does
not need an include directory, set `include = []` or remove that line. For
Icarus, the manifest may select `sim = "iverilog"`; you can also keep
Verilator as the default and override it on the command line.

Run the default directed manifest, or select a design-specific manifest from
the project root:

```bash
./scripts/simulation/directed/run_directed.sh
./scripts/simulation/directed/run_directed.sh --sim iverilog
./scripts/simulation/directed/run_directed.sh config/simulation/directed/counter_4bit.toml
./scripts/simulation/directed/run_directed.sh config/simulation/directed/counter_4bit.toml --sim iverilog
```

Equivalent direct CLI forms are:

```bash
../vlsi-toolkit/vlsi run --config config/simulation/directed/directed.toml
../vlsi-toolkit/vlsi run --config config/simulation/directed/directed.toml --sim iverilog
```

The run writes its VCD under the configured build directory when waveform
generation is enabled. For that to work, the testbench must include the
conditional `VLSI_WAVEFORM` dump hook. See
[`../vlsi-toolkit/docs/WAVEFORMS.md`](../vlsi-toolkit/docs/WAVEFORMS.md) for
the hook and examples.
Open the VCD with GTKWave, using the path printed by the run or the configured
build path, for example:

```bash
gtkwave build/sim/plain-verilator/waveform.vcd
```

For a custom waveform location, set `waveform_file` in `[run]`, for example
`waveform_file = "waveforms/my_directed_tb.vcd"`. Relative waveform filenames are
under the selected build directory.

Once the matching manifest exists, the Makefile selects it by design name:

```bash
make sim                         # starter directed manifest
make sim DESIGN=my_design        # config/simulation/directed/my_design.toml
make sim DESIGN=my_design SIM=iverilog
```

`CONFIG=path/to/manifest.toml` is an optional override when the manifest is in
a different location. The Makefile adds a separate build directory when you
set `SIM`; keep that directory and the manifest's `waveform_file` consistent.

## 4. Configure UVM simulation

Edit `config/simulation/uvm/uvm.toml`. Update the source list and top for your
environment.
Order UVM sources so declarations are available before they are used.

```toml
[project]
root = "../../.."

[run]
sim = "verilator"
uvm = true
top = "my_uvm_top"
rtl = ["rtl/my_design.sv"]
tb = [
  "tb/uvm/interfaces/my_if.sv",
  "tb/uvm/packages/my_pkg.sv",
  "tb/uvm/agents/my_agent.sv",
  "tb/uvm/env/my_env.sv",
  "tb/uvm/sequences/my_sequence.sv",
  "tb/uvm/tests/my_test.sv",
  "tb/uvm/top/my_uvm_top.sv",
]
include = ["rtl/include", "tb/uvm"]
jobs = 1
waveform_file = "waveforms/my_uvm_top.vcd"
build_dir = "build/sim/uvm-verilator"
```

Run it with Verilator:

```bash
./scripts/simulation/uvm/run_uvm.sh
./scripts/simulation/uvm/run_uvm.sh config/simulation/uvm/my_uvm_design.toml
```

Equivalent direct CLI command:

```bash
../vlsi-toolkit/vlsi run --config config/simulation/uvm/uvm.toml
```

The short Makefile form selects `config/simulation/uvm/<design>.toml`:

```bash
make uvm                         # starter UVM manifest
make uvm DESIGN=my_design        # design-specific UVM manifest
make wave-uvm DESIGN=my_design   # open that design's expected UVM VCD
```

The UVM manifest should use `build/sim/<design>-uvm-verilator` as its
`build_dir` and `waveforms/<design>_uvm.vcd` as its `waveform_file` for the
automatic `make wave-uvm DESIGN=...` lookup. Otherwise pass
`WAVEFORM=path/to/file.vcd` to override the waveform path.

UVM is supported here with Verilator and requires its compatible UVM package.
If automatic discovery cannot find the package, set `VERILATOR_UVM_DIR` to the
directory containing `uvm_pkg_all_v2020_3_2_nodpi.svh`. Keep `jobs = 1` on
memory-limited machines. Open its generated waveform with:

```bash
gtkwave build/sim/uvm-verilator/waveforms/my_uvm_top.vcd
```

## 5. Configure synthesis

Edit `config/synthesis/synth.toml`. Only synthesizable RTL belongs in this source list;
do not include testbench files. The following is generic synthesis without a
technology library:

```toml
[project]
root = "../.."

[synth]
top = "my_design"
rtl = ["rtl/my_design.sv"]
include = ["rtl/include"]
build_dir = "build/synth/generic"
```

Run synthesis with either the wrapper or the direct CLI:

```bash
./scripts/synthesis/synth.sh
./scripts/synthesis/synth.sh config/synthesis/counter_4bit.toml
../vlsi-toolkit/vlsi synth --config config/synthesis/synth.toml
```

The Makefile selects the matching synthesis manifest from `DESIGN`:

```bash
make synth DESIGN=my_design
make synth-mapped DESIGN=my_design
```

Both targets use `config/synthesis/my_design.toml`; configure its `[synth]`
table with or without Liberty/ABC mapping as appropriate. An optional
`CONFIG=path/to/manifest.toml` overrides that selection.

For standard-cell mapping and the timing flow in the next section, replace the
`[synth]` section above with one that adds an explicit Liberty file and a
compatible ABC constraints file, for example. After adding the matching
design-named manifest under `config/synthesis/`, run
`make synth-mapped DESIGN=my_design`:

```toml
[synth]
top = "my_design"
rtl = ["rtl/my_design.sv"]
include = ["rtl/include"]
liberty = "/absolute/path/to/compatible_standard_cells.lib"
abc_constraints = "constraints/abc/my_design.abc"
delay_ps = 10000
build_dir = "build/synth/technology"
```

The ABC assumptions file sets input driver and output load values using cells
and units supported by the chosen library. The ABC estimate is synthesis-time
information, not an OpenSTA timing report. See
[`../vlsi-toolkit/docs/SYNTHESIS.md`](../vlsi-toolkit/docs/SYNTHESIS.md) for
the file format.

## 6. Configure timing and run OpenSTA

Timing analysis uses the technology-mapped gate-level netlist, the same
compatible Liberty library, and an SDC file. Generic synthesis without a
standard-cell mapping is not the expected input for this Liberty-based flow.
First select a library compatible with the target process and mapped cells;
the toolkit does not download or choose a PDK. Put the SDC file under
`constraints/sdc/`.

Edit `config/timing/timing.toml` and set the Liberty path for your machine. Also
ensure its netlist path matches the technology-mapped output directory in
`config/synthesis/synth.toml`:

```toml
[project]
root = "../.."

[timing]
top = "my_design"
netlist = "build/synth/technology/netlist.v"
liberty = "/absolute/path/to/compatible_standard_cells.lib"
sdc = "constraints/sdc/my_design.sdc"
build_dir = "build/timing"
```

Run timing analysis after the corresponding technology-mapped synthesis run.
The Makefile selects `config/timing/<design>.toml` for timing:

```bash
make timing DESIGN=my_design
```

Use `CONFIG=path/to/timing_manifest.toml` when the timing manifest is stored
elsewhere. Ensure its `netlist` setting points to the mapped netlist produced
by that design's synthesis manifest.

```bash
./scripts/timing/timing.sh
./scripts/timing/timing.sh config/timing/counter_4bit.toml
../vlsi-toolkit/vlsi timing --config config/timing/timing.toml
```

The timing reports and OpenSTA logs are stored in `build/timing/`. A Liberty
parse check can help validate the file's syntax before running the full flow:

```bash
../vlsi-toolkit/vlsi library check --liberty /absolute/path/to/compatible_standard_cells.lib
```

The SDC must reflect your design's clock and input/output timing requirements;
do not reuse example periods or delays as signoff constraints without checking
them against the target specification. See
[`../vlsi-toolkit/docs/TIMING_ANALYSIS.md`](../vlsi-toolkit/docs/TIMING_ANALYSIS.md)
for SDC examples and flow limits.

## 7. What the scaffold scripts do

Use `make help` to see short commands for tool checks, setup checks, simulation,
synthesis, mapped synthesis, timing, waveform viewing, and cleanup. Set
`DESIGN=name` to select matching per-design manifests; create those TOML files
first. `CONFIG=path/to/manifest.toml` and `WAVEFORM=path/to/file.vcd` are
optional overrides. For automatic waveform lookup, use
`build_dir = "build/sim/<design>-verilator"` and
`waveform_file = "waveforms/<design>.vcd"` in a directed manifest. For Icarus,
the Makefile expects `build/sim/<design>-iverilog` as the build directory.
For UVM, use `build/sim/<design>-uvm-verilator` and
`waveforms/<design>_uvm.vcd`. The `wave` and `wave-uvm` targets only open an
existing waveform; run the matching simulation first.

Each wrapper accepts an optional manifest path as its first argument (or as
`--config MANIFEST.toml`). With no manifest argument, it uses the starter
manifest shown below. Keep a separate manifest and `build_dir` for each design
so logs and generated reports stay separate.

| Script | Toolkit command | Manifest |
| --- | --- | --- |
| `scripts/simulation/directed/run_directed.sh` | `vlsi run` | `config/simulation/directed/directed.toml` |
| `scripts/simulation/uvm/run_uvm.sh` | `vlsi run` | `config/simulation/uvm/uvm.toml` |
| `scripts/synthesis/synth.sh` | `vlsi synth` | `config/synthesis/synth.toml` |
| `scripts/timing/timing.sh` | `vlsi timing` | `config/timing/timing.toml` |

They find the CLI from `PATH`, the adjacent `../vlsi-toolkit/vlsi`, or the
`VLSI_CLI` environment variable. The scaffold provides starter manifests,
but you must edit their placeholder paths and tops. You still create your RTL,
testbench, and constraint files.
