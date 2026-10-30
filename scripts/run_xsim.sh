#!/usr/bin/env bash
# Cross-check: run the unit testbenches and the core programs in Vivado's
# simulator (xsim) instead of Icarus. Core traces are compared with the
# Python reference model output from `make test-core` (run that first).
#
# Usage: scripts/run_xsim.sh            (from WSL; calls Windows Vivado)
# Override the Vivado location with VIVADO_BIN='C:\path\to\Vivado\bin'.

set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VIVADO_BIN="${VIVADO_BIN:-C:\\AMDDesignTools\\2026.1\\Vivado\\bin}"
WORK="$ROOT/build/xsim"
mkdir -p "$WORK/build/sim/core"      # testbenches write VCDs to build/sim/ relative to cwd
cd "$WORK"

win() {   # run a Vivado .bat tool through cmd.exe, from $WORK
    local tool=$1; shift
    cmd.exe /c "$VIVADO_BIN\\$tool.bat $*" 2>&1 | tr -d '\r'
}

R=../..
PKG="$R/rtl/rv32i_pkg.sv"
RTL_ALL="$PKG $R/rtl/program_counter.sv $R/rtl/instruction_memory.sv $R/rtl/instruction_decoder.sv
 $R/rtl/control_unit.sv $R/rtl/immediate_generator.sv $R/rtl/register_file.sv $R/rtl/alu.sv
 $R/rtl/branch_unit.sv $R/rtl/next_pc_logic.sv $R/rtl/load_store_unit.sv $R/rtl/data_memory.sv
 $R/rtl/rv32i_core.sv $R/rtl/rv32i_soc_top.sv"

UNIT_TBS="tb_program_counter tb_register_file tb_alu tb_immediate_generator tb_control_unit
 tb_branch_unit tb_next_pc_logic tb_load_store_unit"
TB_FILES=$(for t in $UNIT_TBS tb_rv32i_core; do echo -n "$R/tb/$t.sv "; done)

fail=0
echo "== xvlog (compile) =="
if ! win xvlog --sv -i "$R/tb" $RTL_ALL $TB_FILES > xvlog_console.txt; then :; fi
if grep -q "ERROR" xvlog_console.txt; then grep "ERROR" xvlog_console.txt; echo "FAIL: xvlog"; exit 1; fi

for tb in $UNIT_TBS; do
    win xelab -debug off "$tb" -s "${tb}_snap" > "xelab_$tb.txt"
    win xsim "${tb}_snap" -R > "xsim_$tb.txt"
    if grep -q "^PASS: $tb" "xsim_$tb.txt"; then
        grep "^PASS: $tb" "xsim_$tb.txt" | sed 's/^/xsim /'
    else
        echo "xsim FAIL: $tb"; grep -E "FAIL|ERROR|Fatal" "xsim_$tb.txt" | head -5; fail=1
    fi
done

win xelab -debug off tb_rv32i_core -s core_snap > xelab_core.txt
for hex in "$ROOT"/tests/programs/*.hex; do
    name=$(basename "$hex" .hex)
    # cmd.exe splits batch arguments at '=', so each plusarg is passed in quotes.
    win xsim core_snap -R -testplusarg "\"PROGRAM=$R/tests/programs/$name.hex\"" \
        -testplusarg "\"TRACE=build/sim/core/$name.xsim.txt\"" > "xsim_core_$name.txt"
    ref="$ROOT/build/sim/core/$name.iss.txt"
    act="$WORK/build/sim/core/$name.xsim.txt"
    if [[ ! -f "$ref" ]]; then
        echo "xsim SKIP: $name (no model output; run make test-core first)"
    # xsim on Windows writes CRLF line endings; strip CR before comparing.
    elif grep -q "^PASS: tb_rv32i_core" "xsim_core_$name.txt" && cmp -s "$ref" <(tr -d '\r' < "$act"); then
        echo "xsim PASS: core program $name (trace matches reference model)"
    else
        echo "xsim FAIL: core program $name"; fail=1
    fi
done

exit $fail
