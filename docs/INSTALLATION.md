# Installation and tool setup

Use the setup script for a checked Ubuntu/WSL installation, or follow the
manual package instructions when you want to manage the tools yourself.

## Contents

- [Supported environment](#supported-environment)
- [Automated Ubuntu setup](#automated-ubuntu-setup)
- [Manual tool setup](#manual-tool-setup)

## Supported environment

The toolkit runs on Ubuntu 22.04, 24.04, or 26.04, including Ubuntu under WSL. It
requires Python 3.10 or newer for the `vlsi` command. Python 3.10 also needs the
Ubuntu `python3-tomli` package for TOML manifests. The RTL flows use Icarus
Verilog, Verilator, and Yosys; GTKWave is used to view waveforms. OpenSTA is
required for `vlsi timing` and is built by default setup if no usable `sta` is
found. Git, `tree`, GNU make, and a C++ compiler are also used by setup and
Verilator workflows.

## Automated Ubuntu setup

From the repository root, run:

```bash
scripts/tool_setup_and_check.sh
```

The installer checks for `git`, `tree`, `iverilog`/`vvp`, `gtkwave`, `yosys`,
`make`, `g++`, and the Verilator/OpenSTA build prerequisites. It runs
`apt-get update`
and installs only packages whose required executable is missing. If a package
is already present and usable, it is left alone. It requires Verilator 5.052
or newer, the version verified for this project's UVM 2020.3.2 test.

If no usable Verilator is found, the setup clones the pinned Verilator v5.052
source and builds it with one job under `~/opt/verilator-5.052`. This does not
overwrite an existing system or custom Verilator. If its UVM test package is
not already available, it fetches the matching source checkout under
`~/opt/vlsi-toolkit/`. It writes `~/opt/vlsi-toolkit/verilator-env.sh`; source
that file in future shells to select the isolated tool and UVM package.

The default run uses `sudo` to install missing Ubuntu packages, builds pinned
OpenSTA/CUDD sources under `~/opt/opensta` if needed, and runs RTL, UVM, Yosys,
and a small OpenSTA timing smoke check. The OpenSTA smoke uses a synthetic
Liberty fixture and does not install or validate a PDK. Verilator and OpenSTA
compilation are limited to one job. Build products and logs are written under
`build/tool_setup/`.
Package-manager and Verilator build output is saved to
`build/tool_setup/logs/tool_setup_install.log`.

For a read-only check, use:

```bash
scripts/tool_setup_and_check.sh --check-only
```

To compile and run the smoke tests without attempting package installation:

```bash
scripts/tool_setup_and_check.sh --smoke-only
```

The UVM test uses Verilator's UVM 2020.3.2 test package. If that package is
outside `VERILATOR_ROOT/test_regress/t/uvm`, point the scripts at its directory:

```bash
export VERILATOR_UVM_DIR=/path/to/verilator/test_regress/t/uvm
scripts/tool_setup_and_check.sh --check-only
scripts/tool_setup_and_check.sh --smoke-only
```

The directory must contain `uvm_pkg_all_v2020_3_2_nodpi.svh`. In default
install mode, if a supported Verilator or matching UVM package is unavailable,
the setup fetches the pinned Verilator v5.052 source as needed and builds the
isolated tool with one job. It does not replace an existing supported
installation. `--check-only` never fetches or builds tools; `--smoke-only`
expects OpenSTA to be available.

If a check reports missing apt packages, it prints a ready-to-run
`sudo apt-get update && sudo apt-get install ...` command. You can also rerun
the default setup command to install only missing packages and then repeat the
checks and smoke tests. For failure-specific guidance, see
[Tool setup troubleshooting](TROUBLESHOOTING.md).

`./vlsi doctor` checks for OpenSTA (`sta`) and points to the timing setup guide
if it is missing. Setup installs it under `~/opt/opensta`; the helper
`~/opt/opensta/opensta-env.sh` adds it to `PATH`, and setup adds an idempotent
source line to `~/.bashrc` for future interactive Bash shells. Source the
helper in the current shell with `source ~/opt/opensta/opensta-env.sh`. See
[Timing analysis](TIMING_ANALYSIS.md) for the `vlsi timing` workflow.
The toolkit does not install a PDK. Validate a library you selected with
`./vlsi library check --liberty "$HOME/opt/pdk/sky130hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib"`
before using it on this host. On another system, replace that path with the
absolute path to a compatible Liberty library.

GTKWave availability is checked by executable path. The setup script does not
launch a GUI. In WSL, GTKWave needs WSLg or an X server.

## Manual tool setup

On Ubuntu, install the common package set with:

```bash
sudo apt-get update
sudo apt-get install git tree python3 iverilog gtkwave yosys build-essential flex bison autoconf help2man
```

Confirm `python3 --version` reports 3.10 or newer. On Python 3.10, also install
`python3-tomli`. Then check tools and run the
compile suite. Use the automated setup for the supported Verilator/UVM build;
the Ubuntu package may be older than the toolkit's UVM minimum:

```bash
./vlsi doctor
scripts/diagnose.sh
VERILATOR_UVM_DIR=/path/to/verilator/test_regress/t/uvm \
  scripts/run_all_smoke_tests.sh
```

For steps to create a new project and run it, see
[Create and run a project](NEW_PROJECT.md).
