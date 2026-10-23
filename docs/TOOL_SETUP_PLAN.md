# Tool setup completion plan

This plan completes the RTL/UVM tool setup before starting a laptop setup guide
or a new SoC project. Git initialization and GitHub setup are explicitly left
until the end.

## Current audit

- Icarus Verilog 12.0, `vvp`, Verilator 5.052, Yosys 0.33, GTKWave, `git`, and
  `tree` are present in this WSL environment.
- The toolkit's Icarus and Verilator runners pass counter and FIFO checks.
  Yosys synthesis passes for the counter, FIFO, and multi-file AND-gate design.
- A prebuilt Verilator/UVM AND-gate test runs to completion and reports
  `AND_GATE_UVM_SCOREBOARD_PASSED`, four checked transactions, zero scoreboard
  errors, and zero UVM errors/fatals. It emits two no-DPI/name-check warnings.
  The UVM RTL/testbench source copies in this toolkit match the sources used to
  build that executable.
- The old prebuilt UVM executable was built without trace support, but the new
  scripted build enables trace and generates a VCD successfully.
- Compile scripts, the aggregate runner, setup entry point, diagnostics,
  troubleshooting guide, version configuration, and setup documentation are
  implemented. See the phase statuses below for validation results.
- The Python regression suite now includes a Verilator/UVM AND-gate build and
  scoreboard check when Verilator and the matching UVM source are available.
  It directs generated files to a temporary build directory under
  `build/regression/`.

## Simulator and waveform decision

Use both simulators for their strengths:

- Icarus is the fast baseline for small, portable synthesizable RTL
  testbenches. Its SystemVerilog implementation is still an evolving subset,
  so it is not the toolkit's UVM backend.
- Verilator is the UVM-capable simulator for this project. The installed 5.052
  release supports UVM 2020.3.2, with documented remaining limitations. Keep
  build parallelism at one job by default in WSL.
- Both produce VCD files that GTKWave can open. For toolkit projects:

  ```bash
  gtkwave build/counter/counter_tb/waveform.vcd
  ```

  The toolkit's `--waveform` and `--waveform-file` options enable trace support
  for Verilator. The UVM compile script must also pass Verilator's trace option;
  otherwise the UVM top's `$dumpvars` is ignored. GTKWave is installed, but its
  GUI has not been launched in this session. In WSL, graphical display depends
  on WSLg or an X server.

## Implementation sequence

### 1. Reproducible project compile scripts

**Status: complete and verified.** `scripts/compile_iverilog.sh`,
`scripts/compile_verilator.sh`, `scripts/compile_uvm.sh`, and
`scripts/run_all_smoke_tests.sh` build in separate `build/tool_setup/`
directories. The UVM script accepts `VERILATOR_UVM_DIR`; on the current host
the source is at `/home/parasdewa/projects/verilator-latest/test_regress/t/uvm`.
The complete aggregate run passed all seven simulator/project combinations,
and verified non-empty Icarus counter, Verilator counter, and UVM VCD files.
The first UVM C++ compilation took about five minutes with one build job.

The completed scripts cover the projects exercised so far:

- Counter RTL/testbench
- AND-gate RTL/testbench
- Synchronous FIFO RTL/testbench
- AND-gate UVM testbench using Verilator and UVM 2020.3.2

Scripts will resolve the repository root from their own location, use separate
`build/tool_setup/` output directories, retain command logs, and use one
Verilator build job. The UVM script will discover or accept the UVM library
location explicitly and fail with a direct setup instruction if it cannot find
the expected UVM 2020.3.2 source.

**Done when:** a clean invocation compiles and runs every listed test, prints a
pass sentinel for each, and preserves existing example build directories.

### 2. Modular Ubuntu installer and checker

