---
name: loop-iteration
description: Use at the start of every /loop iteration and every autonomous work cycle — when resuming from a schedule wake-up, when a prompt says "continue the loop / continua il loop", or when about to schedule the next iteration of long-horizon work.
---

# One Loop Iteration

## Overview

One iteration moves the project's objective, or learns why it cannot. The unit of control is
the gap between the objective and the current value, read from the map (`HANDOFF.md`). There is
no contract to conform to and no verifier to satisfy inside the iteration: the control is the
cheap test that can kill a lever. Protocol: `ORCHESTRATION.md` §2-3.

## The iteration

1. **Re-anchor from the map, not from memory.** Read `HANDOFF.md`: head line (objective, current,
   gap), levers, fog, landmines. If the conversation and the file disagree, the file wins. If the
   head line has not moved in the last two sessions, the first step is to say why, not to work.
2. **Take the biggest gap.** One lever family per iteration. Before writing code, one pass outside:
   who has already solved this (papers, repos, the framework's docs, a reference implementation)?
   Add what you find to the lever list with the expected gain.
3. **List the levers, then kill them cheaply.** For each candidate write in one line: what it is,
   the expected gain, the test that can kill it in minutes (a micro-bench, a 10-turn chat, a
   smoke run, a unit test). Include combinations, not only single levers. Run the kill tests.
   Winners stay; the dead get their number and the reason in one line. Never a long run inside
   the iteration: certification belongs to the boundary, on final code.
4. **Implement the winners directly.** Delegate only what is parallel or bulk (exclusive files,
   explicit model: opus or sonnet). Fix what you meet on the path: a defect or an old form next
   to a better one is repaired in the same pass, never fenced or logged for later. Values we set
   ourselves are knobs: question them before treating them as limits. Read the tool before
   spending it: any operation costing more than five minutes of machine gets its flags from
   `--help` or the source first.
5. **Decide, don't escalate.** Only four kinds of question go to the user: irreversible, spend
   (money or >30 min of machine), public, change of objective. In chat, one line each with the
   default applied on a bare "ok", at most three. Everything else: decide, execute, write it in
   the map. If you would proceed anyway before an answer, it was not a question.
6. **Redraw the map and log the experiment.** Update `HANDOFF.md` in place (head line, levers,
   fog, landmines). Append to `.harness/tried.md` three lines per experiment: lever, result with
   the number, verdict (keep / dead / park). Nothing else is written: no journal, no docket.
7. **Digest.** Three lines for a reader on a phone who has never seen the project: the objective
   was at X and is now at Y; what was tried and what it said; what moves it next. No IDs, no
   sigle, every project term explained in half a line or dropped.
8. **Schedule or stop, as the LAST action of the turn.** More work → `ScheduleWakeup`
   (self-paced). Two iterations without the gap moving → change lever family; four → stop with
   `ScheduleWakeup{stop:true}` and say what you suspect is wrong (objective, ceiling, method).
   Remaining work all in the four kinds → stop by design, decisions in chat. A turn that ends
   without a schedule or a declared stop has killed the loop; the Stop hook `loop-guard` refuses it.

## Common mistakes

- Measuring before acting: an hour of certification on a lever that a five-minute test would
  have killed. Certify at the boundary, on final code.
- Escalation as insurance: asking a question whose answer you would not wait for.
- Fencing instead of fixing: a guard, a debt comment or a watching test around a defect you
  could repair in the same pass.
- Treating a historical value (an arena size, a cap, a bar) as a law.
- Journal-only progress: an iteration that rewrote documents and moved no number.
- Delegating a one-file change to a workflow: a workflow is for a multi-file build with a spec.
- Ending the turn "in loop" without scheduling.
