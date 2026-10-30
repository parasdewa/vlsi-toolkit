# Create and run a project

Follow this guide to generate an empty project scaffold, run an existing
design, and configure UVM when needed.

## Contents

- [Create a project scaffold](#create-a-project-scaffold)
- [Pass your own project files directly](#pass-your-own-project-files-directly)
- [Run a UVM project with Verilator](#run-a-uvm-project-with-verilator)

## Create a project scaffold

These commands assume the toolkit is checked out. If tools are not installed
yet, follow [Installation and tool setup](INSTALLATION.md). From the toolkit
repository, create a project scaffold:

```bash
./vlsi init ../my_rtl_project
```

The command creates directories, flow helper scripts, `.gitignore`, and an
`initial-start.md` guide, but no RTL, testbench, constraints, or TOML manifests.
It refuses to write into a non-empty
directory. The structure separates plain simulation sources, UVM components,
constraints, configuration, scripts, tests, and generated build outputs:

```text
my_rtl_project/
├── initial-start.md            # first steps for adding sources and running flows
├── config/                     # user-created plain.toml, uvm.toml, synth.toml, timing.toml
├── rtl/include/
├── constraints/                # kept separate from RTL source files
│   ├── abc/
│   └── sdc/
├── tb/plain/
├── tb/uvm/                     # interfaces, packages, agents, env, sequences, tests, top
├── scripts/                    # run_plain.sh, run_uvm.sh, synth.sh, timing.sh
├── tests/unit/
├── tests/regression/
└── build/                      # per-flow simulation, synthesis, timing outputs
```

Read `initial-start.md` in the new project first. It covers source placement,
manifest setup, the wrapper scripts, waveforms, synthesis, and timing. Then
create your design sources, constraint files, and manifests in the matching
directories. The helper scripts expect `config/plain.toml`, `config/uvm.toml`,
`config/synth.toml`, and `config/timing.toml`. For example:

Because these TOML files live one directory below the project root, set
`[project] root = ".."` in each manifest. Set each flow's `build_dir` to the
matching path under `build/` to keep outputs separated, for example
`build_dir = "build/sim/plain-verilator"` under `[run]`.

```bash
cd ../my_rtl_project
./scripts/run_plain.sh
./scripts/run_plain.sh --sim iverilog
./scripts/run_uvm.sh
./scripts/synth.sh
./scripts/timing.sh
```

The wrappers call `vlsi` from `PATH`, use `../vlsi-toolkit/vlsi` when the
project sits beside the toolkit, or use an executable specified by `VLSI_CLI`.
They forward any extra command-line options. If you want to start without a
manifest, call the toolkit directly and provide your source files explicitly:

```bash
../vlsi-toolkit/vlsi run --sim verilator \
  --project . \
  --top my_testbench \
  --rtl rtl/my_design.sv \
  --tb tb/plain/my_testbench.sv

../vlsi-toolkit/vlsi synth \
  --project . \
  --top my_design \
  --rtl rtl/my_design.sv
```

For a UVM testbench, add `--uvm` and list each interface, package, and top
source with a separate `--tb` option. Set `--include` to the directory or
directories containing UVM includes. For example, after creating these files:

```bash
../vlsi-toolkit/vlsi run --sim verilator --uvm --jobs 1 \
  --project . \
  --top my_uvm_top \
  --rtl rtl/my_design.sv \
  --tb tb/uvm/interfaces/my_if.sv \
  --tb tb/uvm/packages/my_pkg.sv \
  --tb tb/uvm/top/my_uvm_top.sv \
  --include tb/uvm \
  --build-dir build/uvm-first-run
```

Manifests save source lists, top modules, simulator/UVM settings, and build
directories. Keep simulation, synthesis, and timing outputs in distinct build
directories. Logs and reports are written within each flow's build directory.

The simulation checks the design and writes a VCD under the project's build
directory. Open it with GTKWave, for example:

```bash
gtkwave build/sim/plain-verilator/waveforms/my_design.vcd
```

For a project you want to keep independently, create it outside the toolkit
directory and give that project its own Git repository. The toolkit accepts
external project paths and does not require projects to be nested inside its
repository.

## Pass your own project files directly

For an existing project without a manifest, pass the project root, top module,
and source files directly:

```bash
./vlsi run --sim iverilog \
  --project /path/to/my_project \
  --top my_testbench \
  --rtl rtl/my_design.sv \
  --tb tb/my_testbench.sv \
  --waveform
```

Runs without an explicit simulator use Verilator. Use `--sim iverilog` to
select Icarus. Paths after `--rtl`, `--tb`, and `--include` are resolved
relative to `--project`. Run `./vlsi run --help` for the full option list.

## Run a UVM project with Verilator

UVM is selected as a Verilator run option. A project manifest can include:

```toml
[run]
sim = "verilator"
uvm = true
top = "my_uvm_top"
rtl = ["rtl/design.sv"]
tb = ["tb/interface.sv", "tb/package.sv", "tb/my_uvm_top.sv"]
include = ["tb"]
jobs = 1
```

Set `VERILATOR_UVM_DIR` to the directory containing Verilator's supported
`uvm_pkg_all_v2020_3_2_nodpi.svh` package when it cannot be discovered:

```bash
export VERILATOR_UVM_DIR=/path/to/verilator/test_regress/t/uvm
./vlsi run --config /path/to/my_project/vlsi.toml
```

Or run with `--uvm` on the command line and pass `--uvm-dir DIR` if needed.
UVM requires Verilator 5.052 or newer. The toolkit setup command can install
missing Ubuntu tools and prepare the verified Verilator/UVM toolchain.
