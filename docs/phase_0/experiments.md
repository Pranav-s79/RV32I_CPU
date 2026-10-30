# Phase 0 Experiments

No experiments in Phase 0.

## Why this template matters

From Phase 6 on, **every performance or area optimization must be written up with the template below**. This keeps claims honest: each one has a baseline, a verified change, and before/after numbers measured under the same conditions. See [`agents/performance.md`](../../agents/performance.md) and [`configs/baselines/`](../../configs/baselines/README.md).

Copy the template into the current phase's `experiments.md` and number experiments in order (001, 002, ...).

---

## Template

```markdown
# Experiment XXX — Name

## Question
What are we trying to find out?

## Hypothesis
What do we expect to happen, and why?

## Baseline
Baseline ID (configs/baselines/...), design version (git commit), and the measured numbers.

## Change
Exactly what was changed (files, commit).

## Verification
Which tests were run after the change, and their results. The design must still be correct.

## Results
| Metric | Before | After | Change |
|--------|--------|-------|--------|
| Fmax (MHz) | | | |
| WNS (ns) | | | |
| LUTs | | | |
| FFs | | | |
| BRAM | | | |
| CPI | | | |

Links to the source reports in results/.

## Conclusion
Did the hypothesis hold? What did it cost?

## Follow-up
Next questions or experiments.
```
