---
description: Scheduled weekly maintenance — stale maps, hook health, memory hygiene, one adversarial audit
---

Weekly maintenance of the harness (scheduled via tools/install-schedules.sh; the agent does the
checks, only decisions reach the user). Write the report in the user's own language, plain
language, titles not IDs; only these instructions are English.

1. **Stale maps.** Every `HANDOFF.md` under the projects root: head line unchanged for more than
   two weeks, or over 150 lines, or section 4 (decisions) with more than three items. One line
   per project with a proposal: reopen / archive / ask.
2. **One adversarial audit.** Pick ONE commit of the week at random on a shared branch
   (`git log --oneline --since="1 week ago" | shuf -n1`, no cherry-picking) and launch
   `adversarial-reviewer` (model opus) to refute it against the map's objective. A confirmed
   defect goes to the top of the next morning report.
3. **Hook health.** `bash tests/run.sh` in the harness repo, plus the live checks: session-anchor
   on a project emits the map head; loop-guard blocks a close without a schedule; push-guard
   decides per policy; a polling fixture ("done?") makes firefight-catch respond. A silent hook
   is an incident.
4. **Memory hygiene.** Per project auto-memory: entries that restate a rule now in CLAUDE.md,
   entries contradicted by a later one, entries about files that no longer exist. Propose the
   pruning diff; do not apply it.

Report ≤ 30 lines, each section closed by "no action" or by the decision to take.
