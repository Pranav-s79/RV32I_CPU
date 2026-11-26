# 08. FPGA Synthesis and Timing

## Synthesis and implementation are different

Synthesis converts RTL into a netlist of device resources: LUTs, FFs, RAMs,
and other primitives. Implementation places those resources and routes the
wires. Timing after implementation includes effects of placement and routing;
pre-synthesis estimates do not.

Resource reports answer questions such as how many LUTs and FFs the design
uses. Timing reports answer whether constrained paths meet their required
arrival times. Neither report proves the ISA behavior; simulation and other
verification do that.

## Clock constraints

An XDC clock constraint gives the timing engine a target period and identifies
the clock port. If the constraint is missing or incorrect, timing numbers are
not meaningful. Input/output delays also matter for a board-level top. The
current B001 methodology uses a fixed 10 ns reference period for a controlled
comparison; see [`../baseline.md`](../baseline.md).

## WNS, slack, and Fmax

For a setup path, slack compares the required arrival time with the actual
arrival time. Positive slack means the data arrived early enough for that
constraint. Negative slack means it missed the target by that amount.

**WNS** is the worst negative slack over checked setup paths. Under a fixed
methodology, one can estimate the clock limit from a run with period `T` and
WNS `W` as approximately:

```text
estimated_min_period ≈ T - W
estimated_Fmax ≈ 1 / (T - W)
```

This is an estimate based on the tested design and flow. It is not a physical
measurement on the FPGA. A period sweep with implementation pass/fail checks
is a stronger way to identify a timing boundary.

## Reading the critical path

Start with the actual worst path in the timing report. Identify its startpoint,
endpoint, logic cells, routing contribution, and fanout. Common CPU paths
include register read to ALU to writeback, load address through memory to
writeback, and branch comparison through PC selection.

Optimize only after you know the path. Reducing an unrelated expression may
not affect Fmax and can make area or correctness worse.

## Fair comparisons

To compare two architectures, keep the FPGA part, tool version, constraints,
synthesis/implementation settings, and benchmark image consistent. Save the
commit and report files for each result. Report Fmax together with CPI when
comparing processors; a faster clock alone does not guarantee more completed
instructions per second.

## Check your understanding

1. Why can placement make a design slower than synthesis estimates suggest?
2. What does negative WNS tell you under the specified clock target?
3. Why is `T - WNS` only an estimate of the limiting period?
4. What must remain fixed for a fair baseline comparison?

## In this repository

Use [`../baseline.md`](../baseline.md),
[`../../configs/baselines/B001_single_cycle.md`](../../configs/baselines/B001_single_cycle.md),
and [`../../scripts/vivado/synth_baseline.tcl`](../../scripts/vivado/synth_baseline.tcl).
