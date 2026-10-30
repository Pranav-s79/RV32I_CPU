# Makefile for the RV32I single-cycle CPU (Phase 1)
#
#   make test            all unit tests + full-core program tests
#   make test-unit       all unit tests
#   make test-alu        one unit test (see list below)
#   make test-core       run every program in tests/programs on the CPU and
#                        compare against the Python reference model
#   make test-xsim       re-run unit + core tests in Vivado's simulator (xsim)
#   make lint            elaborate the whole design with all warnings on
#   make programs        re-assemble tests/programs/*.S into .hex images
#   make synth           Vivado synthesis + implementation baseline (Windows Vivado)
#   make vivado-project  create a Vivado GUI project
#   make clean           delete build/

SHELL := /bin/bash
.SHELLFLAGS := -o pipefail -c

BUILD   := build
SIM_DIR := $(BUILD)/sim

PKG := rtl/rv32i_pkg.sv
RTL := $(PKG) \
       rtl/program_counter.sv \
       rtl/instruction_memory.sv \
       rtl/instruction_decoder.sv \
       rtl/control_unit.sv \
       rtl/immediate_generator.sv \
       rtl/register_file.sv \
       rtl/alu.sv \
       rtl/branch_unit.sv \
       rtl/next_pc_logic.sv \
       rtl/load_store_unit.sv \
       rtl/data_memory.sv \
       rtl/rv32i_core.sv \
       rtl/rv32i_soc_top.sv

UNIT := ./scripts/sim_unit.sh

# Vivado on the Windows host (called from WSL through cmd.exe)
VIVADO ?= C:\AMDDesignTools\2026.1\Vivado\bin\vivado.bat

.PHONY: test test-unit test-pc test-registers test-alu test-imm test-control \
        test-branch test-nextpc test-lsu test-core test-xsim lint programs synth \
        vivado-project clean

test: test-unit test-core
	@echo "==== ALL TESTS PASSED ===="

test-unit: test-pc test-registers test-alu test-imm test-control test-branch test-nextpc test-lsu
	@echo "==== ALL UNIT TESTS PASSED ===="

test-pc:
	$(UNIT) tb_program_counter rtl/program_counter.sv tb/tb_program_counter.sv

test-registers:
	$(UNIT) tb_register_file rtl/register_file.sv tb/tb_register_file.sv

test-alu:
	$(UNIT) tb_alu $(PKG) rtl/alu.sv tb/tb_alu.sv

test-imm:
	$(UNIT) tb_immediate_generator $(PKG) rtl/immediate_generator.sv tb/tb_immediate_generator.sv

test-control:
	$(UNIT) tb_control_unit $(PKG) rtl/instruction_decoder.sv rtl/control_unit.sv tb/tb_control_unit.sv

test-branch:
	$(UNIT) tb_branch_unit $(PKG) rtl/branch_unit.sv tb/tb_branch_unit.sv

test-nextpc:
	$(UNIT) tb_next_pc_logic rtl/next_pc_logic.sv tb/tb_next_pc_logic.sv

test-lsu:
	$(UNIT) tb_load_store_unit $(PKG) rtl/load_store_unit.sv tb/tb_load_store_unit.sv

test-core:
	python3 scripts/run_core_tests.py

test-xsim:
	./scripts/run_xsim.sh

lint:
	./scripts/lint.sh

programs:
	python3 scripts/build_programs.py

synth:
	cmd.exe /c "$(VIVADO) -mode batch -notrace -source scripts/vivado/synth_baseline.tcl -log build/vivado/synth_baseline.log -journal build/vivado/synth_baseline.jou"

vivado-project:
	cmd.exe /c "$(VIVADO) -mode batch -notrace -source scripts/vivado/create_project.tcl -log build/vivado/create_project.log -journal build/vivado/create_project.jou"

clean:
	rm -rf $(BUILD)
