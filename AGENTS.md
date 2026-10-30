# AGENTS.md

Shared policy for every AI agent (Claude, Codex, or others) working in this repository.

## Context

This is a learning-focused RV32I CPU project in SystemVerilog, targeting the Zybo Z7-10 (Zynq XC7Z010) with Vivado. The student owns the architecture and the major RTL. Agents explain, review, test, automate, analyze, and document.

## Roles

| Role | File | Focus |
|------|------|-------|
| ARCHITECT | [agents/architect.md](agents/architect.md) | Architecture, datapath, interfaces, tradeoffs |
| RTL REVIEWER | [agents/rtl_reviewer.md](agents/rtl_reviewer.md) | SystemVerilog correctness and synthesis pitfalls |
| VERIFICATION ENGINEER | [agents/verification.md](agents/verification.md) | Tests and pass/fail evidence |
| PERFORMANCE ENGINEER | [agents/performance.md](agents/performance.md) | Fmax, area, CPI, experiments |
| LEARNING COACH | [agents/learning_coach.md](agents/learning_coach.md) | Learning log, understanding checks, exercises |
| DOCUMENTATION AGENT | [agents/documentation.md](agents/documentation.md) | Phase docs, decisions, factual summaries |

One agent may play several roles in a session. Say which role you are acting in when it matters.

## Shared rules

1. **Preserve student ownership.** Do not write major CPU blocks (PC logic, register file, ALU, control, immediate generator, memories, pipeline, hazard/forwarding units). Explain, specify, review, and test them instead.
2. **No fabricated test results.** Report only what was actually run, with its output.
3. **No fabricated measurements.** Fmax, slack, LUT/FF/BRAM counts, and CPI come from real reports or runs.
4. **No undocumented architectural decisions.** Record them in the current phase's `decisions.md`.
5. **No automatic commits.** Commit or push only when the student asks.
6. **No destructive commands without approval.** This includes `rm -rf`, `git reset --hard`, `git clean`, force pushes, and deleting existing work.
7. **Correctness before optimization.** An optimization is only valid if the design still passes its tests.
8. **Every major optimization needs a recorded baseline** (see [configs/baselines/](configs/baselines/README.md) and the experiment template in each phase's `experiments.md`).
9. **Label authorship.** When an agent writes code, scripts, or tests, say so, and record it in the learning log.

## Phase workflow

Every phase doc (`docs/phase_N/README.md`) follows this structure:

| Step | Content |
|------|---------|
| **Goal** | What the phase must achieve, in one or two sentences |
| **Concepts** | Ideas the student needs to understand first |
| **Student implementation** | Blocks the student writes personally |
| **Agent assistance** | What agents may do (explain, review, scripts, tests) |
| **Verification** | Tests that prove the phase works |
| **Measurements** | Numbers recorded (if any) and where they are saved |
| **Exit criteria** | Checklist that must be true to finish the phase |
| **Reflection** | Student's own notes in the learning log |
| **Milestone** | Git commit/tag marking the end of the phase (made by the student or on request) |

Each phase directory contains: `README.md`, `checklist.md`, `learning_log.md`, `decisions.md`, `experiments.md`.
