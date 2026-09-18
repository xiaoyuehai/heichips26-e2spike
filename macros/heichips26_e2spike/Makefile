# SPDX-FileCopyrightText: 2026 The HeiChips Contributors
# SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1

MAKEFILE_DIR := $(shell dirname $(realpath $(firstword $(MAKEFILE_LIST))))

RUN_TAG = $(shell ls -1 $(LIBRELANE_DIR)/runs 2>/dev/null | tail -n 1)

# Variables
TOP = heichips26_e2spike

# PDK, as set up by `make clone-pdk` in the repository root
PDK_ROOT ?= $(MAKEFILE_DIR)/../../IHP-Open-PDK
PDK ?= ihp-sg13cmos5l
SRAM_V_DIR  := $(PDK_ROOT)/$(PDK)/libs.ref/sg13cmos5l_sram/verilog
CELLS_V_DIR := $(PDK_ROOT)/$(PDK)/libs.ref/sg13cmos5l_stdcell/verilog

.DEFAULT_GOAL := help

# Cell name for verification targets (default: top-level cell)
# Override with: make <target> CELL=<cellname>
CELL ?= $(TOP)

# Set the waveform viewer GTKWave or Surfer (default: gtkwave)
# Override with: make <target> WAVEFORM_VIEWER=<gtkwave|surfer>
WAVEFORM_VIEWER ?= gtkwave

# Folder structure
MACROS_DIR      := macros
VERILOG_TB_DIR 	:= testbenches/verilog
REPORT_DIR     	:= verification
SRC_DIR 		:= rtl
NET_NL_DIR    	:= netlist/nl
NET_PNL_DIR  	:= netlist/pnl
NET_SPICE_DIR 	:= netlist/spice
LIBRELANE_DIR 	:= flow/librelane
FLOW_FINAL_DIR 	:= flow/final
FINAL_DIR      	:= final

