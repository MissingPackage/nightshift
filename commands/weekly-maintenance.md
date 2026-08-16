---
description: Scheduled weekly maintenance — triage, agentic adversarial audit, hook health, memory hygiene (C10)
---

Weekly maintenance of the harness (ruling C10, 2026-08-12: runs scheduled via
tools/install-schedules.sh; the old "100% PI time" ritual was never executed —
0 out of 3 weeks. The agent does the checks; only the decisions reach the user).
Write the report itself in the user's own language — user surface, "match the user's language" rule; only these
instructions are English. Plain language, titles not IDs. Order:

1. **Cross-project docket triage.** Every `.harness/goals/*/docket.md` under ~/Projects
   (skip `STATUS: PAUSED` goals): open entries with age in days, oldest first.
   For each a proposal: decide now / can wait / kill — with the why in ≤15 words.
   The proposals feed the decision batch of the next coffee report.
2. **Agentic adversarial audit** (replaces the PI's spot-audit — ruling C10: he does not
   read diffs, by choice). Pick ONE PASS-verified slice of the week at random
   (`git log --oneline --since="1 week ago" | shuf -n1`, no cherry-picking) and launch
   an independent adversarial agent (adversarial-reviewer) with a mandate to REFUTE the
   PASS: diff vs done-when vs evidence. If the audit contradicts the verifier: harness
   incident — tighten the verifier the same day, and at the top of the next coffee
   report.
3. **Hook health** (10s each). `bash tests/run.sh` in the harness repo; plus the live
   type-tests: "fatto?" fixture → firefight-catch responds; push fixture → push-guard
   decides per policy; session-anchor on the repo → emits HANDOFF §1. A silent hook
   = incident.
4. **Memory and surface hygiene.** HANDOFF over 80 lines per touched project;
   goals with all phases done but not archived; auto-memory MEMORY.md with dead
   entries; **GLOSSARY.md**: entries whose referent no longer exists (grep the term in
   code/docs: zero hits = removal candidate) and terms coined in the week's digests
   that are NOT in the glossary; **pruning skill sediment**: references to files or IDs
   a fresh reader cannot resolve — an installed skill must stand on its own. Propose
   the pruning diff, do not apply it.
5. **Eval drift** (if evals/ exists). Run and compare with the latest RESULTS: a
   dropped section is an incident; one stuck at 100% for 3+ weeks calls for harder
   scenarios.

Report ≤ 50 lines: one section per point, each closed by "nessuna azione" (no action)
or by the exact decision (which flows into the next morning's frontier batch).
