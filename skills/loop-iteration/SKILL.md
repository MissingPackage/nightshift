---
name: loop-iteration
description: Use at the start of every /loop iteration and every /goal work cycle — when resuming autonomous work from a schedule wake-up, when a loop prompt says "continue the loop / continua il loop", or when about to schedule the next iteration of long-horizon work.
---

# One Loop Iteration

## Overview

The unit of long-horizon work is one **re-anchored, verified, journaled** iteration. This protocol is generalized from a long-running research loop (45 iterations, verifier-gated, stopped by design when work became user-gated) — the shape that worked. Two axes were added after an autopsy in which a measure-only phase estimated at 1 iteration consumed 8 while the goal's objective never moved: **trajectory** (step 2/7) and the **escalation discriminant** (step 5). A loop can be perfect cycle-by-cycle and go nowhere.

## The iteration

1. **Re-anchor from disk, not from memory.** Read, in order: the loop's directive file(s), `HANDOFF.md`/`AGENDA.md` §"next decidable", the docket. If the conversation and the files disagree, the files win.
2. **Check the trajectory, then pick ONE decidable step.** Two checks from GOAL.md's objective and PHASES' estimates:
   - iterations consumed by the current phase vs its PHASES estimate — at **3x overrun, stop executing the row**: the decidable step becomes re-planning, presented to the user, not another conformant iteration;
   - has the objective metric moved in the last few iterations? Flat objective + a phase that only measures/documents = ask whether the phase still earns its place.
   Then pick the largest step you can finish and verify this iteration — not the most interesting one. If nothing is decidable without a user ruling → go to **Stop by design**.
3. **Execute** within the loop's standing constraints (scope caps, protected paths, budget — from the loop command file). Inside a goal, the PHASES row + its spec IS the plan: implement directly against the done-when. A phase that is a multi-task build runs via the `sdd-conductor` workflow — **declared in its PHASES row** (goal-setup writes that declaration; a build row without it is a row defect: docket it, don't improvise a planning chain). Never route a phase through the vendored writing-plans → subagent-driven-development chain: that is the feature-scale path outside goals.
   - **Feasibility before conformity.** Before executing a done-when, check the row is executable as written: parameters exist, it fits the hardware, the cells are non-degenerate. A row broken on the facts gets a "row is malformed" docket item BEFORE any spend — executing a known-degenerate contract to the letter is the bug, not diligence.
   - **Fix what you meet on the path — don't fence it.** A defect encountered while executing the row (an old form still in use where the repo already has a better one; a bug in code the row touches) is NOT out-of-scope: its removal is the real closure of the row. The fence — a guard, a declared-debt comment, a test that watches a known-bad state — passes every gate while rotting the codebase, and rigor spent on the fence makes it look like quality. Before fencing, answer one question: **does a working form already exist in this repo?** If yes, the fix is a port — delegate it to a subagent with an exclusive-files brief (pattern-wide: the `pattern-migration` workflow) and let the row's verify cover both. Docket it instead ONLY when the fix needs a ruling (it changes a contract) or exceeds the loop's budget — and then the entry carries the fix's estimated cost, not just the finding. Precedent (2026-08-14): a spec-limit violation got a 20-line debt comment, a hand re-verification, a guarding test and a docket item — all rigorous, all waste; the fitting form already lived in a sibling path and porting it was one subagent away.
   - **Read the tool before spending it.** Any operation costing >5 min of GPU/money/API: read the runner's parameters first (`--help`, grep the source) and record in the journal the EXACT command, with the flags that select what you believe you are measuring.
   - **Fresh context for re-orientation.** Above ~150k of context, extended Read/Grep re-orientation goes to a fresh subagent, not this session — measured: past that threshold, re-reading of already-read files jumps from 1.6% to 12-22% (context audit 2026-08-12).
