# Synthesis with Yosys

This guide covers the generic synthesis flow, optional Liberty mapping, and the
ABC delay estimate. For a constrained static timing report, continue to the
[OpenSTA timing guide](TIMING_ANALYSIS.md).

## Contents

- [Generic synthesis](#generic-synthesis)
- [Liberty mapping and ABC constraints](#liberty-mapping-and-abc-constraints)

## Generic synthesis

Use `vlsi synth` to synthesize synthesizable RTL. Pass design source files with
`--rtl`; do not include simulation testbenches:

```bash
./vlsi synth \
  --project tests/rtl/counter \
  --top counter \
  --rtl counter.sv
```

The command runs Yosys `read_verilog -sv`, hierarchy checks, the generic
`synth` flow, `check`, and `stat`. It writes these files to
`build/<project-name>/<top>/synthesis/` by default:

- `synth.ys`: reproducible Yosys command script
- `synth.log`: full Yosys output and cell statistics
- `netlist.json`: machine-readable synthesized design
- `netlist.v`: synthesized Verilog
- `abc_timing_report.txt`: ABC delay and path estimate when technology mapping
  runs (or a note explaining why ABC did not emit an estimate)

Use `--include DIR` for include directories and `--define NAME[=VALUE]` for
preprocessor definitions. Repeat either option as needed. `--build-dir DIR`
sets a separate output directory.

The AND-gate synthesis example uses two RTL files and an include directory:

```bash
./vlsi synth \
  --project tests/rtl/and_gate_synthesis \
  --top and_gate_top \
  --rtl ../and_gate/and_gate.sv \
  --rtl and_gate_top.sv \
  --include include
```

Its wrapper includes `include/and_gate_config.vh` and instantiates the existing
AND gate module from `tests/rtl/and_gate/and_gate.sv`.

By default this is a generic logic synthesis flow. It does not apply a target
cell library or timing constraints; the reported generic cell statistics are
not area or timing estimates for a physical implementation.

## Liberty mapping and ABC constraints

When you have a target standard-cell Liberty file, configure technology mapping
in `[synth]`:

```toml
[synth]
top = "counter"
rtl = ["counter.sv"]
liberty = "lib/standard_cells.lib"
abc_constraints = "constraints/abc.constr"
delay_ps = 1000
```

Before mapping, you can check that OpenSTA can read the selected Liberty file:

```bash
./vlsi library check --liberty "$HOME/opt/pdk/sky130hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib"
```

This command uses the local Sky130 HD library on this host. On another system,
replace the path with the absolute path to a compatible Liberty file.

This checks parsing and reports library/cell counts and units. It does not
select a PDK or verify that its process corner matches your design. See
[`TIMING_ANALYSIS.md`](TIMING_ANALYSIS.md#select-and-validate-a-liberty-file)
for the local Sky130 example and report details.

The paths are relative to the project root. `liberty` is required for
technology mapping. `abc_constraints` and `delay_ps` are optional, but each
requires `liberty`. The equivalent command-line options are `--liberty FILE`,
`--abc-constraints FILE`, and `--delay-ps PS`.

The ABC constraints file uses Yosys ABC syntax, not SDC. It contains a driving
cell that exists in the Liberty library and an output load in femtofarads, for
example:

```text
set_driving_cell <input_driver_cell_name_from_the_library>
set_load 5.0
```

For example, with the local Sky130 HD library, use a driver cell from that
library such as `sky130_fd_sc_hd__inv_1`. Choose a cell and load appropriate to
the interface being modeled; the example is not a board-level constraint.

Replace the example cell name with a real cell from your library. `delay_ps`
passes ABC's delay target in picoseconds. The toolkit maps flip-flops with
`dfflibmap`, maps combinational logic with ABC, then writes the mapped netlist
and Liberty-based cell statistics. ABC's input/output constraints are not SDC
and do not define clocks, per-port input/output delays, or timing exceptions.
Use [`vlsi timing`](TIMING_ANALYSIS.md) with OpenSTA for a separate static timing
report from the mapped netlist and an SDC file.

When `abc_constraints` is supplied, the synthesis build directory also gets
`abc_timing_report.txt`. It contains ABC's synthesis-time delay estimate and
the paths ABC reports under the selected input-driver/output-load assumptions.
Without `abc_constraints`, ABC's default Yosys script does not emit a measured
delay; the file records that no estimate was produced. This estimate is not
pre-synthesis STA and is not a substitute for the constrained OpenSTA report.

If no `liberty` is configured, synthesis keeps using the original generic Yosys
flow. Supplying an ABC constraints file or delay target without a Liberty file
is rejected with an actionable error.
