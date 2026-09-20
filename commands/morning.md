---
description: The coffee report — cross-project map deltas, arrives on its own (scheduled)
---

Assemble the morning report across all projects (runs scheduled via
tools/install-schedules.sh; the user reads it from the app over breakfast). Write the report
in the user's own language, plain language: every project term explained in half a line or omitted, things cited
by title never by ID. Read-only. Order:

1. **Maps.** For every project under ~/Projects with a `HANDOFF.md` changed in the last 24 hours:
   ONE line per project — the head line now vs yesterday (objective, value, gap). Numbers from
   the map and the tail of `.harness/tried.md`, not reconstructed.
2. **The night.** For each project with wake-ups after 23:00 (`.harness/loop-state.json` and
   `~/.claude/loop-watchdog.log`): what was tried and what it said, from tried.md, two lines per
   project. Loops that died or were revived by the watchdog: say it first.
3. **Decisions.** All items in the maps' section "Decisions for the user" (§4), across projects, in
   ONE batch: numbered, one line each with the default. Never more than six.
4. **One line of health** only if there is something to say: a map over 150 lines, a map whose
   head line has not moved in two sessions, a silent hook, a timer that did not fire.

Total output ≤ 30 lines. If nothing moved and there are no decisions: three lines and close.
