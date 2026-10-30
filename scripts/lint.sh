#!/usr/bin/env bash
# Lint / elaboration check for all RTL.
#   1. Icarus Verilog: elaborate rv32i_soc_top and rv32i_core with -Wall.
#   2. Verilator --lint-only -Wall, if installed (not required).
# Vivado's synthesis log is the final word on latches; see make synth.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
mkdir -p build/lint

RTL="rtl/rv32i_pkg.sv rtl/program_counter.sv rtl/instruction_memory.sv rtl/instruction_decoder.sv
     rtl/control_unit.sv rtl/immediate_generator.sv rtl/register_file.sv rtl/alu.sv rtl/branch_unit.sv
     rtl/next_pc_logic.sv rtl/load_store_unit.sv rtl/data_memory.sv rtl/rv32i_core.sv rtl/rv32i_soc_top.sv"
# Known Icarus 11 limitation (sensitivity-list granularity, not a design issue)
FILTER='sorry: constant selects in always_\* processes'
fail=0

for top in rv32i_soc_top rv32i_core; do
    out=$(iverilog -g2012 -Wall -s "$top" -o "build/lint/$top.vvp" $RTL 2>&1)
    status=$?
    msgs=$(echo "$out" | grep -v "$FILTER" | sed '/^$/d')
    if [[ $status -ne 0 ]]; then
        echo "FAIL: iverilog elaboration of $top"; echo "$msgs"; fail=1
    elif [[ -n "$msgs" ]]; then
        echo "WARN: iverilog warnings for $top:"; echo "$msgs"; fail=1
    else
        echo "PASS: iverilog -Wall elaboration of $top (no warnings)"
    fi
done

if command -v verilator >/dev/null 2>&1; then
    if verilator --lint-only -Wall --top-module rv32i_soc_top $RTL; then
        echo "PASS: verilator --lint-only -Wall"
    else
        echo "FAIL: verilator lint"; fail=1
    fi
else
    echo "SKIP: verilator not installed (optional: sudo apt install verilator)"
fi

exit $fail