4. **Verify before claiming.** Run the gates (skill: done). For research loops: grade the outcome against the pre-registered prediction. If the loop mandates an independent verifier, spawn `loop-verifier` and do not proceed on a FAIL — fix or docket it. The verifier brief includes the trajectory line: a flat objective across ~5+ iterations with only measure/document phases in flight is a **trajectory FAIL** even when each iteration passes.
5. **Decide vs escalate.** Before opening a docket question, write what you would do if no answer ever came. If that fallback matches your own recommendation, it is not an escalation — execute it and REGISTER it (decision taken, recorded, "no ruling needed"). Escalate only what you genuinely cannot take: money, root, the user's machine, the objective function, an authority grant. An escalation goes **in chat, phone-readable**: the question in one line + what not-deciding costs + the default applied on a bare "ok". Several decidable questions → ONE batch (frontier style): numbered, one idea each, ordered by importance with a recommended answer — partial replies are the norm; dependent questions wait for the next round. Cite items and phases by their **title**, never a bare ID. The docket entry is the *record* of the decision, not the medium — and the user says "in standby / non ora / lo riprendiamo poi" about a goal, you write `STATUS: PAUSED (reason, date, quote)` in its GOAL.md without asking (a chat decision that never reaches disk becomes indistinguishable from abandonment). Observable self-test: if you would proceed before the answer arrives, it was a disclaimer, not a block — don't send it.
6. **Journal.** Update the journal/diary (append) and refresh HANDOFF/AGENDA §next-decidable (in place). Log NEW-scope findings (features, ideas, anything that is not closing the current row) to the docket — never pursue them mid-loop; a defect met on the path is step 3's business (fix via subagent, don't fence), not a docket default. The journal is the agent's working memory and may stay dense. If this iteration coined a project term — a name an outsider could not guess — add its half-line to the project `GLOSSARY.md` now: the cost of a term is paid when it is invented, not when someone is confused by it.
7. **Digest to the user.** FIRST line = the trajectory: the goal's objective was at X, is now at Y, the next thing that moves it is Z. Then 3-5 lines: what was done, what the results say, what's next — written **for a reader who has never seen this project**: every project term explained in half a line or dropped, no bare sigla. Write it even when the user is asleep — it's the morning report.
8. **Pre-limit hand-back.** Before any long operation (subagent fan-out, multi-run eval,
   a fresh phase), ask whether the session's remaining limits can carry it. If the doubt
   is concrete: clean hand-back NOW — commit verified work, digest, HANDOFF refresh — and
   stop on a clean boundary. One fewer iteration beats a half-finished merge; the next
   run resumes from disk with no human 'continue' (precedent: the 2026-07-10 insights report).
9. **Schedule or stop — as the LAST action of the turn.**
   - More decidable work → schedule the next iteration (ScheduleWakeup) as the **final tool call**, self-paced: shorter when momentum is high, longer when waiting on external state. A turn that ends with a digest but neither a schedule nor a stop declaration has silently killed the loop — that is a bug, not a pause, and the Stop hook `loop-guard` refuses the close.
   - Work exhausted or user-gated → **Stop by design**: declare it with `ScheduleWakeup{stop:true}`, say exactly why in the digest, put the open decisions in chat (phone format, step 5), do NOT idle-loop or invent scope.
   - Same step failed twice → stop and docket it with the two failure analyses. A loop that retries the same step forever is a bug.
   - The bookkeeping is mechanical, not yours: a PostToolUse hook records every ScheduleWakeup in `.harness/loop-state.json`, and an external watchdog (tools/loop-watchdog.sh, on a timer) revives loops whose wake-up died with the process. Your only duty is the call itself.

## Stop conditions (any one suffices)

- Every remaining item needs a user decision (each already presented in chat, phone format).
- Budget/scope cap from the loop definition reached.
- Two consecutive iterations produced no verified progress.
- The directive files are contradictory or stale beyond safe interpretation → say so, stop.

## Common mistakes

- Deciding docket items yourself because the user is away (anti-ratcheting: ontology/architecture/merge-policy decisions are user territory).
- **Escalation as insurance**: opening a docket question whose outcome you then execute anyway. If you can write a recommendation, you have decided — register it instead.
- Growing scope when the goal feels "almost complete" — completion pressure invents features. New scope goes to the docket.
- **Fencing instead of fixing**: wrapping a defect met on the path in a debt comment + guarding test because "don't widen scope". That rule exists against invented features, not against removing defects the row already touches — the fence is more code than the fix, survives every review, and no gate ever flags it (step 3).
- Journal-only progress: an iteration that only rewrote documents twice in a row counts as "no verified progress".
- Trusting conversation memory after compaction — re-anchor from disk every single iteration.
- Re-planning a phase: invoking writing-plans on a PHASES row because it "looks feature-sized" — every row is feature-sized by construction (1-4 iterations), so that test always fires and buys a plan document instead of code. The row's done-when is the plan; brainstorming's scale fork governs its own exit, not phase execution.
- Ending the turn "in loop" without scheduling — the loop only exists if the next wake-up is scheduled or the stop is declared (step 9).
