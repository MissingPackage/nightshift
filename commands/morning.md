---
description: The coffee report — cross-goal aggregate, arrives on its own (scheduled, C10)
---

Assemble the AGGREGATED morning report across all projects (ruling C10, 2026-08-12: runs
scheduled via tools/install-schedules.sh, no longer a ritual the user invokes — they read
it from the app over breakfast). Write the report itself in the user's own language — user surface,
"match the user's language" rule; only these instructions are English. Plain language: every
project term explained in half a line or omitted; items and phases cited by TITLE, never
the bare ID. Read-only: decisions remain his. Order:

1. **Trajectories.** For every project under ~/Projects with active `.harness/goals/`
   (skip goals with `STATUS: PAUSED`): ONE line per goal — objective, distance now vs
   yesterday, what moves it next. Numbers from the tail of `digests.md`, not
   reconstructed.
2. **The night.** The digests.md entries after the last report: what the autonomous work
   produced, 2-3 lines per goal, most recent last. Loops dead or revived by the watchdog
   (~/.claude/loop-watchdog.log): say it first, it is the first thing he wants to know.
3. **Open decisions, frontier format.** All pending decisions cross-project in ONE
   batch: numbered, one idea per question, ordered by importance, each with options and
   a recommended answer + cost of not deciding. Partial answers are the norm; he replies
   in chat, the agent transcribes into the record (docket). Never more than ~6: the rest
   wait for the next round, mention them only as a count.
4. **One line of health.** Active timers, HANDOFF over 80 lines, silent hooks — only if
   there is something to say.

Total output ≤ 40 lines. If the night produced nothing and there are no decisions:
say so in 3 lines and close — a long empty report is worse than no report.
