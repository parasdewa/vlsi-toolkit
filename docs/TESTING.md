# Regression checks

The toolkit's regression suite uses Python's standard-library `unittest` and
does not need pip-installed dependencies. Python 3.10 also needs Ubuntu's
`python3-tomli` package for the toolkit's TOML manifests; the setup script
checks and installs it when needed.

```bash
python3 -m unittest discover -s tests/toolkit -v
```

The suite checks CLI help, project scaffolding, invalid source handling, and manifest-driven flows.
When Icarus, Verilator, or Yosys is installed, it also runs the small counter
simulation and waveform flows, and the counter plus multi-file/include synthesis
flows. It also simulates and synthesizes the synchronous FIFO example. Missing
EDA tools cause only their corresponding integration check to be skipped. When
Verilator and its UVM 2020.3.2 test package are available, the suite also uses
`vlsi run --uvm` to build and run the UVM AND-gate scoreboard test and checks
its VCD output.

Each integration run uses a temporary directory under `build/regression/` and
removes it when the check finishes. The saved example build outputs are not
overwritten. Verilator is explicitly limited to one build job. A fresh UVM
build can take several minutes; the suite allows up to ten minutes for that
check. Set `VERILATOR_UVM_DIR` if the package is not discoverable under
`VERILATOR_ROOT` or alongside the Verilator executable.
