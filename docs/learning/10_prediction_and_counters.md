# 10. Branch Prediction and Performance Counters

## Measure before predicting

Before changing branch behavior, count cycles, retired instructions, branches,
taken branches, and mispredictions. Optional stall/flush counters help explain
why CPI differs from 1. Define precisely when a counter increments and whether
it resets with the core.

Useful metrics:

```text
CPI = cycles / retired instructions
branch accuracy = correct predictions / predictions
mispredictions per 1,000 instructions = 1,000 * mispredictions / retired instructions
approximate instructions per second = Fmax / CPI
```

Always report the workload and configuration with the number. CPI from a
short loop is not a universal property of the processor.

## Two-bit branch history table

A **branch history table (BHT)** stores a small state per index derived from
the branch PC. A common design uses a 2-bit saturating counter:

| State | Prediction | On taken | On not taken |
|-------|------------|----------|--------------|
| `00` strongly not taken | not taken | `01` | `00` |
| `01` weakly not taken | not taken | `10` | `00` |
| `10` weakly taken | taken | `11` | `01` |
| `11` strongly taken | taken | `11` | `10` |

The high bit supplies the prediction. Saturation prevents one unusual branch
outcome from completely reversing a stable pattern.

## Branch target buffer

A **branch target buffer (BTB)** stores target addresses for recently seen
branches and jumps. The BHT answers “taken or not?”; the BTB answers “where
to fetch if taken?” Entries need a valid/tag check so an unrelated PC that
collides at the same index does not use a stale target.

## Update and recovery

Prediction happens before the branch resolves. When EX determines the actual
outcome, update the predictor and compare actual versus predicted next PC. A
misprediction redirects fetch and flushes younger instructions. Predictor state
must be updated exactly once for each resolved branch, including when several
branches are in flight in a more advanced design.

## Tradeoffs

A predictor may reduce flushes and CPI but costs LUTs, FFs, and possibly BRAM.
It can also add logic or fanout to the fetch path and lower Fmax. Compare
`Fmax / CPI`, not accuracy or clock rate alone. Use the same workloads and
measurement setup for predictor-off and predictor-on configurations.

## Check your understanding

1. Why are two counter bits more stable than a one-bit last-outcome predictor?
2. What information does a BTB add beyond the BHT?
3. Why can predictor accuracy rise while total performance gets worse?
4. Why should a misprediction counter increment at branch resolution rather
   than at prediction time?

## In this repository

The design is planned for a later milestone. Record the interface and
configuration in its phase decisions before implementation.
