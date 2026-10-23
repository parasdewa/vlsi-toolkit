# Synthesis with Yosys

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

This is a generic logic synthesis flow. It does not apply a target cell library,
timing constraints, or technology-specific mapping; the reported cells and
statistics are not area or timing estimates for a physical implementation.
