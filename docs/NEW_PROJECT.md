# Create and run a project

These commands assume the toolkit is checked out. If tools are not installed
yet, follow [Installation and tool setup](INSTALLATION.md). From the toolkit
repository, create a starter project:

```bash
./vlsi init ../my_rtl_project
```

The command creates an AND-gate RTL module, a testbench that checks all four
input combinations, a TOML manifest, and a short README. It refuses to write
into a non-empty directory. The generated manifest selects Verilator by
default. Select Icarus explicitly with `--sim iverilog`.

You can run the project from the toolkit repository with its manifest:

```bash
./vlsi run --config ../my_rtl_project/vlsi.toml
./vlsi synth --config ../my_rtl_project/vlsi.toml
```

Or change into the project directory and use the relative toolkit path:

```bash
cd ../my_rtl_project
../vlsi-toolkit/vlsi run --config vlsi.toml
../vlsi-toolkit/vlsi synth --config vlsi.toml
```

`--config vlsi.toml` tells `vlsi` to load saved project settings: source lists,
top modules, simulator and UVM options, and build directories. It is optional.
For a first simulation or synthesis, pass those options directly instead:

```bash
../vlsi-toolkit/vlsi run --sim verilator \
  --project . \
  --top and_gate_tb \
  --rtl rtl/and_gate.sv \
  --tb tb/and_gate_tb.sv

../vlsi-toolkit/vlsi synth \
  --project . \
  --top and_gate \
  --rtl rtl/and_gate.sv
```

For a UVM testbench, add `--uvm --include tb` and list each required UVM
interface, package, and top file with a separate `--tb` option. Add each RTL
source with a separate `--rtl` option. For example, the UVM testbench in
`vlsi-toolkit-demo-rtl` can be run without its manifest using:

```bash
../vlsi-toolkit/vlsi run --sim verilator --uvm --jobs 1 \
  --project . \
  --top and_gate_tb_top \
  --rtl rtl/and_gate.sv \
  --tb tb/and_gate_if.sv \
  --tb tb/and_gate_pkg.sv \
  --tb tb/and_gate_tb_top.sv \
  --include tb \
  --build-dir build/uvm-first-run
```

Use a distinct build directory for each design if you want their build outputs
kept separate. The manifest is convenient for repeated runs because it saves
these options in one place.

The simulation checks the design and writes a VCD under the project's build
directory. Open it with GTKWave, for example:

```bash
gtkwave ../vlsi-toolkit-demo-rtl/build/run/waveforms/and_gate.vcd
```

Edit the generated RTL and testbench to start your design. Add more files by
editing the `[run]` and `[synth]` source lists in `vlsi.toml`. For a project
you want to keep independently, create it outside the toolkit directory and
give that project its own Git repository later. The toolkit accepts external
project paths and does not require projects to be nested inside its repository.

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
