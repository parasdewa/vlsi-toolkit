.DEFAULT_GOAL := help

VLSI ?= $(if $(wildcard ../vlsi-toolkit/vlsi),../vlsi-toolkit/vlsi,vlsi)
TOOL_SETUP ?= ../vlsi-toolkit/scripts/tool_setup_and_check.sh
DESIGN ?=
SIM ?=
SIM_NAME = $(if $(strip $(DESIGN)),$(DESIGN),directed)
SIMULATOR = $(if $(strip $(SIM)),$(SIM),verilator)

DIRECTED_CONFIG ?= $(if $(strip $(CONFIG)),$(CONFIG),$(if $(strip $(DESIGN)),config/simulation/directed/$(DESIGN).toml,config/simulation/directed/directed.toml))
UVM_CONFIG ?= $(if $(strip $(CONFIG)),$(CONFIG),$(if $(strip $(DESIGN)),config/simulation/uvm/$(DESIGN).toml,config/simulation/uvm/uvm.toml))
SYNTH_CONFIG ?= $(if $(strip $(CONFIG)),$(CONFIG),$(if $(strip $(DESIGN)),config/synthesis/$(DESIGN).toml,config/synthesis/synth.toml))
TIMING_CONFIG ?= $(if $(strip $(CONFIG)),$(CONFIG),$(if $(strip $(DESIGN)),config/timing/$(DESIGN).toml,config/timing/timing.toml))
WAVEFORM ?= $(if $(strip $(DESIGN)),build/sim/$(DESIGN)-$(SIMULATOR)/waveforms/$(DESIGN).vcd,$(if $(strip $(SIM)),build/sim/directed-$(SIM)/waveform.vcd,build/sim/plain-verilator/waveform.vcd))
UVM_WAVEFORM ?= $(if $(strip $(DESIGN)),build/sim/$(DESIGN)-uvm-verilator/waveforms/$(DESIGN)_uvm.vcd,build/sim/uvm-verilator/waveforms/my_uvm_top.vcd)
LIBERTY ?=

SIM_OPTION = $(if $(strip $(SIM)),--sim "$(SIM)",)
SIM_BUILD_OPTION = $(if $(strip $(SIM)),--build-dir "build/sim/$(SIM_NAME)-$(SIM)",)

.PHONY: help doctor setup setup-check smoke clean clean-dry-run sim run uvm synth synth-mapped timing library-check wave wave-uvm

help:
	@printf '%s\n' \
	  'Project Make targets:' \
	  '  make sim [DESIGN=name] [SIM=iverilog|verilator] [CONFIG=FILE]' \
	  '  make uvm [DESIGN=name] [CONFIG=FILE]' \
	  '  make synth [DESIGN=name] [CONFIG=FILE]' \
	  '  make synth-mapped [DESIGN=name] [CONFIG=FILE]' \
	  '  make timing [DESIGN=name] [CONFIG=FILE]' \
	  '  make wave [DESIGN=name] [WAVEFORM=FILE] | wave-uvm [DESIGN=name] [WAVEFORM=FILE]' \
	  '  make doctor | library-check LIBERTY=path/to/cells.lib' \
	  '  make setup | setup-check | smoke' \
	  '  make clean-dry-run | clean'

doctor:
	$(VLSI) doctor

setup:
	$(TOOL_SETUP)

setup-check:
	$(TOOL_SETUP) --check-only

smoke:
	$(TOOL_SETUP) --smoke-only

clean-dry-run:
	$(VLSI) clean --dry-run

clean:
	$(VLSI) clean

sim run:
	./scripts/simulation/directed/run_directed.sh "$(DIRECTED_CONFIG)" $(SIM_OPTION) $(SIM_BUILD_OPTION)

uvm:
	./scripts/simulation/uvm/run_uvm.sh "$(UVM_CONFIG)"

synth:
	./scripts/synthesis/synth.sh "$(SYNTH_CONFIG)"

synth-mapped:
	./scripts/synthesis/synth.sh "$(SYNTH_CONFIG)"

timing:
	./scripts/timing/timing.sh "$(TIMING_CONFIG)"

library-check:
	@test -n "$(LIBERTY)" || { echo 'Set LIBERTY, for example: make library-check LIBERTY=/path/to/cells.lib' >&2; exit 2; }
	$(VLSI) library check --liberty "$(LIBERTY)"

wave:
	gtkwave "$(WAVEFORM)"

wave-uvm:
	gtkwave "$(if $(strip $(WAVEFORM)),$(WAVEFORM),$(UVM_WAVEFORM))"
