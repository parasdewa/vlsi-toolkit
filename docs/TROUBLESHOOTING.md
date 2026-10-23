# Tool setup troubleshooting

Use these checks to narrow down setup, simulator, UVM, synthesis, and waveform
failures. Start with the non-installing checks below.

## Contents

- [First checks](#first-checks)
- [Remove generated outputs](#remove-generated-outputs)
- [A tool is missing or cannot run](#a-tool-is-missing-or-cannot-run)
- [Verilator version or UVM source is missing](#verilator-version-or-uvm-source-is-missing)
- [A compile or simulation smoke test fails](#a-compile-or-simulation-smoke-test-fails)

## First checks

Start with the non-installing checks:

```bash
scripts/tool_setup_and_check.sh --check-only
scripts/diagnose.sh
```

## Remove generated outputs

`vlsi clean` targets the current working directory. Run it from the RTL project
whose outputs you want to remove, or pass that project with `--project`:

```bash
../vlsi-toolkit/vlsi clean --dry-run
../vlsi-toolkit/vlsi clean
```

From the toolkit root, for example, target the sibling demo explicitly:

```bash
./vlsi clean --project ../vlsi-toolkit-demo-rtl --dry-run
./vlsi clean --project ../vlsi-toolkit-demo-rtl
```

The command removes only `build/`, `logs/`, and `log/` under the selected
project root. It does not remove custom build directories configured elsewhere
or selected with `--build-dir` outside those directories.

The setup scripts print a suggested resolution when a check fails. The apt
install and Verilator build log is
`build/tool_setup/logs/tool_setup_install.log`; simulator and synthesis logs
are kept beside their build outputs under `build/tool_setup/`.

## A tool is missing or cannot run

Run `scripts/tool_setup_and_check.sh` on Ubuntu 22.04, 24.04, or 26.04. It
installs only packages with missing or unusable executables. If apt fails,
check network access and sudo rights, then read the install log. A Snap binary
can be present on `PATH` but unusable in a restricted environment; the setup
checker treats `tree` as missing if `tree --version` cannot run, so the apt
package can provide the normal Ubuntu executable.

The toolkit CLI needs Python 3.10 or newer. Python 3.10 also needs the Ubuntu
`python3-tomli` package for TOML parsing; rerun `scripts/tool_setup_and_check.sh`
to install it if missing. Check `python3 --version` and, on a system with
multiple interpreters, make sure `python3` selects the supported version before
invoking `./vlsi`.

If `./vlsi doctor` reports `sta` missing, run `scripts/tool_setup_and_check.sh`
to install its build dependencies and build pinned OpenSTA/CUDD sources. The
installer log is `build/tool_setup/logs/tool_setup_install.log`. If setup has
already installed OpenSTA but the current shell cannot find it, run
`source ~/opt/opensta/opensta-env.sh`. For a failed timing smoke check, inspect
the newest `build/tool_setup/opensta/smoke.*/run.log` and its `build/timing.log`.

## Verilator version or UVM source is missing

The verified UVM flow requires Verilator 5.052 or newer and the UVM 2020.3.2
test package. The installer preserves a working custom Verilator. When it
needs a newer tool, it builds pinned Verilator v5.052 under `~/opt` with one
job and stores source/build output separately. For a future shell, source the
environment file it creates:

```bash
source ~/opt/vlsi-toolkit/verilator-env.sh
```

If you already have a source checkout, point to its UVM package directory:

```bash
export VERILATOR_UVM_DIR=/path/to/verilator/test_regress/t/uvm
scripts/tool_setup_and_check.sh --check-only
```

That directory must contain `uvm_pkg_all_v2020_3_2_nodpi.svh`, and the file
must identify UVM 2020.3.2. The default installer can fetch the pinned matching
Verilator source when the package is not found; check-only mode never fetches
or installs anything.

## A compile or simulation smoke test fails

Read the per-project log named in the failed step. Run just the relevant
compile script after fixing the reported issue:

```bash
scripts/compile_iverilog.sh
scripts/compile_verilator.sh
scripts/compile_uvm.sh
```

The UVM script needs `VERILATOR_UVM_DIR` if it is not available under
`VERILATOR_ROOT`. It checks for the four-transaction scoreboard sentinel,
zero UVM errors/fatals, and the UVM waveform. Two no-DPI/name-check warnings
are expected with this Verilator UVM package.

If a counter VCD is missing, confirm the compile command enabled waveform
tracing and the testbench has the `VLSI_WAVEFORM` dump hook. UVM uses its own
`$dumpvars`; `scripts/compile_uvm.sh` must pass Verilator `--trace`.

The smoke check confirms the GTKWave executable and VCD contents, but it does
not launch the GUI. If `gtkwave <file.vcd>` cannot display a window in WSL,
check WSLg or the X server before investigating the VCD itself.

If Yosys fails, inspect
`build/tool_setup/yosys/counter/synth.log`. The smoke test expects both
`netlist.json` and `netlist.v` from the configured counter synthesis.
