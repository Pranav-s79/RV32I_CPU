#!/usr/bin/env python3
"""Run every test program on the RTL CPU and check it three ways:

1. tb_rv32i_core.sv checks halt, trap cause, and a0 by itself (PASS/FAIL).
2. The RTL trace (every retired instruction + final state) must match the
   Python reference model (scripts/rv32i_iss.py) line for line.
3. Hand-written expectations below (trap PC, trap value, specific
   registers and memory words) are checked against the RTL output.

Exit status is non-zero if any program fails.
"""

import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PROG = ROOT / "tests" / "programs"
OUT = ROOT / "build" / "sim" / "core"
VVP = ROOT / "build" / "sim" / "tb_rv32i_core.vvp"

RTL = ["rv32i_pkg", "program_counter", "instruction_memory", "instruction_decoder",
       "control_unit", "immediate_generator", "register_file", "alu", "branch_unit",
       "next_pc_logic", "load_store_unit", "data_memory", "rv32i_core", "rv32i_soc_top"]

# Expected results, worked out by hand from each program's source.
# pc / tval may name a symbol ("sym+offset") from the program's .sym file.
TESTS = {
    "rv32i_full": dict(cause=11, a0=0x0, led=0x5),
    "c_simple": dict(cause=11, a0=0x8),                 # add_numbers(5, 3)
    "trap_illegal": dict(cause=2, pc="expected_trap", tval=0x02C585B3,
                         regs={10: 0x11, 11: 0x3}),
    "trap_ebreak": dict(cause=3, pc="expected_trap", tval="expected_trap",
                        regs={10: 0x33}),
    "trap_load_misaligned": dict(cause=4, pc="expected_trap", tval=0x10002,
                                 regs={5: 0x55}),
    "trap_store_misaligned": dict(cause=6, pc="expected_trap", tval=0x10005,
                                  mem={0x10004: 0x11223344}),
    "trap_load_fault": dict(cause=5, pc="expected_trap", tval=0x100,
                            regs={5: 0x66}),
    "trap_store_fault": dict(cause=7, pc="expected_trap", tval=0x11000,
                             mem={0x10000: 0xAAAA5555}),
    "trap_jalr_misaligned": dict(cause=0, pc="expected_trap", tval="landing+2",
                                 regs={1: 0x77}),
    "trap_branch_misaligned": dict(cause=0, pc="expected_trap", tval="expected_trap+2",
                                   regs={10: 0x2}),
    "trap_fetch_fault": dict(cause=1, pc=0x1000, tval=0x1000, regs={1: 0x8}),
}

WAVEFORMS = {"rv32i_full", "c_simple", "trap_load_misaligned"}


def symbols(name):
    table = {}
    for line in (PROG / f"{name}.sym").read_text().splitlines():
        addr, sym = line.split()
        table[sym] = int(addr, 16)
    return table


def resolve(value, syms):
    if isinstance(value, int):
        return value
    sym, _, off = value.partition("+")
    return syms[sym] + (int(off, 0) if off else 0)


def parse_state(path):
    state = {"regs": {}, "mem": {}}
    for line in path.read_text().splitlines():
        if line.startswith("TRAP"):
            fields = dict(f.split("=") for f in line.split()[1:])
            state["cause"] = int(fields["cause"])
            state["pc"] = int(fields["pc"], 16)
            state["tval"] = int(fields["tval"], 16)
        elif line.startswith("x") and "=" in line and " " not in line:
            reg, val = line[1:].split("=")
            state["regs"][int(reg)] = int(val, 16)
        elif line.startswith("LED="):
            state["led"] = int(line[4:], 16)
        elif line.startswith("MEM["):
            addr, val = line[4:].split("]=")
            state["mem"][int(addr, 16)] = int(val, 16)
    return state


def compile_tb():
    OUT.mkdir(parents=True, exist_ok=True)
    srcs = [str(ROOT / "rtl" / f"{m}.sv") for m in RTL] + [str(ROOT / "tb" / "tb_rv32i_core.sv")]
    cmd = ["iverilog", "-g2012", "-I", str(ROOT / "tb"), "-s", "tb_rv32i_core", "-o", str(VVP), *srcs]
    result = subprocess.run(cmd, capture_output=True, text=True)
    noise = "sorry: constant selects in always_* processes"
    msgs = [l for l in (result.stdout + result.stderr).splitlines() if noise not in l]
    if msgs:
        print("\n".join(msgs))
    if result.returncode != 0:
        sys.exit("FAIL: tb_rv32i_core did not compile")


