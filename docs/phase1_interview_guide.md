# Phase 1 Interview Guide

How to talk about this project honestly and well. Before using any line below, make sure you can explain it yourself, without notes.

## Authorship (say this accurately)

The Phase 1 RTL, testbenches, reference model, and scripts were written by an AI assistant (Claude) at your request, starting from your own PC and instruction-memory drafts. In an interview, say so plainly and focus on what you understand, verified, and decided. Interviewers will probe details; understanding is what survives that. Claims to avoid: "I designed every module from scratch." Claims that hold if you've studied the code: "I built and verified a single-cycle RV32I core, and I can walk you through every block and the critical path."

## 30-second summary

> I built a single-cycle 32-bit RISC-V RV32I processor in SystemVerilog, targeting a Zynq-7010 FPGA. It runs all 37 base-integer instructions plus FENCE, ECALL, and EBREAK, and it detects illegal instructions and misaligned or out-of-range accesses instead of ignoring them. I verified it at three levels: self-checking unit testbenches, assembly and C programs on the full system, and line-by-line trace comparison against an independent Python instruction-set simulator, in two different simulators. I also planted bugs to prove the tests catch them. On Vivado it uses about 2,000 LUTs, with an estimated Fmax around 58 MHz. The critical path is the load path through both memories, which sets up the pipelining work in the next phase.

## Key design decisions (and why)

| Decision | Why | Trade-off |
|----------|-----|-----------|
| Single-cycle first | Simplest correct design; gives a correctness and performance baseline | Clock period = slowest instruction (loads) |
| Asynchronous-read memories (LUT ROM/RAM), not BRAM | A single-cycle CPU needs instruction and load data in the same cycle; BRAM reads are registered | Small memories, slow, high fan-out; fixed by pipelining |
| Memories outside the core | Core can be measured alone; memory map lives in the SoC | Slightly more wiring at the top |
| Separate branch comparator and target adder | ALU stays simple; branch decision doesn't wait for the ALU mux | One extra 32-bit adder |
| Trap = halt with cause/PC/value outputs (mcause numbering) | No CSRs in RV32I base; still never silently ignores errors | Software can't recover from traps yet |
| Misaligned loads/stores trap | Allowed by the spec; much simpler hardware | Software must align data |
| Full-address decode with access faults | Prevents silent aliasing (e.g. `0x11000` wrapping to `0x10000`) | A few comparators |
| Synchronous reset; register file not reset | Xilinx-friendly; lets the register file map to LUTRAM | Registers start at 0 only from configuration |

## Questions you should be ready for

**Why is it called single-cycle, and what limits its speed?**
Every instruction completes in one clock. The clock must cover the slowest path: a load goes PC → instruction memory → register read → address add → data memory → extend → register write. Vivado measured that path at about 16.9 ns, 79 % of it routing.

**How do you handle x0?**
The register file ignores writes when `rd = 0` and also forces reads of register 0 to 0. Each mechanism is tested on its own; one of them alone is invisible to programs, which a fault-injection test exposed.

**How does sign extension work for loads and immediates?**
Replicate the sign bit: `{{24{b[7]}}, b}` for LB, and `instr[31]` for all immediates (RISC-V always puts the immediate's sign bit at instr[31]).

**Signed vs. unsigned?**
SLT/BLT/BGE use `$signed` comparisons; SLTU/BLTU/BGEU are unsigned; SRA uses `>>>` on a signed operand. ADD/SUB don't care, thanks to two's complement.

**Why does JALR clear bit 0?**
The spec says so. It lets software use addresses with bit 0 as a tag. If the result's bit 1 is set, the target isn't 4-byte aligned and the JALR itself traps.

**What does FENCE do in your design?**
Nothing, legitimately: one hart, strictly in order, no caches or store buffers, so every access is complete before the next begins.

**How do you know it's correct?**
Unit tests with hand-computed corner cases and independent reference functions; directed assembly programs; lockstep trace comparison with an independent ISS; two simulators; and 14 planted bugs, all caught. Gaps: no official compliance suite yet, no random instruction generation, no formal verification, not run on hardware.

**How would you make it faster?**
Pipeline it into 5 stages, move memories to block RAM (whose registered read becomes a pipeline register), then add forwarding and hazard detection to keep CPI near 1. Compare against this baseline under the same constraint and tool settings.

**What was the hardest bug?**
Answer from your own experience. Things that came up in this phase: a wrong expected value in a testbench (the test was wrong, not the design); simulator differences (Icarus unsupported casts; Windows xsim argument splitting and CRLF line endings).

## Numbers to remember (all measured, see `baseline.md`)

- ~2,054 LUTs (556 as distributed RAM), 47 FFs, 0 latches, 0 BRAM, full system post-route
- 1,079 LUTs, 101 FFs: core alone, post-synthesis
- WNS −7.194 ns at a 10 ns constraint → estimated Fmax ≈ 58 MHz
- Critical path 16.9 ns, 19 logic levels, ~79 % routing
- CPI = 1

## Limitations to state up front

No CSRs/interrupts/trap handlers; no compliance suite run yet; tiny LUT-based memories; programs can't use initialized data; not yet run on the physical Zybo; the reference model was written by the same AI that wrote the RTL (independent code, but not third-party like Spike or Sail).