**Status: implemented and passed in the user's Ubuntu 24.04.5 WSL session.**
The modular entry point and helpers are in `scripts/tool_setup_and_check.sh`
and `scripts/lib/`. The full run detected all tools, including Snap `tree`,
preserved the existing Verilator 5.052 installation, found the UVM 2020.3.2
source, and completed the RTL, UVM, Yosys, and waveform smoke checks. Since all
required Ubuntu packages were already present, apt was not run. The Verilator
source build path remains pinned to v5.052, isolated under `~/opt`, and
limited to one job; that installation path was not needed in this run.

The entry point uses separate helpers for OS/root checks, package
detection/installation, Verilator UVM setup, tool verification, smoke tests,
and failure guidance. It:

- Support Ubuntu/WSL Ubuntu and stop with a clear message on unsupported OSes.
- Check each executable/package before attempting installation and install only
  missing packages.
- Install Git, `tree`, Icarus/`vvp`, GTKWave, Yosys, and the prerequisites for
  Verilator. It will check Verilator's UVM-capable version and preserve existing
  custom installations; an older system package will not silently replace the
  known-good local tool.
- Provide `--check-only` and `--smoke-only` modes so users can diagnose or
  validate an existing setup without running package installation.
- Use bounded Verilator jobs and report where logs and generated smoke-test
  outputs were written.

**Done when:** the installer is idempotent, reports all tools present on a
second run, and does not modify or replace a detected working installation.

### 3. Tool smoke tests and actionable diagnostics

**Status: implemented and passed through the full setup entry point.** The setup smoke helper runs
the Icarus, Verilator, and UVM compile scripts; synthesizes the counter with
Yosys; and checks the Icarus/Verilator/UVM VCD files. Failure messages point
to the relevant tool, trace, source, or log location. The full setup run passed
against the current toolchain. GTKWave executable availability was checked;
opening the GUI remains dependent on the WSL display environment and was not
part of this run.

The implemented checks cover tool detection, Icarus and Verilator simulation,
VCD creation, GTKWave executable availability, Yosys synthesis, and the UVM
AND-gate scoreboard. The UVM check compiles in its own build directory with
trace enabled, runs one test, and verifies the scoreboard pass sentinel and
zero UVM errors/fatals. Diagnostics map common failures to an action, such as
a missing compiler, unsupported Verilator version, missing UVM source, failed
compile, missing VCD, or unavailable graphical display.

**Done when:** every smoke check has a clear pass/fail result and a failed check
prints a relevant next command or documentation section.

### 4. Setup documentation and environment report

**Status: complete.** The installation guide, setup verification report, and
troubleshooting guide are populated with supported Ubuntu releases, install
and check commands, WSL notes, actual test results, and current limitations.

Complete the installation guide with supported Ubuntu versions, prerequisites,
exact installer commands, optional manual setup, WSL notes, and what the
installer changes. Populate the setup verification report with actual tool
versions and smoke-test results. Populate troubleshooting with the diagnostics
implemented in phase 3. Document both simulator commands and GTKWave opening
commands, including the UVM trace requirement.

**Done when:** a new user can follow the setup page from a clean Ubuntu/WSL
environment, run the installer, confirm every smoke test, and resolve the
documented common failures without relying on this chat.

### 5. Final end-to-end review

Run the setup checker in check-only mode, run the complete compile/smoke suite,
confirm output/log locations and memory limits, and reconcile the docs with the
observed results. Only after this tool setup work is complete should Git and
GitHub setup be started.

## External tool references

- Icarus documents its SystemVerilog support as ongoing in its
  [command-line reference](https://steveicarus.github.io/iverilog/usage/command_line_flags.html).
- Verilator 5.052 adds support for UVM 2020.3.2 in its
  [release notes](https://verilator.org/guide/latest/changes.html?page=1). Its
  [UVM tracking issue](https://github.com/verilator/verilator/issues/1538)
  records remaining limitations.
- GTKWave accepts VCD files from both simulators; see its
  [command reference](https://gtkwave.github.io/gtkwave/man/gtkwave.1.html).
