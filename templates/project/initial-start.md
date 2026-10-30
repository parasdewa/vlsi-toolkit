# Initial Start Guide

This guide takes a newly initialized project from an empty scaffold to its
first plain simulation, UVM simulation, synthesis, and timing run. It assumes
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

- Keep synthesizable design sources in `rtl/`, plain testbenches in
  `tb/plain/`, and UVM components in their matching `tb/uvm/` subdirectories.
- Keep ABC and SDC constraints in the top-level `constraints/` directory,
  separate from RTL sources.
- List source files explicitly in each TOML manifest. For UVM, list packages
  after the interfaces and before the agents, environment, tests, and top.
- Keep simulation, synthesis, and timing outputs in their separate `build/`
  subdirectories. The scaffold's `.gitignore` excludes generated build output.
- First compile and simulate a small directed test. Add UVM and technology
  mapping once the plain RTL flow works.
- Commit source, testbench, configuration, and constraint changes together
  when they describe one reproducible design state.

## 2. Put your sources in the project tree

```text
rtl/
├── include/                 # RTL headers and include files
└── *.sv                     # synthesizable design files
tb/
├── plain/                   # directed/non-UVM testbenches
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
config/                      # project-owned TOML manifests
build/                       # generated outputs; keep each flow in its own path
```

Use descriptive filenames and keep modules in a deliberate compile order.
Each file passed to `--rtl` or `--tb` must exist. Paths in manifests are
resolved from the project root, configured with `[project] root` below.

## 3. Create the plain simulation manifest

Create `config/plain.toml`. Replace the example module and filenames with your
own. Add one entry for every RTL and testbench source file.

```toml
[project]
root = ".."

[run]
sim = "verilator"
uvm = false
top = "my_plain_tb"
rtl = ["rtl/my_design.sv"]
tb = ["tb/plain/my_plain_tb.sv"]
include = ["rtl/include"]
waveform = true
build_dir = "build/sim/plain-verilator"
```

If there are multiple files, list them in compile order. If the testbench does
not need an include directory, set `include = []` or remove that line. For
Icarus, the manifest may select `sim = "iverilog"`; you can also keep
Verilator as the default and override it on the command line.

Run the plain testbench from the project root:

```bash
./scripts/run_plain.sh
./scripts/run_plain.sh --sim iverilog
```

Equivalent direct CLI forms are:

```bash
../vlsi-toolkit/vlsi run --config config/plain.toml
../vlsi-toolkit/vlsi run --config config/plain.toml --sim iverilog
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
`waveform_file = "waveforms/my_plain_tb.vcd"`. Relative waveform filenames are
under the selected build directory.

## 4. Create the UVM simulation manifest

Create `config/uvm.toml`. Update the source list and top for your environment.
Order UVM sources so declarations are available before they are used.

```toml
[project]
root = ".."

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
./scripts/run_uvm.sh
```

Equivalent direct CLI command:

```bash
../vlsi-toolkit/vlsi run --config config/uvm.toml
```

UVM is supported here with Verilator and requires its compatible UVM package.
If automatic discovery cannot find the package, set `VERILATOR_UVM_DIR` to the
directory containing `uvm_pkg_all_v2020_3_2_nodpi.svh`. Keep `jobs = 1` on
memory-limited machines. Open its generated waveform with:

```bash
gtkwave build/sim/uvm-verilator/waveforms/my_uvm_top.vcd
```

## 5. Create the synthesis manifest

Create `config/synth.toml`. Only synthesizable RTL belongs in this source list;
do not include testbench files. The following is generic synthesis without a
technology library:

```toml
[project]
root = ".."

[synth]
top = "my_design"
rtl = ["rtl/my_design.sv"]
include = ["rtl/include"]
build_dir = "build/synth/generic"
```

Run synthesis with either the wrapper or the direct CLI:

```bash
./scripts/synth.sh
../vlsi-toolkit/vlsi synth --config config/synth.toml
```

For standard-cell mapping and the timing flow in the next section, replace the
`[synth]` section above with one that adds an explicit Liberty file and a
compatible ABC constraints file, for example:

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

## 6. Create the timing manifest and run OpenSTA

Timing analysis uses the technology-mapped gate-level netlist, the same
compatible Liberty library, and an SDC file. Generic synthesis without a
standard-cell mapping is not the expected input for this Liberty-based flow.
First select a library compatible with the target process and mapped cells;
the toolkit does not download or choose a PDK. Put the SDC file under
`constraints/sdc/`.

Create `config/timing.toml` and set the Liberty path for your machine:

```toml
[project]
root = ".."

[timing]
top = "my_design"
netlist = "build/synth/technology/netlist.v"
liberty = "/absolute/path/to/compatible_standard_cells.lib"
sdc = "constraints/sdc/my_design.sdc"
build_dir = "build/timing"
```

Run timing analysis after the corresponding technology-mapped synthesis run.

```bash
./scripts/timing.sh
../vlsi-toolkit/vlsi timing --config config/timing.toml
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

The wrappers run the matching toolkit command with the corresponding
configuration file:

| Script | Toolkit command | Manifest |
| --- | --- | --- |
| `scripts/run_plain.sh` | `vlsi run` | `config/plain.toml` |
| `scripts/run_uvm.sh` | `vlsi run` | `config/uvm.toml` |
| `scripts/synth.sh` | `vlsi synth` | `config/synth.toml` |
| `scripts/timing.sh` | `vlsi timing` | `config/timing.toml` |

They find the CLI from `PATH`, the adjacent `../vlsi-toolkit/vlsi`, or the
`VLSI_CLI` environment variable. The scaffold intentionally leaves the
manifests and your RTL, testbench, and constraint files for you to create.