def run_one(name, exp):
    errors = []
    syms = symbols(name)
    hexfile = PROG / f"{name}.hex"
    expected = OUT / f"{name}.iss.txt"
    actual = OUT / f"{name}.rtl.txt"

    subprocess.run([sys.executable, str(ROOT / "scripts" / "rv32i_iss.py"), str(hexfile), str(expected)],
                   check=True)

    args = ["vvp", "-n", str(VVP), f"+PROGRAM={hexfile}", f"+TRACE={actual}",
            f"+EXPECT_CAUSE={exp['cause']}"]
    if "a0" in exp:
        args.append(f"+EXPECT_A0={exp['a0']:x}")
    if name in WAVEFORMS:
        args.append(f"+VCD={OUT / (name + '.vcd')}")
    sim = subprocess.run(args, capture_output=True, text=True, cwd=ROOT)
    log = sim.stdout + sim.stderr
    (OUT / f"{name}.log").write_text(log)
    if sim.returncode != 0 or "PASS: tb_rv32i_core" not in log:
        errors.append("testbench self-checks failed:\n    " + "\n    ".join(
            l for l in log.splitlines() if "FAIL" in l or "FATAL" in l))
    if not actual.exists():
        return errors + ["no RTL trace produced"]

    # ---- 2. lockstep trace comparison against the reference model ----
    exp_lines = expected.read_text().splitlines()
    act_lines = actual.read_text().splitlines()
    for i, (e, a) in enumerate(zip(exp_lines, act_lines)):
        if e != a:
            errors.append(f"trace mismatch at line {i + 1}:\n    model: {e}\n    RTL:   {a}")
            break
    else:
        if len(exp_lines) != len(act_lines):
            errors.append(f"trace length differs: model {len(exp_lines)} lines, RTL {len(act_lines)}")

    # ---- 3. hand-written expectations ----
    st = parse_state(actual)
    if st.get("cause") != exp["cause"]:
        errors.append(f"cause {st.get('cause')} != expected {exp['cause']}")
    for key in ("pc", "tval"):
        if key in exp and st.get(key) != resolve(exp[key], syms):
            errors.append(f"trap {key} 0x{st.get(key, 0):08x} != expected 0x{resolve(exp[key], syms):08x}")
    if "a0" in exp and st["regs"].get(10) != exp["a0"]:
        errors.append(f"a0 0x{st['regs'].get(10, 0):08x} != expected 0x{exp['a0']:08x}")
    if "led" in exp and st.get("led") != exp["led"]:
        errors.append(f"LED {st.get('led')} != expected {exp['led']}")
    for reg, val in exp.get("regs", {}).items():
        if st["regs"].get(reg) != val:
            errors.append(f"x{reg} 0x{st['regs'].get(reg, 0):08x} != expected 0x{val:08x}")
    for addr, val in exp.get("mem", {}).items():
        if st["mem"].get(addr, 0) != val:
            errors.append(f"MEM[0x{addr:08x}] 0x{st['mem'].get(addr, 0):08x} != expected 0x{val:08x}")
    if "mem" in exp and set(st["mem"]) != set(exp["mem"]):
        errors.append(f"unexpected memory words written: {sorted(hex(a) for a in set(st['mem']) - set(exp['mem']))}")

    retired = sum(1 for l in act_lines if l[:1] in "0123456789abcdef" and " " in l and not l.startswith("x"))
    return errors, retired, st


def main():
    compile_tb()
    failed = 0
    for name, exp in TESTS.items():
        result = run_one(name, exp)
        if isinstance(result, list):
            errors, retired, st = result, 0, {}
        else:
            errors, retired, st = result
        if errors:
            failed += 1
            print(f"FAIL: {name}")
            for e in errors:
                print(f"  - {e}")
        else:
            print(f"PASS: {name:24s} {retired:4d} instructions retired, "
                  f"trap cause={st['cause']:2d} pc=0x{st['pc']:08x} tval=0x{st['tval']:08x}")
    total = len(TESTS)
    if failed:
        print(f"==== CORE TESTS: {failed} of {total} FAILED ====")
        sys.exit(1)
    print(f"==== CORE TESTS: all {total} programs PASSED (RTL matches reference model) ====")


if __name__ == "__main__":
    main()
