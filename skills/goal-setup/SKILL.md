---
name: goal-setup
description: Use on iteration 0 of any /goal — when a goal has just been set, when GOAL.md exists without PHASES.md, or when a goal's phase decomposition must be rebuilt after a re-scope ruling.
---

# Goal Setup (iteration 0)

## Overview

Turns a goal contract into a loop-runnable spine. Runs once per goal (or after a re-scope
ruling). Protocol context: `~/.claude/ORCHESTRATION.md` §2 (installed alongside the skills;
in this repo it sits at the root).

## Steps

1. **Scaffold** `<project>/.harness/goals/<slug>/` with `GOAL.md` (the contract — if the goal
   text isn't in contract shape, run it through the goal-brief structure first and mark
   inferences `[ASSUMED]`), plus empty `journal.md`, `docket.md`, `digests.md`.
   **`GLOSSARY.md`** at the project root: optional to start, **required once the project
   coins its own terms** (a name whose meaning a competent outsider could not guess). It
   serves the AGENTS and the next session — it does NOT license jargon toward the user,
   whose surfaces stay plain-language regardless. Shape, deliberately minimal:

   ```
   # GLOSSARY — <project>
   <term> — <half a line: what it is, in plain words>. <where it lives, if code>
   <term> — ... ⚠ collides with <other term>: <the distinction in one clause>
   ```

   A term either pays rent here or gets renamed/dropped. Collisions get the ⚠ line: two
   things called the same name is the failure this file exists to prevent. Maintained at
   two points, never on a schedule of its own: a term coined mid-iteration is added in the
   same iteration (loop-iteration step 6), and weekly-maintenance flags entries whose
   referent no longer exists.
2. **Decompose** into `PHASES.md`. Every phase row must be loop-runnable:
   - mechanical done-when (a verifier can grade it tonight);
   - **feasibility verified at write time**: a done-when enters the table only
     after checking it is executable as written — parameters exist, it fits the hardware,
     no cell is degenerate by construction. The precedent: a merge gate demanded 9
     measurements of which 6 were no-ops and 1 physically impossible, and the agent
     discovered it by executing them;
   - **objective link**: each row names which GOAL.md objective metric it moves
     (roughly how much), or declares itself a quality gate. Count the gates — a plan that is
     mostly gates photographs the state instead of improving it;
   - **no free debt branch**: a done-when of the form "either X, or declare the debt" prices
     its branches asymmetrically — declaring closes the row tonight, fixing opens work of
     unknown size — so an executor optimizing for "row closed" picks debt every time. Such a
     row enters the table only if the debt branch requires two facts AT declaration time:
     the estimated cost of the fix, and the answer to "**does a working form already exist
     in this repo?**" — an existing form makes the fix a port and the debt inexcusable.
     Precedent (2026-08-14): a hardware-limit debt was declared with full rigor — arithmetic,
     re-verification, guarding test — while the fitting form already lived in a sibling path
     of the same repo;
   - **vehicle declared**: a row that is a multi-task build states
     `sdd-conductor` in the row itself — that is what loop-iteration reads at execution, and
     the plan-check approval then covers the invocation. Rows without it default to direct
     implementation; the vendored writing-plans chain is never a phase vehicle;
   - authority ⊆ GOAL.md's grant — a phase needing more is created with status `blocked` and a
     docket entry (docket-born);
   - sized 1-4 iterations (bigger → split); the estimate is not decoration — loop-iteration
     stops the row at 3x overrun;
   - sliced **vertically** where the work allows: a build row cuts through the layers and is
     demonstrable on its own, never a layer-phase ("all the schemas, then all the APIs");
     wide refactors go expand–contract (new next to old, migrate in lots, delete), not
     forced into fake slices;
   - `parallel-group` only with disjoint `owns:` path sets; otherwise sequential.

   ```
   | # | phase | done-when (mechanical) | authority delta | owns | status |
   |---|-------|------------------------|-----------------|------|--------|
   | 1 | ...   | `pytest tests/... green` + artifact X exists | none | apps/server/src/... | ready |
   ```
3. **Wire the pointer**: HANDOFF.md §1 → this goal, phase 1.
4. **Gate**: product goal → append `plan-check` to docket.md and STOP (the user approves
   PHASES.md before iteration 1 — the "show me the file before executing" gate). Research
   goal → no plan-check; predictions files gate execution instead.
5. **Digest**: 3-6 lines — phases, first target, what's docket-born.

## Common mistakes

- A done-when that needs human eyes ("looks right") — rewrite until mechanical, or split the
  human part into a docket item.
- A measurement matrix nobody test-fit before making it a merge gate — degenerate cells get
  executed for conformity and committed as if they meant something.
- Decomposing to activity ("work on auth") instead of outcomes ("login round-trip test green
  against local ory mock").
- Silently widening authority because a phase "obviously" needs it — that's docket-born, by design.
- A done-when offering "or declare the debt" with no price attached — the debt branch gets
  chosen by default, not by judgment (see "no free debt branch" above).
- Re-decomposing mid-goal without a ruling: PHASES.md changes after iteration 0 only via docket.
