# Phase 1 Baseline: Synthesis, Timing, Resources

All numbers below were **measured** on 2026-10-29 by `make synth` (`scripts/vivado/synth_baseline.tcl`) with Vivado 2026.1. The reports they come from are in `results/synthesis/` and `results/timing/`. The formal baseline record is [`configs/baselines/B001_single_cycle.md`](../configs/baselines/B001_single_cycle.md).

## Method

| Item | Setting |
|------|---------|
| Part | `xc7z010clg400-1` (Zybo Z7-10) |
| Tool | Vivado 2026.1, non-project batch mode, default synthesis/implementation directives |
| Mode | Out-of-context (OOC): no I/O buffers, no pin constraints |
| Clock constraint | `create_clock -period 10.000 [get_ports clk]` (`constraints/timing_phase1.xdc`) |
| Run 1 | `rv32i_soc_top` (core + 4 KiB instruction ROM + 4 KiB data RAM + LED register): synth → opt → place → route |
| Run 2 | `rv32i_core` alone (no memories): synthesis only, for core resource usage |
| ROM image | `tests/programs/rv32i_full.hex` (386 words) |

**Why 10 ns?** It's a fixed reference period kept the same in every future phase so results are comparable. It is *not* a claim that the design runs at 100 MHz. The single-cycle design fails it, and the estimated maximum frequency is derived from the slack:

> estimated Fmax = 1 / (T − WNS) = 1000 / (10.000 − WNS) MHz

This estimate assumes the same critical path stays critical at the slower clock, which is normal for a single-clock, register-to-register design. Vivado runs with a constraint the design can't meet. A run with the period set just above the achievable one might do slightly better or worse. Phase 6 will run a period sweep to confirm.

**OOC caveats.** With no clock source pin, Vivado assumes an ideal clock (no insertion delay or skew; warning `Timing 38-242`). Ports such as `reset` and `led` have no I/O delays, so only internal register-to-register paths are timed. That is the CPU datapath, which is what this baseline is for.

## Results: full system (post-route)

| Metric | Value |
|--------|-------|
| Worst negative slack (WNS) | **−7.194 ns** |
| Total negative slack (TNS) | −15,052.168 ns over 5,361 of 5,805 endpoints |
| Worst hold slack (WHS) | +0.257 ns (met) |
| Critical path data delay | 16.925 ns (logic 3.600 ns = 21%, routing 13.325 ns = 79%) |
| Critical path logic levels | 19 |
| **Estimated Fmax** | **≈ 58.2 MHz** (1000 / 17.194) |
| Post-synthesis estimate (for comparison) | WNS −6.955 ns → ≈ 59.0 MHz |

| Resource | Used | Available | % |
|----------|-----:|----------:|--:|
| Slice LUTs (total) | 2,054 | 17,600 | 11.7 |
| – LUT as logic | 1,498 | 17,600 | 8.5 |
| – LUT as distributed RAM | 556 | 6,000 | 9.3 |
| Flip-flops | 47 | 35,200 | 0.13 |
| Latches | **0** | | |
| CARRY4 | 51 | | |
| MUXF7 / MUXF8 | 385 / 189 | | |
| Block RAM (RAMB36/18) | 0 | 60 / 120 | 0 |
| DSP48 | 0 | 80 | 0 |

The full system has only 47 flip-flops because Vivado removed the core's `trap_pc`/`trap_tval` registers (the SoC doesn't output them).

## Results: core only (post-synthesis)

| Resource | Used |
|----------|-----:|
| Slice LUTs | 1,079 |
| – LUT as logic | 1,031 |
| – LUT as distributed RAM (register file) | 48 |
| Flip-flops | 101 (PC 32 + halted 1 + trap cause 4 + trap PC 32 + trap value 32) |
| Latches | **0** |
| CARRY4 | 51 |
| Block RAM / DSP | 0 / 0 |

Breakdown caveat: Vivado's hierarchical report shows most logic under `u_pc`, because synthesis moves logic across module boundaries while optimizing. Per-module numbers are therefore not reliable. The totals are.

## Critical path

From `results/timing/phase1_soc_route_timing_paths.rpt` (path 1):

```
Start: u_core/u_pc/pc_reg[6]/C                        (PC flip-flop)
  → instruction ROM logic (LUT6 → MUXF7 → MUXF8 → LUT6)   instruction bits (rs2 field)
  → register file LUTRAM read port                     rs2_data
  → operand / ALU / address logic (LUT6 ×6, LUT3, LUT4) data-memory address
  → data memory LUTRAM (RAMS64E → MUXF7 → MUXF8 → LUT6) load data
  → load extension + writeback mux (LUT6 ×3)
End:   u_core/u_regfile/.../DIB0                       (register file write data)
```

This is the **load instruction path**, as predicted in `instruction_walkthrough.md`: two memory reads in series in one cycle. Signs of what limits it:

- **Routing is 79 % of the delay.** Huge fan-outs: one PC bit drives 339 loads (the ROM is a big LUT tree), and one data-memory address bit drives 517 LUTRAM cells (4 KiB in 64-bit LUTRAM pieces).
- **Deep logic.** 19 levels on the worst path; most of the top 1,000 paths have 17–20 levels.
- **Asynchronous memories built from LUTs** are slower than block RAM and scale poorly with size.

## Performance

- CPI = 1 by construction: the RTL has no stall path, and the PC advances on every cycle that commits an instruction. `rv32i_full` retires 397 instructions, then traps on the ECALL in the next cycle. The testbench's cycle counter reports 399, which is 397 + 1 trapping cycle + 1 cycle of testbench observation latency.
- Throughput ≈ Fmax / CPI ≈ **58 million instructions/s** (estimated, not measured on hardware).

## Limitations and future optimization opportunities

| Bottleneck | Likely fix | Phase |
|------------|-----------|-------|
| Fetch + load in one cycle | 5-stage pipeline (IF/ID/EX/MEM/WB); each stage holds a fraction of this path | 3 |
| LUT memories, large fan-out | Block RAM with registered read, used as pipeline registers | 3 |
| Hazards from pipelining | Forwarding + hazard detection to keep CPI near 1 | 4 |
| Register-file read in the middle of the path | Moves into ID stage | 3 |
| Long ALU → address → memory chain | Separate address adder / MEM stage | 3 |

Expected direction: a pipelined design should run much faster per cycle at a CPI slightly above 1. That claim must be verified against this baseline under the **same** constraint, tool version, and settings (see `configs/baselines/README.md`).

## Reproduce

```bash
make synth                                  # ~10 minutes; writes build/vivado/baseline/
cat build/vivado/baseline/summary.txt
```
