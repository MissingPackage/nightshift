---
description: One iteration of an autonomous research loop (use as `/loop /research-loop`)
---

Continue the autonomous research loop for this project.

Follow the loop-iteration skill exactly. For this iteration:

1. Re-anchor from disk: the PI directive files referenced in `research/AGENDA.md` (or `HANDOFF.md`), then AGENDA §1 "next decidable", then the PI docket.
2. Execute the single next decidable research step. Standing constraints: pre-register the prediction in `research/predictions.md` BEFORE any `--execute`; dry-run and show cost estimates before real API spend; hard-stop and docket if projected spend exceeds the session budget in CLAUDE.md.
3. Before scheduling the next iteration, spawn the `loop-verifier` agent with your claimed outcome. On FAIL: fix if decidable this iteration, otherwise docket and stop.
4. Grade the outcome against the pre-registered prediction — honestly. Negative and null results are recorded with the same care as positives ("failures are data").
5. Update: journal (append), AGENDA §1 (refresh in place), docket (append PI-gated items).
6. Send the digest: 3-6 lines — what was done, why, what the results say, what's next.
7. Schedule the next iteration (self-paced) — or STOP BY DESIGN if all remaining work is PI-gated, stating the docket items that need rulings. Never invent scope to keep the loop alive.

State machine and escalation semantics: ORCHESTRATION.md §4; goal spine (multi-phase research goals): §1-2.

$ARGUMENTS
