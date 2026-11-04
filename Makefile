SHELL := /bin/bash
.DEFAULT_GOAL := help

VLSI ?= ./vlsi
CONFIG ?=
DESIGN ?=
SIM ?=
PROJECT ?=
LIBERTY ?=
SIM_CONFIG ?= $(if $(strip $(CONFIG)),$(CONFIG),$(if $(strip $(DESIGN)),tests/rtl/$(DESIGN)/vlsi.toml,tests/rtl/counter/vlsi.toml))
UVM_CONFIG ?= $(if $(strip $(CONFIG)),$(CONFIG),$(if $(strip $(DESIGN)),tests/uvm/$(DESIGN)/vlsi.toml,tests/uvm/and_gate/vlsi.toml))
SYNTH_CONFIG ?= $(if $(strip $(CONFIG)),$(CONFIG),$(if $(strip $(DESIGN)),tests/rtl/$(DESIGN)/vlsi.toml,tests/rtl/counter/vlsi.toml))
TIMING_CONFIG ?= $(if $(strip $(CONFIG)),$(CONFIG),$(if $(strip $(DESIGN)),tests/rtl/$(DESIGN)/vlsi_sky130_timing.toml,tests/rtl/counter/vlsi_sky130_timing.toml))
SIM_DESIGN = $(if $(strip $(DESIGN)),$(DESIGN),counter)
UVM_DESIGN = $(if $(strip $(DESIGN)),$(DESIGN),and_gate)
SIM_WAVEFORM ?= $(if $(filter counter,$(SIM_DESIGN)),build/counter/counter_tb/waveforms/config_counter.vcd,)
UVM_WAVEFORM ?= $(if $(filter and_gate,$(UVM_DESIGN)),build/uvm-and-gate/build/and_gate_uvm.vcd,build/uvm-$(UVM_DESIGN)/build/$(UVM_DESIGN)_uvm.vcd)
WAVEFORM ?=

SIM_OPTION = $(if $(strip $(SIM)),--sim "$(SIM)",)

.PHONY: help doctor setup setup-check smoke clean clean-dry-run init sim run uvm synth synth-mapped timing library-check wave wave-uvm

help:
	@printf '%s\n' \
	  'VLSI Toolkit Make targets:' \
	  '  make doctor                         Check installed tools' \
	  '  make setup-check                    Check setup without installing' \
	  '  make smoke                          Run setup smoke checks' \
	  '  make setup                          Run the full tool setup script' \
	  '  make sim [DESIGN=counter|sync_fifo|and_gate] [SIM=TOOL] [CONFIG=FILE]' \
	  '  make uvm [DESIGN=and_gate] [CONFIG=FILE]' \
	  '  make synth [DESIGN=counter|sync_fifo|and_gate_synthesis] [CONFIG=FILE]' \
	  '  make synth-mapped [DESIGN=counter] [CONFIG=FILE]' \
	  '  make timing [DESIGN=counter] [CONFIG=FILE]' \
	  '  make library-check LIBERTY=FILE     Validate a Liberty file' \
	  '  make wave [DESIGN=counter] [WAVEFORM=FILE]' \
	  '  make wave-uvm [DESIGN=and_gate] [WAVEFORM=FILE]' \
	  '  make init PROJECT=PATH              Create a project scaffold' \
	  '  make clean-dry-run | clean           Preview or remove toolkit outputs'

doctor:
	$(VLSI) doctor

setup:
	./scripts/tool_setup_and_check.sh

setup-check:
	./scripts/tool_setup_and_check.sh --check-only

smoke:
	./scripts/tool_setup_and_check.sh --smoke-only

clean-dry-run:
	$(VLSI) clean --dry-run

clean:
	$(VLSI) clean

init:
	@test -n "$(PROJECT)" || { echo 'Set PROJECT, for example: make init PROJECT=../my_rtl_project' >&2; exit 2; }
	$(VLSI) init "$(PROJECT)"

sim run:
	$(VLSI) run --config "$(SIM_CONFIG)" $(SIM_OPTION)

uvm:
	$(VLSI) run --config "$(UVM_CONFIG)" $(SIM_OPTION)

synth:
	$(VLSI) synth --config "$(SYNTH_CONFIG)"

synth-mapped:
	$(VLSI) synth --config "$(TIMING_CONFIG)"

timing:
	$(VLSI) timing --config "$(TIMING_CONFIG)"

library-check:
	@test -n "$(LIBERTY)" || { echo 'Set LIBERTY, for example: make library-check LIBERTY=/path/to/cells.lib' >&2; exit 2; }
	$(VLSI) library check --liberty "$(LIBERTY)"

wave:
	@test -n "$(if $(strip $(WAVEFORM)),$(WAVEFORM),$(SIM_WAVEFORM))" || { echo 'This fixture has no default waveform path; set WAVEFORM=path/to/file.vcd' >&2; exit 2; }
	gtkwave "$(if $(strip $(WAVEFORM)),$(WAVEFORM),$(SIM_WAVEFORM))"

wave-uvm:
	gtkwave "$(if $(strip $(WAVEFORM)),$(WAVEFORM),$(UVM_WAVEFORM))"
