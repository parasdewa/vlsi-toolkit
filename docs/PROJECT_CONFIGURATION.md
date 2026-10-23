# Project configuration

`vlsi run` and `vlsi synth` accept `--config FILE` for a TOML project manifest.
The manifest's paths are resolved from `[project].root`, which is relative to
the manifest file. If `[project].root` is omitted, the manifest directory is
the project root.

```toml
[project]
root = "."

[run]
sim = "verilator"
uvm = false
top = "counter_tb"
rtl = ["counter.sv"]
tb = ["counter_tb.sv"]
include = []
defines = []
sim_args = []
waveform = false
jobs = 1

[synth]
top = "counter"
rtl = ["counter.sv"]
include = []
defines = []
```

Run either configured workflow with:

```bash
./vlsi run --config path/to/vlsi.toml
./vlsi synth --config path/to/vlsi.toml
```

The selected command requires its matching table (`[run]` or `[synth]`). RTL
and testbench files, include directories, and defines are arrays of strings.
`[run].sim` accepts `iverilog` or `verilator` and defaults to `verilator` when
omitted; use `--sim iverilog` to select Icarus from the command line.
`[run].jobs` accepts `1` or `2`.
Set `[run].uvm = true` to compile with Verilator's UVM 2020.3.2 package; this
requires `[run].sim = "verilator"`. `[run].uvm_dir` can specify the package
directory when it cannot be found through `VERILATOR_UVM_DIR` or
`VERILATOR_ROOT`.
`[run].waveform` is a boolean. `[run].waveform_file` may specify a custom VCD
path and enables waveform generation; relative paths are resolved from the
selected build directory. `build_dir` may be set in either table; a relative
value is resolved from the project root. Unspecified build directories use the
normal toolkit defaults.

Pass CLI options to override manifest values. Repeated CLI list options replace
the manifest list for that field. `--project` overrides the configured project
root, and relative RTL/include paths then resolve from the override. Use
`--no-waveform` to disable a manifest's waveform setting.

The included examples are `tests/rtl/counter/vlsi.toml` and
`tests/rtl/and_gate_synthesis/vlsi.toml`.
