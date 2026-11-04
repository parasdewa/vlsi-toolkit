# Initial Start: Add and Run a Design

This guide shows how to add one design and its testbenches to a project made
with `vlsi init`. Run commands from the project root. For a multi-file RTL
design, list dependency modules before the top module. The testbench top is the
module named by the simulation manifest; it may differ from the RTL top.

## 1. Put files in the project directories

- Synthesizable RTL: `rtl/` (headers/includes: `rtl/include/`).
- Directed, non-UVM testbench: `tb/directed/`.
- UVM components: `tb/uvm/interfaces/`, `packages/`, `agents/`, `env/`,
  `sequences/`, `tests/`, and `top/`.
- ABC mapping assumptions and SDC timing constraints:
  `constraints/abc/` and `constraints/sdc/`.
- Design-specific manifests: `config/simulation/directed/`,
  `config/simulation/uvm/`, `config/synthesis/`, and `config/timing/`.

For example, a structural 4-bit adder could use `rtl/full_adder.sv` and
`rtl/adder_4bit.sv`, with directed testbench `tb/directed/tb_adder_4bit.sv`.
List `full_adder.sv` before `adder_4bit.sv`. Do not include testbench files in
synthesis sources.

## 2. Directed simulation and waveform

Create `config/simulation/directed/adder_4bit.toml`. Set `root` to `../../..`,
`top` to the testbench module name, and update the ordered `rtl` and `tb`
source paths. Enable waveform output and give the run its own build directory:

```toml
[project]
# Keep for manifests under config/simulation/directed/.
root = "../../.."

[run]
sim = "verilator"
uvm = false
# UPDATE: directed testbench module name.
top = "tb_adder_4bit"
# UPDATE: all RTL files, listed in compile dependency order.
rtl = ["rtl/full_adder.sv", "rtl/adder_4bit.sv"]
# UPDATE: directed testbench source path(s).
tb = ["tb/directed/tb_adder_4bit.sv"]
# UPDATE: include paths if required.
include = ["rtl/include"]
waveform = true
# UPDATE: VCD name; use the design name for automatic Makefile lookup.
waveform_file = "waveforms/adder_4bit.vcd"
# UPDATE: separate build directory for this design.
build_dir = "build/sim/adder_4bit-verilator"
jobs = 1
```

```bash
make sim DESIGN=adder_4bit
make wave DESIGN=adder_4bit
make sim DESIGN=adder_4bit SIM=iverilog
make wave DESIGN=adder_4bit SIM=iverilog
```

The testbench must use the `VLSI_WAVEFORM` dump hook for the configured VCD
path. `make wave` only opens the waveform; run simulation first.

## 3. UVM simulation and waveform

Create `config/simulation/uvm/adder_4bit.toml`. Set `root`, the UVM top module,
ordered RTL sources, all UVM files in dependency order, include directories,
waveform name, and build directory. For the adder, the RTL list remains
`["rtl/full_adder.sv", "rtl/adder_4bit.sv"]`; point `tb` at the UVM files you
create. Typical UVM file order is interface, package, agents/environment,
sequence/test, then top. Use `uvm = true` and `sim = "verilator"`.

```toml
[project]
# Keep for manifests under config/simulation/uvm/.
root = "../../.."

[run]
sim = "verilator"
uvm = true
# UPDATE: UVM top module name.
top = "adder_4bit_uvm_top"
# UPDATE: list design RTL in compile dependency order.
rtl = ["rtl/full_adder.sv", "rtl/adder_4bit.sv"]
# UPDATE: replace with the UVM source files you create, dependency first.
tb = [
  "tb/uvm/interfaces/adder_if.sv",
  "tb/uvm/packages/adder_pkg.sv",
  "tb/uvm/env/adder_env.sv",
  "tb/uvm/tests/adder_test.sv",
  "tb/uvm/top/adder_4bit_uvm_top.sv",
]
# UPDATE: include paths required by the RTL and UVM sources.
include = ["rtl/include", "tb/uvm"]
waveform = true
# UPDATE: VCD name; use <design>_uvm.vcd for automatic wave-uvm lookup.
waveform_file = "waveforms/adder_4bit_uvm.vcd"
# UPDATE: unique UVM build directory.
build_dir = "build/sim/adder_4bit-uvm-verilator"
jobs = 1
```

