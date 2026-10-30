#!/usr/bin/env bash
# Compile and run one self-checking testbench with Icarus Verilog.
# Usage: scripts/sim_unit.sh <top_module> <source files...>
# Exit status is non-zero if compilation fails, the testbench calls $fatal,
# or the log does not contain a PASS line.

set -uo pipefail

TOP="$1"; shift
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SIM_DIR="$ROOT/build/sim"
mkdir -p "$SIM_DIR"
cd "$ROOT"

# Icarus 11 prints "sorry: constant selects in always_* processes ..." for
# any always_comb that reads part of a vector. It only means the whole
# vector is put in the sensitivity list (slightly slower simulation); the
# behavior is unchanged. Filter that one message so real warnings stand out.
FILTER='sorry: constant selects in always_\* processes'

if ! iverilog -g2012 -Wall -I tb -s "$TOP" -o "$SIM_DIR/$TOP.vvp" "$@" 2>&1 | { grep -v "$FILTER" || true; }; then
    echo "FAIL: $TOP (compile error)"
    exit 1
fi

vvp -n "$SIM_DIR/$TOP.vvp" 2>&1 | tee "$SIM_DIR/$TOP.log"
status=${PIPESTATUS[0]}

if [[ $status -ne 0 ]]; then
    exit "$status"
fi
if ! grep -q "^PASS: $TOP" "$SIM_DIR/$TOP.log"; then
    echo "FAIL: $TOP (no PASS line in log)"
    exit 1
fi
