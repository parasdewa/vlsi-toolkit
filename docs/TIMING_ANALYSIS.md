# Static timing analysis with OpenSTA

This guide explains the Liberty and SDC inputs, the synthesis-to-STA example,
the generated reports, and the limits of the current flow.

## Contents

- [Timing stages](#timing-stages)
- [Check for OpenSTA](#check-for-opensta)
- [Select and validate a Liberty file](#select-and-validate-a-liberty-file)
- [Example flow](#example-flow)
- [Limits](#limits)
- [Asynchronous reset recovery/removal](#asynchronous-reset-recoveryremoval)

## Timing stages

The toolkit provides two timing-related stages:

- `vlsi synth` uses Yosys/ABC for technology mapping. With a Liberty library
  and ABC input/output constraints, it saves ABC's synthesis-time combinational
  delay estimate separately in `abc_timing_report.txt`.
- `vlsi timing` runs OpenSTA against a mapped Verilog netlist, Liberty timing
  library, and SDC constraints. It writes a separate report containing timing
  paths, worst slack, and total negative slack.

ABC's estimate is generated during technology mapping. It is not a clocked
static-timing report, and it is not a pre-synthesis STA report. OpenSTA needs a
gate-level netlist; it cannot time RTL directly. If you already have a
pre-synthesis gate-level netlist, `vlsi timing` can analyze it with the same
explicit Liberty and SDC inputs, and can then analyze the synthesized netlist
for comparison, writing each result to a different build directory. Without
SPEF, interconnect parasitics are not extracted; pass `spef` after routing to
include extracted parasitics.

## Check for OpenSTA

Run:

```bash
./vlsi doctor
```

The doctor checks for the OpenSTA executable named `sta`. If it is missing,
the default `scripts/tool_setup_and_check.sh` installs its Ubuntu build
dependencies and builds pinned OpenSTA/CUDD sources under `~/opt/opensta` with
one build job. It also runs a constrained timing smoke check against a tiny
synthetic Liberty fixture. This confirms the tool works; it does not install
or validate a target PDK/library. `--check-only` remains read-only, while
`--smoke-only` expects OpenSTA to already be available.

The setup creates `~/opt/opensta/opensta-env.sh` to add `sta` to `PATH` and
adds a guarded, idempotent source line to `~/.bashrc` for future interactive
Bash shells. Source it in the current shell with
`source ~/opt/opensta/opensta-env.sh`.

## Select and validate a Liberty file

The toolkit does not choose or download a PDK. Select a Liberty file that
matches the target process, cell family, and operating corner, then ask
OpenSTA to parse it. On this host, use the installed Sky130 HD typical-corner
library:

```bash
source "$HOME/opt/opensta/opensta-env.sh"
export LIBERTY="$HOME/opt/pdk/sky130hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib"
./vlsi library check --liberty "$LIBERTY"
```

The command reports parsed library names, library count, cell count, and time
units. It saves `liberty_check.tcl` and `liberty_check.log` under
`build/liberty_check/<file-name>/` by default. Pass `--build-dir DIR` to choose
another output location. A successful parse confirms Liberty syntax and
readability; it does not prove that the library is the correct process/corner
for a design or that its cells match a synthesized netlist.

`$LIBERTY` is an external local installation, not bundled in the toolkit
repository. On another system, set it to the absolute path of a compatible
Liberty file before running the validation, synthesis, and timing commands.

## Example flow

The example counter project includes [`timing.sdc`](../tests/rtl/counter/timing.sdc).
Set `LIBERTY` to a technology-compatible standard-cell timing library and run
synthesis and timing analysis into isolated build directories:

```bash
LIBERTY=/path/to/sky130_fd_sc_hd__tt_025C_1v80.lib
ABC_CONSTRAINTS=/path/to/abc.constr

./vlsi synth \
  --project tests/rtl/counter \
  --top counter \
  --rtl counter.sv \
  --liberty "$LIBERTY" \
  --abc-constraints "$ABC_CONSTRAINTS" \
  --delay-ps 10000 \
  --build-dir /tmp/counter-synth

./vlsi timing \
  --project tests/rtl/counter \
  --top counter \
  --netlist /tmp/counter-synth/netlist.v \
  --liberty "$LIBERTY" \
  --sdc timing.sdc \
  --build-dir /tmp/counter-timing
```

`$ABC_CONSTRAINTS` should point to a file defining a driver cell from the
selected Liberty and an output load in femtofarads. `--abc-constraints FILE`
provides ABC's input-driver and output-load assumptions and produces its
separate delay estimate. That file is ABC-specific, not SDC. OpenSTA uses the
SDC file for clocks, I/O delays, and timing exceptions.

The timing output directory contains:

- `timing_report.txt`: max and min timing paths, units, worst slack, and TNS
- `setup_check.txt`: OpenSTA setup/constraint diagnostics
- `timing.tcl`: generated OpenSTA commands
- `timing.log`: full OpenSTA output

`vlsi timing` prints `TIMING_STATUS PASS` when max and min worst slack are
nonnegative. Negative slack produces `TIMING_STATUS FAIL` and a nonzero exit
status, while keeping all reports in the build directory. If OpenSTA does not
provide both slack summaries, the status is `UNKNOWN` and the command returns
nonzero.

For a project manifest, add:

```toml
[timing]
top = "counter"
netlist = "/tmp/counter-synth/netlist.v"
liberty = "/path/to/standard_cells.lib"
sdc = "timing.sdc"
# Optional extracted parasitics:
# spef = "counter.spef"
build_dir = "/tmp/counter-timing"
```

Then run `./vlsi timing --config path/to/vlsi.toml`. Paths in the `timing`
table are resolved from `[project].root`, except absolute paths, which are used
as given.

## Limits

The toolkit does not download or bundle PDK libraries. The netlist and Liberty
library must use compatible cell names and models. Use a platform's cell
exclusion guidance for synthesis; unrestricted mapping may select specialized
cells, such as low-power isolation cells. Post-synthesis STA without SPEF is an
estimate and does not include routed wire parasitics.

## Asynchronous reset recovery/removal

The counter example treats its asynchronous reset as out-of-band and its SDC
uses `set_false_path -from [get_ports reset_n]`. That intentionally suppresses
reset timing checks, so its normal timing report does not sign off recovery or
removal.

OpenSTA can check these arcs when the selected Liberty models them and reset
release is constrained. For a real design, remove the reset false path and
constrain the deasserting edge with characterized minimum and maximum arrival
delays relative to the destination clock. Keep asynchronous assertion and
synchronized deassertion behavior consistent with the design and platform.
Do not copy arbitrary example delays into signoff constraints.

I confirmed that the installed Sky130 HD `dfrtp` cells contain recovery and
removal arcs. In an isolated run with the false path removed, OpenSTA reported
both check types and correctly returned `TIMING_STATUS FAIL` for a deliberately
inadequate reset-release assumption. This demonstrates the check path; it is
not a timing result for the example design or a reset signoff constraint.
