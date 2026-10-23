# Waveforms

Pass `--waveform` to `vlsi run` to generate a VCD file at
`<build-dir>/waveform.vcd`. Both Icarus and Verilator support this option; the
runner enables VCD tracing for Verilator and passes the output path to the
simulation as `+VLSI_WAVEFORM=<path>`.

Choose another location with `--waveform-file FILE`. This option also enables
waveform generation. Relative paths are resolved from the selected build
directory, and parent directories are created automatically. The command
returns an error if the testbench exits successfully without creating the
requested VCD. Use `--no-waveform` to turn off waveform generation configured
in a manifest.

The testbench must include a conditional dump block. This keeps waveform
generation optional and avoids changing normal simulation runs:

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

The included counter testbench has this hook. For example:

```bash
./vlsi run --sim iverilog --waveform \
  --project tests/rtl/counter --top counter_tb \
  --rtl counter.sv --tb counter_tb.sv

gtkwave build/counter/counter_tb/waveform.vcd
```

For a custom location under the build directory, use:

```bash
./vlsi run --sim iverilog --waveform-file traces/counter.vcd \
  --project tests/rtl/counter --top counter_tb \
  --rtl counter.sv --tb counter_tb.sv
```

Use `--build-dir DIR` if you want to retain waveforms from multiple runs in
separate locations. The runner-generated default remains
`<build-dir>/waveform.vcd`.
