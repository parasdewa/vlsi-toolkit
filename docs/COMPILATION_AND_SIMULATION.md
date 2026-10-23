# Compile and simulate a project

The first runner uses Icarus Verilog and requires no Python packages beyond the
standard library.

```bash
./vlsi run \
  --sim iverilog \
  --project /path/to/project \
  --top my_testbench \
  --rtl rtl/design.sv \
  --tb tb/my_testbench.sv
```

`--project` sets the working directory. Relative source and include paths are
resolved from it. Repeat `--rtl` and `--tb` for more source files. Optional
arguments include:

- `--include DIR` for a SystemVerilog include directory
- `--define NAME[=VALUE]` for a preprocessor definition
- `--sim-arg ARG` to pass an argument to the simulator executable
- `--waveform` to enable VCD dumping when the testbench has the waveform hook
- `--build-dir DIR` to choose where build products and logs go

The default build directory is `build/<project-name>/<top>`. The runner stores
the compiled `.vvp` executable plus `compile.log` and `run.log` there. It uses
argument arrays rather than a shell, so paths containing spaces are supported.

For example, run the included counter project with:

```bash
./vlsi run --sim iverilog \
  --project tests/rtl/counter \
  --top counter_tb \
  --rtl counter.sv \
  --tb counter_tb.sv
```

## Verilator

Use the same project and source options with `--sim verilator`:

```bash
./vlsi run --sim verilator --jobs 1 \
  --project tests/rtl/counter \
  --top counter_tb \
  --rtl counter.sv \
  --tb counter_tb.sv
```

Verilator builds a native executable in `build/<project-name>/<top>/obj_dir`
and runs it. `--jobs` accepts `1` or `2` and defaults to `1` to keep memory use
predictable. Both compile and simulation output are saved in `compile.log` and
`run.log`.

To save a waveform, add `--waveform` to either simulator command. The testbench
must conditionally call `$dumpfile` and `$dumpvars` when `VLSI_WAVEFORM` is
defined. The runner passes the output path as the `+VLSI_WAVEFORM=<path>`
plusarg and writes the VCD to the selected build directory:

```systemverilog
`ifdef VLSI_WAVEFORM
    string waveform_file;
    initial begin
        if (!$value$plusargs("VLSI_WAVEFORM=%s", waveform_file))
            waveform_file = "waveform.vcd";
        $dumpfile(waveform_file);
        $dumpvars(0, my_testbench);
    end
`endif
```

Verilator's waveform option enables VCD tracing during compilation. Open the
result with GTKWave, for example `gtkwave build/counter/counter_tb/waveform.vcd`.

## Run UVM with the CLI

UVM is enabled as a Verilator run option. For the included AND-gate UVM
project:

```bash
export VERILATOR_UVM_DIR=/path/to/verilator/test_regress/t/uvm
./vlsi run --sim verilator --uvm --jobs 1 \
  --project tests/uvm/and_gate \
  --top and_gate_tb_top \
  --rtl rtl/and_gate.sv \
  --tb tb/and_gate_if.sv \
  --tb tb/and_gate_pkg.sv \
  --tb tb/and_gate_tb_top.sv \
  --include tb
```

The CLI adds the UVM 2020.3.2 package during compilation, enables trace, and
runs the built test. It returns a failure if the UVM report summary contains
non-zero error or fatal counts. Relative files written by the testbench are
placed under the selected build directory. The included test writes
`build/and_gate_uvm.vcd`, so its waveform is at
`build/and_gate/and_gate_tb_top/build/and_gate_uvm.vcd` with the default build
location. The UVM package directory can also be supplied with
`--uvm-dir DIR` or in `[run].uvm_dir` in a manifest. Verilator 5.052 or newer
is required. See [Create and run a project](NEW_PROJECT.md) for a manifest
example.

## Compile the toolkit smoke examples

The compile scripts build and run the counter, AND gate, and synchronous FIFO
with both simulators, then build and run the AND-gate UVM test with Verilator:

```bash
scripts/compile_iverilog.sh
scripts/compile_verilator.sh
scripts/compile_uvm.sh
```

To run all of them in sequence, use:

```bash
VERILATOR_UVM_DIR=/path/to/verilator/test_regress/t/uvm scripts/run_all_smoke_tests.sh
```

The UVM directory must contain
`uvm_pkg_all_v2020_3_2_nodpi.svh`. Set `VERILATOR_UVM_DIR` when that test
source is not under `VERILATOR_ROOT/test_regress/t/uvm`. The UVM script enables
trace and verifies the scoreboard sentinel, four checked transactions, zero
UVM errors/fatals, and a non-empty VCD. Its VCD is written under
`build/tool_setup/uvm/run/build/and_gate_uvm.vcd`.

The compile scripts are retained as smoke-test entry points. Use
`vlsi run --uvm` to run UVM projects through the normal CLI. Smoke outputs are under
`build/tool_setup/`, separate from normal CLI build directories. The first UVM
C++ build can take several minutes even with one job.
