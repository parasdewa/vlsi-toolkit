# RTL examples

The toolkit includes a parameterized synchronous FIFO in
`tests/rtl/sync_fifo/`. Its manifest can run the self-checking testbench or
synthesize the RTL:

```bash
./vlsi run --config tests/rtl/sync_fifo/vlsi.toml
./vlsi run --config tests/rtl/sync_fifo/vlsi.toml --sim verilator --jobs 1
./vlsi synth --config tests/rtl/sync_fifo/vlsi.toml
```

The testbench checks reset flags, FIFO ordering, full and empty transitions,
overflow and underflow rejection, simultaneous push/pop while partially full,
and pointer wraparound.

After the directed checks, a pseudo-random sequence runs against a software
queue model. By default it performs 200 cycles with seed `1ACE_B00C`. It checks
flags and queue head data on every cycle, drains the model at the end, and
requires the run to exercise simultaneous transfers, rejected pushes, and
rejected pops. Failures are reproducible because the default seed is fixed.

Override the seed and cycle count with simulator plusargs:

```bash
./vlsi run --config tests/rtl/sync_fifo/vlsi.toml \
  --sim-arg +FIFO_SEED=D00DFEED \
  --sim-arg +FIFO_CYCLES=1000
```

The seed is a nonzero 32-bit hexadecimal value and the cycle count must be
positive. Runs also need enough cycles to hit the required randomized operation
coverage. The test prints the seed, final LFSR state, and operation coverage
counts.

The FIFO accepts a push only when it is not full and accepts a pop only when it
is not empty. When both are asserted at an intermediate occupancy, both
operations complete and occupancy stays constant. At full, a simultaneous
push/pop accepts the pop and rejects the push; at empty it accepts the push and
rejects the pop. `data_out` is the current read slot and is meaningful when
`empty` is low. Reset clears pointers and occupancy; storage contents are not
reset.

Yosys maps the small storage array to generic registers in this flow. The
resulting cell count is for logic validation only; no target memory macro or
standard-cell library is selected.
