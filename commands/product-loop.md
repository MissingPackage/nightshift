---
description: One guarded iteration of an autonomous product-development loop (use as `/loop /product-loop`)
---

Continue the autonomous product loop for this project. Follow the loop-iteration skill exactly.

**Standing guardrails (non-negotiable for every iteration):**
- **Scope cap:** ONE feature-slice or fix per iteration, small enough to implement AND verify (skill: done) within the iteration. Roadmap-scale choices about WHAT to build next come from `HANDOFF.md` §next-decidable / the tracker (Linear) — if neither names a next item, STOP and docket "roadmap ruling needed" instead of inventing features.
- **Protected paths:** never touch deploy/infra manifests, auth/consent flows, or migrations unless the iteration's tracker item explicitly says so. Anything under the cofounder's ownership (deploy repo, cluster apps) is read-only: docket, don't edit.
- **Branch & merge policy:** work on a feature branch per slice. NO merges to dev/main and NO pushes beyond the branch unless the goal text explicitly grants it. PR-ready is the target state; merging is a docket item by default.
- **Verification:** full gates (skill: done) each iteration — unit + integration (real Docker) + lint + conventions (domain events, factory pattern, docs procedure). Run the `consistency-sweep` agent whenever the slice introduced or extended a pattern; INCOMPLETE coverage blocks the slice from PR-ready.
- **Residue routing:** bugs/ideas found along the way → Linear/docket with one line each; never absorbed into the current slice.

**State machine, escalation levels, and the unattended test:** ORCHESTRATION.md §4. Goal spine: `.harness/goals/<slug>/` (§1).

**Each iteration:** re-anchor (HANDOFF, tracker, docket) → pick the one named next slice → implement → verify (done-report saved into the journal) → `loop-verifier` gate → refresh HANDOFF §next-decidable → digest to the user (3-6 lines: slice, evidence one-liner, next) → schedule or stop-by-design.

**Morning report:** the final digest of a night run additionally lists: slices completed (with branches/PRs), the full docket delta, and anything a human must do before the next run.

$ARGUMENTS