# Variables for simulation and linting targets
# rtl/*.v is what the LibreLane config synthesizes (rtl/tb and rtl/fpga_emu are
# not included).
MODULES_SYNTH := $(wildcard $(SRC_DIR)/*.v)

MODULES_SIM := \
	$(MODULES_SYNTH)

# Testbench around the macro: the eFPGA memory controller and the IHP SRAM model
TB_SIM_BUILD := $(VERILOG_TB_DIR)/sim_build
TB_SRCS := \
	$(VERILOG_TB_DIR)/$(TOP)_tb.v \
	$(VERILOG_TB_DIR)/efpga_mem_ctrl.v \
	$(SRAM_V_DIR)/RM_IHPSG13_1P_1024x32_c2_bm_bist.v \
	$(SRAM_V_DIR)/RM_IHPSG13_1P_core_behavioral_bm_bist.v
# Checks of the default run: sample 0 image against the reference snapshots.
# Set TB_CHECKS= to simulate a different image with TB_ARGS=+MEMFILE=<pat>.
TB_CHECKS ?= +EXPECT_DIR=expected +EXPECT_CLASS=0 +EXPECT_CYCLES=651328
# Further plusargs, e.g. TB_ARGS=+WAVES or TB_ARGS="+NINFER=2 +RESET_BETWEEN"
TB_ARGS ?=

# Source files for sim-rtl-verilog: auto-selects MODULES_SIM when CELL == TOP, single-file otherwise (prefers .sv, falls back to .v)
_SIM_SRCS = $(if $(filter $(CELL),$(TOP)),$(MODULES_SIM),$(or $(wildcard $(SRC_DIR)/$(CELL).sv),$(SRC_DIR)/$(CELL).v))

# Source files for lint-verilog: all synthesis sources for TOP, single-file otherwise (prefers .sv, falls back to .v)
_LINT_SRCS = $(if $(filter $(CELL),$(TOP)),$(MODULES_SYNTH),$(or $(wildcard $(SRC_DIR)/$(CELL).sv),$(SRC_DIR)/$(CELL).v))

# Testbench extension: prefers <CELL>_tb.sv, falls back to <CELL>_tb.v (dot is added at use site)
_TB_EXT = $(if $(wildcard $(VERILOG_TB_DIR)/$(CELL)_tb.sv),sv,v)


# Help Target
help: ## Show this help message
	@echo 'Usage: make <target> [CELL=<cellname>] [WAVEFORM_VIEWER=<gtkwave|surfer>]'
	@echo ''
	@echo 'Available targets:'
	@grep -E '^[a-zA-Z0-9_.-]+:.*## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*## "}; {printf "  %-20s %s\n", $$1, $$2}'
	@echo ''
	@echo 'CELL defaults to $(TOP). Override to lint or simulate subcells.'
	@echo 'WAVEFORM_VIEWER defaults to gtkwave. Use surfer to launch Surfer instead.'
.PHONY: help
# ================================================================================================


# Linter Targets
lint-verilog: ## Lint Verilog source files with Verilator (usage: make lint-verilog [CELL=<cellname>])
	verilator --lint-only -Wno-fatal -I"$(SRC_DIR)" --top-module $(CELL) $(_LINT_SRCS)
.PHONY: lint-verilog

lint-verilog-all: ## Lint all Verilog source files (counter sub-macro + heichips26_e2spike)
	$(MAKE) -C $(MACROS_DIR)/counter lint-verilog-all
	$(MAKE) lint-verilog
.PHONY: lint-verilog-all
# ================================================================================================


# Simulation Targets
# Both runs load interface/bank_cfg.pat, run one inference and compare the SRAM
# after every layer with testbenches/verilog/expected/. The plusargs are listed
# at the top of testbenches/verilog/heichips26_e2spike_tb.v.
sim-rtl-verilog: ## Run the self-checking RTL simulation of heichips26_e2spike with Icarus Verilog (about 1 min)
	@test -f $(SRAM_V_DIR)/RM_IHPSG13_1P_1024x32_c2_bm_bist.v || { \
		echo "IHP SRAM model not found under $(SRAM_V_DIR), run make clone-pdk in the repository root or set PDK_ROOT"; exit 1; }
	mkdir -p $(TB_SIM_BUILD)
	iverilog -g2012 -DFUNCTIONAL -s $(TOP)_tb -o $(TB_SIM_BUILD)/$(TOP)_tb_rtl.vvp $(TB_SRCS) $(MODULES_SIM)
	cd $(VERILOG_TB_DIR) && vvp -n sim_build/$(TOP)_tb_rtl.vvp -fst $(TB_CHECKS) $(TB_ARGS) | tee sim_build/rtl.log
	@grep -q "^TB PASS" $(TB_SIM_BUILD)/rtl.log
.PHONY: sim-rtl-verilog

# The committed netlist is simulated twice, with every flip-flop starting at 0
# and at 1 (see testbenches/verilog/gl_udp_init.py). Both must pass.
sim-gl-verilog: ## Run the self-checking gate-level simulation of final/nl with both power-up states (about 9 min)
	@test -f $(CELLS_V_DIR)/sg13cmos5l_stdcell.v || { \
		echo "IHP standard cell models not found under $(CELLS_V_DIR), run make clone-pdk in the repository root or set PDK_ROOT"; exit 1; }
	mkdir -p $(TB_SIM_BUILD)
	@set -e; for init in 0 1; do \
		python3 $(VERILOG_TB_DIR)/gl_udp_init.py $(CELLS_V_DIR)/sg13cmos5l_udp.v $(TB_SIM_BUILD)/udp_init$$init.v $$init; \
		iverilog -g2012 -gno-specify -DFUNCTIONAL -DGL -s $(TOP)_tb -o $(TB_SIM_BUILD)/$(TOP)_tb_gl$$init.vvp \
			$(TB_SRCS) $(TB_SIM_BUILD)/udp_init$$init.v $(CELLS_V_DIR)/sg13cmos5l_stdcell.v $(FINAL_DIR)/nl/$(TOP).nl.v \
			2>&1 | grep -v "sorry: ifnone\|timescale" || true; \
		echo "gate level, flip-flops starting at $$init"; \
		(cd $(VERILOG_TB_DIR) && vvp -n sim_build/$(TOP)_tb_gl$$init.vvp -fst $(TB_CHECKS) $(TB_ARGS) | tee sim_build/gl$$init.log); \
		grep -q "^TB PASS" $(TB_SIM_BUILD)/gl$$init.log; \
	done
.PHONY: sim-gl-verilog

sim-view-verilog: ## View the waveform of the last run with TB_ARGS=+WAVES (usage: make sim-view-verilog [WAVEFORM_VIEWER=<gtkwave|surfer>])
	$(WAVEFORM_VIEWER) $(TB_SIM_BUILD)/$(TOP)_tb.fst
.PHONY: sim-view-verilog

sim-all: ## Simulate the macro: RTL, then the committed gate-level netlist
	$(MAKE) sim-rtl-verilog
	$(MAKE) sim-gl-verilog
.PHONY: sim-all
# ================================================================================================


# LibreLane Targets
librelane: ## Run LibreLane with Magic and KLayout DRC checks.
	librelane $(LIBRELANE_DIR)/config.yaml --pdk ${PDK} --pdk-root ${PDK_ROOT} --manual-pdk --save-views-to $(FLOW_FINAL_DIR)/
.PHONY: librelane

librelane-nodrc: ## Run LibreLane without DRC checks
	librelane $(LIBRELANE_DIR)/config.yaml --pdk ${PDK} --pdk-root ${PDK_ROOT} --manual-pdk --save-views-to $(FLOW_FINAL_DIR)/ --skip KLayout.DRC --skip Magic.DRC
.PHONY: librelane-nodrc

librelane-magicdrc: ## Run LibreLane with only Magic DRC checks
	librelane $(LIBRELANE_DIR)/config.yaml --pdk ${PDK} --pdk-root ${PDK_ROOT} --manual-pdk --save-views-to $(FLOW_FINAL_DIR)/ --skip KLayout.DRC
.PHONY: librelane-magicdrc

librelane-klayoutdrc: ## Run LibreLane with only KLayout DRC checks
	librelane $(LIBRELANE_DIR)/config.yaml --pdk ${PDK} --pdk-root ${PDK_ROOT} --manual-pdk --save-views-to $(FLOW_FINAL_DIR)/ --skip Magic.DRC
.PHONY: librelane-klayoutdrc

librelane-openroad: ## Open the last LibreLane run in OpenROAD GUI
	librelane $(LIBRELANE_DIR)/config.yaml --pdk ${PDK} --pdk-root ${PDK_ROOT} --manual-pdk --last-run --flow OpenInOpenROAD
.PHONY: librelane-openroad

librelane-klayout: ## Open the last LibreLane run in KLayout
	librelane $(LIBRELANE_DIR)/config.yaml --pdk ${PDK} --pdk-root ${PDK_ROOT} --manual-pdk --last-run --flow OpenInKLayout
.PHONY: librelane-klayout
# ================================================================================================


# Copy Targets
# Using * wildcard to ignore step numbers
copy-reports: ## Copy yosys, antenna, STA, power, IR-drop, DRC, LVS and manufacturability reports from the last LibreLane run to verification/
	rm -rf $(REPORT_DIR)/
	mkdir -p $(REPORT_DIR)/
	cp $(LIBRELANE_DIR)/runs/${RUN_TAG}/*-yosys-synthesis/reports/pre_synth_chk.rpt $(REPORT_DIR)/yosys_synth_check.rpt
	cp $(LIBRELANE_DIR)/runs/${RUN_TAG}/*-yosys-synthesis/reports/pre_techmap.rpt $(REPORT_DIR)/yosys_pre_techmap.rpt
	cp $(LIBRELANE_DIR)/runs/${RUN_TAG}/*-yosys-synthesis/reports/post_dff.rpt $(REPORT_DIR)/yosys_post_dff.rpt
	cp $(LIBRELANE_DIR)/runs/${RUN_TAG}/*-yosys-synthesis/reports/stat.rpt $(REPORT_DIR)/stat.rpt
	cp $(LIBRELANE_DIR)/runs/${RUN_TAG}/*-openroad-checkantennas-1/reports/antenna.rpt $(REPORT_DIR)/antenna_violations.rpt
	cp $(LIBRELANE_DIR)/runs/${RUN_TAG}/*-openroad-checkantennas-1/reports/antenna_summary.rpt $(REPORT_DIR)/antenna_summary.rpt
	cp $(LIBRELANE_DIR)/runs/${RUN_TAG}/*-openroad-stapostpnr/summary.rpt $(REPORT_DIR)/stapostpnr_summary.rpt
	cp $(LIBRELANE_DIR)/runs/${RUN_TAG}/*-openroad-stapostpnr/nom_fast_1p32V_m40C/power.rpt $(REPORT_DIR)/stapostpnr_nom_fast_1p32V_m40C_power.rpt
	cp $(LIBRELANE_DIR)/runs/${RUN_TAG}/*-openroad-stapostpnr/nom_slow_1p08V_125C/power.rpt $(REPORT_DIR)/stapostpnr_nom_slow_1p08V_125C_power.rpt
	cp $(LIBRELANE_DIR)/runs/${RUN_TAG}/*-openroad-stapostpnr/nom_typ_1p20V_25C/power.rpt $(REPORT_DIR)/stapostpnr_nom_typ_1p20V_25C_power.rpt
	cp $(LIBRELANE_DIR)/runs/${RUN_TAG}/*-openroad-irdropreport/irdrop.rpt $(REPORT_DIR)/irdrop.rpt
	cp $(LIBRELANE_DIR)/runs/${RUN_TAG}/*-magic-drc/reports/drc.magic.rpt $(REPORT_DIR)/drc.magic.rpt
	cp $(LIBRELANE_DIR)/runs/${RUN_TAG}/*-klayout-drc/reports/drc.klayout.json $(REPORT_DIR)/drc.klayout.json
	cp $(LIBRELANE_DIR)/runs/${RUN_TAG}/*-netgen-lvs/reports/lvs.netgen.rpt $(REPORT_DIR)/lvs.netgen.rpt
	cp $(LIBRELANE_DIR)/runs/${RUN_TAG}/*-misc-reportmanufacturability/manufacturability.rpt $(REPORT_DIR)/manufacturability.rpt
.PHONY: copy-reports

copy-final: ## Copy final output gds, lef, lib, nl, pnl, spef, vh and render folders from the last LibreLane run to final/
	rm -rf $(FINAL_DIR)/
	mkdir -p $(FINAL_DIR)/
	cp -r $(FLOW_FINAL_DIR)/gds    $(FINAL_DIR)/gds
	cp -r $(FLOW_FINAL_DIR)/lef    $(FINAL_DIR)/lef
	cp -r $(FLOW_FINAL_DIR)/lib    $(FINAL_DIR)/lib
	cp -r $(FLOW_FINAL_DIR)/nl     $(FINAL_DIR)/nl
	cp -r $(FLOW_FINAL_DIR)/pnl    $(FINAL_DIR)/pnl
	cp -r $(FLOW_FINAL_DIR)/spef   $(FINAL_DIR)/spef
	cp -r $(FLOW_FINAL_DIR)/vh     $(FINAL_DIR)/vh
	cp -r $(FLOW_FINAL_DIR)/render $(FINAL_DIR)/render
.PHONY: copy-final

copy-netlist: ## Copy final output spice, pnl and nl netlists from the last LibreLane run to netlist/
	rm -rf $(NET_SPICE_DIR)/
	mkdir -p $(NET_SPICE_DIR)/
	cp -r $(FLOW_FINAL_DIR)/spice/${TOP}.spice $(NET_SPICE_DIR)/${TOP}.spice

	rm -rf $(NET_PNL_DIR)/
	mkdir -p $(NET_PNL_DIR)/
	cp -r $(FLOW_FINAL_DIR)/pnl/${TOP}.pnl.v $(NET_PNL_DIR)/${TOP}.pnl.v

	rm -rf $(NET_NL_DIR)/
	mkdir -p $(NET_NL_DIR)/
	cp -r $(FLOW_FINAL_DIR)/nl/${TOP}.nl.v $(NET_NL_DIR)/${TOP}.nl.v
.PHONY: copy-netlist
# ================================================================================================


# Build Targets
build-counter: ## Lint, build, verify and simulate the counter macro
	@$(MAKE) -C $(MACROS_DIR)/counter all
.PHONY: build-counter

build-macros: ## Lint, build, verify and simulate all macros
	$(MAKE) build-counter
#	ToDo: further macros
.PHONY: build-macros

build-fpga: ## Build FPGA bitstream (usage: make build-fpga [BOARD=ulx3s])
	@$(MAKE) -C fpga all
.PHONY: build-fpga

load-fpga: ## Load FPGA bitstream into SRAM (usage: make load-fpga [BOARD=ulx3s])
	@$(MAKE) -C fpga load_bitstream
.PHONY: load-fpga

flash-fpga: ## Write FPGA bitstream to flash (usage: make flash-fpga [BOARD=ulx3s])
	@$(MAKE) -C fpga flash_bitstream
.PHONY: flash-fpga

build-top: ## Build macro (run LibreLane with KLayout & Magic DRC checks, copy reports, copy final files, and copy netlists)
	$(MAKE) librelane
	$(MAKE) copy-reports
	$(MAKE) copy-final
	$(MAKE) copy-netlist
#	$(MAKE) librelane-openroad
.PHONY: build-top
# ================================================================================================


# DRC & LVS Verification Targets
# The LibreLane flow already includes DRC and LVS checks with Magic and KLayout, and they are saved in the verification/ folder.
# ================================================================================================


# Lint, Build, Verify and Simulate All Target
all: ## Lint, build, verify and simulate the macros and the TOP cell
	$(MAKE) lint-verilog-all
	$(MAKE) build-macros
	$(MAKE) build-fpga
	$(MAKE) build-top
	$(MAKE) sim-all
.PHONY: all
# ================================================================================================


# Clean Targets
clean: ## Delete all generated files and folders of the TOP cell (LibreLane outputs, final, netlist, reports, simulation and FPGA outputs)
	rm -rf $(LIBRELANE_DIR)/runs $(FLOW_FINAL_DIR)
	rm -rf final netlist
	rm -rf $(REPORT_DIR)
	rm -rf $(TB_SIM_BUILD)
	@$(MAKE) -C fpga clean
.PHONY: clean

clean-counter: ## Delete all generated files and folders of the counter macro
	@$(MAKE) -C $(MACROS_DIR)/counter clean
.PHONY: clean-counter

clean-macros: ## Delete all generated files and folders of all macros
	$(MAKE) clean-counter
#	ToDo: further macros
.PHONY: clean-macros

clean-all: ## Delete all generated files and folders of the macros and the TOP cell
	$(MAKE) clean-macros
	$(MAKE) clean
.PHONY: clean-all
# ================================================================================================
