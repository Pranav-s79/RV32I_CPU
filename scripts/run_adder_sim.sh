#!/usr/bin/env bash
# Compile and run the Phase 0 adder simulation with Icarus Verilog.
# Does not modify any RTL. Output goes to build/sim/ (git-ignored).
#
# Note: the current testbench only prints the result; it does not check it.
# A zero exit status means "compiled and ran", not "passed".

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RTL="$ROOT/rtl/simple_adder.sv"
TB="$ROOT/tb/simple_adder_tb.sv"
OUT_DIR="$ROOT/build/sim"
OUT="$OUT_DIR/simple_adder.vvp"

if ! command -v iverilog >/dev/null 2>&1 || ! command -v vvp >/dev/null 2>&1; then
    echo "ERROR: iverilog/vvp not found. Install with: sudo apt install iverilog" >&2
    exit 1
fi

for f in "$RTL" "$TB"; do
    if [[ ! -f "$f" ]]; then
        echo "ERROR: expected source file not found: ${f#"$ROOT"/}" >&2
        exit 1
    fi
done

mkdir -p "$OUT_DIR"

echo "Compiling: ${RTL#"$ROOT"/} ${TB#"$ROOT"/}"
if ! iverilog -g2012 -Wall -o "$OUT" "$RTL" "$TB"; then
    echo "ERROR: compilation failed" >&2
    exit 1
fi

echo "Running simulation:"
vvp -n "$OUT"
