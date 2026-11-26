# 13. Experiments and Final Engineering Evidence

## A controlled experiment

A useful experiment changes one meaningful factor and measures its effect.
Before changing the design, name the question and prediction. Preserve the
baseline, test the new design for correctness, use the same workload and tool
flow, then compare results. If several factors change at once, it is hard to
know which caused the result.

For each result, save:

- source revision or commit;
- tool versions and exact commands;
- FPGA part and timing constraints;
- program image/workload;
- verification pass summary;
- timing and utilization reports;
- cycles, retired instructions, stalls, and relevant counters.

Use the experiment template in each phase's `experiments.md`. Never enter
placeholder measurements as if they were real results.

## The CPI stack

Average CPI gives one number but not the cause of lost cycles. A CPI stack
attributes cycles to categories such as load-use stalls, branch misprediction,
instruction-cache misses, data-cache misses, or other backpressure. Define
categories so each cycle is counted once; if several conditions overlap,
document which category owns that cycle.

```text
total cycles = useful/base cycles + categorized lost cycles
```

The measured total CPI is `total cycles / retired instructions`. Summing the
categories should reconcile with the measured cycle count under the chosen
convention.

## Fmax and CPI together

Approximate instruction throughput is `Fmax / CPI`. A pipeline may raise Fmax
but introduce stalls. A cache may lower average memory delay but consume area
or affect timing. State both clock and CPI, name the baseline, and explain the
workload when making a performance claim.

## FPGA versus board claims

Synthesis and timing reports show how a design is expected to behave on a
specified FPGA flow. They do not prove that it was programmed onto a board or
observed working. Say “synthesized and timed for XC7Z010” until a physical
board run has actually been completed and recorded.

The Zybo Z7-10 uses a Zynq processing system. DDR and the onboard USB-UART are
not automatically connected to a custom programmable-logic CPU. Board use
requires a deliberate memory and I/O integration plan.

## A strong project explanation

Be ready to describe:

1. the baseline and why it was built first;
2. the failure or bottleneck observed;
3. the design change and why it should help;
4. how correctness was verified;
5. the measured benefit and its cost in CPI, area, and timing;
6. what remains unsupported or unmeasured.

## Check your understanding

1. Why should a performance experiment change one factor at a time?
2. How can you check that CPI-stack categories sum to total cycles?
3. Why is Fmax alone not an overall processor-performance metric?
4. What evidence is needed before saying a design worked on the physical board?

## In this repository

See [`../baseline.md`](../baseline.md),
[`../../configs/baselines/README.md`](../../configs/baselines/README.md), and
the experiment template in [`../phase_0/experiments.md`](../phase_0/experiments.md).