```bash
make uvm DESIGN=adder_4bit
make wave-uvm DESIGN=adder_4bit
```

UVM requires a compatible UVM package supported by Verilator. Set
`VERILATOR_UVM_DIR` if toolkit discovery cannot find it. Keep `jobs = 1` on
memory-limited machines. The scaffold contains no design-specific UVM source;
create the files listed by your manifest.

## 4. Generic synthesis

Create `config/synthesis/adder_4bit.toml`. Update the design RTL top, ordered
RTL source list, include paths, and output directory. Use `root = "../.."`.

```toml
[project]
# Keep for manifests under config/synthesis/.
root = "../.."

[synth]
# UPDATE: synthesizable RTL top module.
top = "ripple_carry_adder_4bit"
# UPDATE: list synthesizable RTL only, in dependency order.
rtl = ["rtl/full_adder.sv", "rtl/adder_4bit.sv"]
# UPDATE: add include paths if required.
include = ["rtl/include"]
# UPDATE: unique generic synthesis output directory.
build_dir = "build/synth/adder_4bit/generic"
```

```bash
make synth DESIGN=adder_4bit
```

## 5. Mapped synthesis and timing

Create `constraints/abc/adder_4bit.abc` and
`constraints/sdc/adder_4bit.sdc`, then edit both `[synth]` and `[timing]` in
`config/timing/adder_4bit.toml`. Set the compatible Liberty path explicitly in
both tables. `[synth]` needs the RTL top and ordered RTL list, ABC constraint,
mapping delay, and technology build directory. `[timing]` needs the same top
and Liberty, the mapped netlist path inside that synthesis directory, SDC
path, and timing report directory.

```toml
[project]
# Keep for manifests under config/timing/.
root = "../.."

[synth]
# UPDATE: RTL top and ordered synthesizable RTL source list.
top = "ripple_carry_adder_4bit"
rtl = ["rtl/full_adder.sv", "rtl/adder_4bit.sv"]
include = ["rtl/include"]
# UPDATE: compatible target Liberty file; keep the same path in [timing].
liberty = "/absolute/path/to/compatible_standard_cells.lib"
# UPDATE: ABC assumptions file for this design/library.
abc_constraints = "constraints/abc/adder_4bit.abc"
# UPDATE: mapping delay, in picoseconds.
delay_ps = 10000
# UPDATE: technology-mapped synthesis output directory.
build_dir = "build/synth/technology/adder_4bit"

[timing]
# UPDATE: use the RTL top and same Liberty as in [synth].
top = "ripple_carry_adder_4bit"
# UPDATE: path to <top>_netlist.v under the [synth] build_dir.
netlist = "build/synth/technology/adder_4bit/ripple_carry_adder_4bit_netlist.v"
liberty = "/absolute/path/to/compatible_standard_cells.lib"
# UPDATE: design SDC file with clock and I/O timing constraints.
sdc = "constraints/sdc/adder_4bit.sdc"
# UPDATE: timing report output directory.
build_dir = "build/timing/adder_4bit"
```

Run mapped synthesis before STA:

```bash
make synth-mapped DESIGN=adder_4bit
make timing DESIGN=adder_4bit
```

The ABC and SDC files need assumptions appropriate to the chosen library and
design. Example constraints are not signoff constraints. The toolkit does not
download or choose a PDK/Liberty library.

## 6. Check tools and command help

```bash
../vlsi-toolkit/vlsi doctor
make help
```

Use `make clean-dry-run` to preview cleanup and `make clean` to remove generated
build outputs. Each `DESIGN=name` target expects a matching design-named TOML
file in the corresponding `config/` subdirectory. The scaffold's starter TOML
files are examples and must be edited before use.
