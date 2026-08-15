# Cookbook — ten workloads on the same rails

Each recipe names four things: **when** it applies, the **moves** (exact commands, skills,
agents), the **judgment that stays yours**, and the **failure path** — because a recipe that
only describes the happy case is a demo, not a recipe.

Shared substrate everywhere: the `ORCHESTRATION.md` state machine, files-as-spine, the
done-report, the docket. Your typing budget per recipe is the goal text and the rulings.
Nothing else.

> Every command, skill and agent named below is checked by `tests/check-references.sh` to
> resolve to a real file in this repository. A cookbook that points at things which do not
> exist is worse than no cookbook.

---

## 1. Nightly feature loop

**When:** feature or fix work you want done while you sleep.

**Moves:** *Evening* — `/goal-brief <idea>` → edit the draft, resolving every `[ASSUMED]` →
`/goal` → `goal-setup` writes PHASES.md → you approve `plan-check` (60 seconds) →
`/loop /product-loop`. *Overnight* — each iteration runs the unattended test
(`ORCHESTRATION.md` §4); slices land branch-only; `loop-verifier` and `consistency-sweep` gate
each one; digests accumulate.

**You rule on:** plan-check; the morning docket (merges, authority edges); one spot-audit diff
if you want one.

**If it breaks:** the no-progress breaker blocks the phase, and the loop either takes the next
independent phase or pauses with a notification. You never wake up to eight hours of retries on
one wedged step.

---

## 2. Research campaign

**When:** publication-shaped work with a thesis and work packages.

**Executable:** `workflows/research-campaign.workflow.js` — one work package per run:
schema-forced pre-registration → execution → independent grader → hand-back memo.

**Moves:** THESIS.md and AGENDA.md are yours to write → one `/goal` per work package, with
prediction-gating instead of plan-check → `/loop /research-loop`: pre-register the prediction →
execute → grade honestly against what you predicted → verifier → AGENDA §1 refresh → digest →
self-pace to the next.

**You rule on:** the docket — ontology admissions, framing, budget — through hand-back memos.

**If it breaks:** two dry iterations ⇒ hand back with both failure analyses attached, never a
third attempt. The loop **stops by design** when every remaining item needs a human ruling;
that is a correct ending, not a failure.

---

## 3. Greenfield build

**When:** a new product, site, or tool from zero.

**Executable:** `workflows/sdd-conductor.workflow.js` — spec → validated task graph → waves of
implement + adversarial review → integrate.

**Moves:** `brainstorming` → `spec-first` → you edit the spec → `goal-setup` (phases map onto
task groups) → subagent-driven development: per task, a brief with an explicit `owns:` set,
tool list and interface freeze → implementer → `adversarial-reviewer` round 1 → fix round →
re-review → integrate. `scout` after each milestone; `consistency-sweep` before shipping.

**You rule on:** the spec; interface freezes; ship / no-ship. Steering tokens are enough
mid-flight — "looks right, go" — because the contract is in the brief, not in the conversation.

**If it breaks:** a Critical finding blocks the task, not the build. A task blocked twice is
docketed with both review verdicts attached.

---

## 4. The 11pm firefight

**When:** something is broken NOW and you are typing angry.

**Moves:** paste whatever you have. `firefight-catch` injects the rails; `root-cause` runs:
hypothesis + evidence → the agent acquires observations with its own tools → one change →
verify against the original reproduction → done-report → residue to the docket.

**You rule on:** nothing mid-fix. You are the sensor of last resort only — if the agent can
read the log itself, it should.

**If it breaks:** a second failed fix on the same symptom auto-escalates to a full
investigation. There is no third patch.

---

## 5. Pattern migration / anti-slop

**When:** introducing or completing a convention across a codebase — event shapes, upserts,
error handling, logging.

**Executable:** `workflows/pattern-coverage.workflow.js` is the *sensor* (baseline count,
worklist, exceptions); `workflows/pattern-migration.workflow.js` is the *executor* that brings
non-compliant sites to the form the repo already has.

**Moves:** write the **machine gate first** (an architecture test) → run `consistency-sweep` or
the coverage workflow for the baseline (n/total plus the exact worklist) → executor briefs of
ONE pattern with the explicit site list → sweep to 100% or a justified exception → the gate
becomes merge-blocking in CI so the pattern cannot rot again.

**You rule on:** the invariant itself, and any justified-exception claim.

**If it breaks:** incomplete coverage blocks the merge mechanically. "Mostly applied" — the
pattern that exists at 30% of its sites and reads as done — stops being expressible.

---

## 6. Deploy to shared infrastructure

**When:** shipping images, manifests, or migrations to an environment other people depend on.

**Moves:** done-report green on the branch → build and push artifacts (a moving tag *and* an
immutable one) BEFORE any manifest change → the deployment controller picks it up → the agent
verifies through real sensors (logs, metrics, health endpoints) and reports the blast-radius
line → rollback path is re-pointing to the previous immutable artifact, never editing manifests
under pressure. `push-guard` plus the territory rules in your project's CLAUDE.md fence the
whole flow; diffs to repositories you do not own are proposed, never applied.

**You rule on:** every mutation to shared state, and anything owned by another team.

**If it breaks:** rollback is one re-tag. The incident goes into the project's CLAUDE.md the
same day — the rule being that anything which happens twice gets encoded.

---

## 7. Second-opinion review

**When:** a branch matters enough that one model's judgment should not be the last word.

**Executable:** `workflows/second-opinion.workflow.js` — independent lenses plus a refuter, and
a brief of the contested findings.

**Moves:** `adversarial-reviewer` (deep, artifact-verified) **plus** a review from a different
model family — a second family catches classes of gap the first is systematically blind to,
which is the entire reason to pay for two → merge both finding sets into the docket → fix
Criticals and Importants → `/pr-message` → you merge. Merge authority is never delegated.

**You rule on:** the contested findings. When two reviewers disagree, that disagreement is
precisely the part worth your attention.

**If it breaks:** reviewers deadlock ⇒ you get a ten-line brief of the disagreement, not two
full reports to reconcile yourself.

---

## 8. Weekly maintenance — the harness maintains the harness

**When:** once a week, twenty minutes, or after any harness incident.

**Invoke:** `/weekly-maintenance`.

**Moves:** docket triage across goals (rule, kill, or promote to your tracker) → verifier
spot-audit: one PASS re-checked by hand, because a verifier that has drifted will keep passing
things forever → a `mystery`-tagged docket item solved by hand this month → memory hygiene:
HANDOFF files still short, project CLAUDE.md current, dead goals archived → hook health: pipe a
fixture at each hook and confirm it still fires (ten seconds, and it is how you find the hook
that broke silently three weeks ago).

**You rule on:** everything here. This recipe is deliberately 100% human time — it is the
twenty minutes that keeps the other seven honest.

**If it breaks:** a harness bug found here (a stale HANDOFF, a drifted verifier, a silent hook)
is treated as an incident: encoded or mechanized the same day.

---

## 9. Taking over a codebase you did not write

**When:** the first goal on a repository someone else built — a legacy service, a handover, an
open-source project you just cloned.

**Moves:** `/goal-brief <the outcome you want>` and read the draft for its `[ASSUMED]` markers —
on an unfamiliar codebase those markers are the actual deliverable, because each one is a thing
the agent had to guess and you can now confirm or correct → `scout` on the area you are about to
touch, which returns ranked adjacent risks rather than a lint report → run the coverage sensor
(`workflows/pattern-coverage.workflow.js`) on any convention you intend to follow, so you adopt
the form the repo already uses instead of importing your own → then the normal loop.

Encode what you learn as you learn it: the project's own `CLAUDE.md` is where a discovered rule
goes the first time it costs you something. [`templates/CLAUDE.md`](../templates/CLAUDE.md) is
the starting shape.

**You rule on:** every `[ASSUMED]` marker, and which existing conventions are worth keeping.

**If it breaks:** a phase whose done-when you cannot state mechanically is a phase you do not
understand yet — split it or block it, rather than letting the loop grade itself on a promise.

---

## 10. Picking up a run that died

**When:** the session crashed, the laptop slept, or it is simply the next morning and you have
no memory of where it got to.

**Moves:** open a session in the project — `session-anchor` injects `HANDOFF.md` §1 before you
type anything, and lists the active goals with their open docket counts. Then read the goal's
own spine in `.harness/goals/<slug>/`: PHASES.md for what is DONE / READY / BLOCKED, the journal
for what was actually run, digests for the short version. Nothing here was in the conversation,
so nothing was lost with it.

Two mechanical checks before continuing: `./verify-install.sh` (a fix that exists in the repo
but was never installed does not run — that has cost two days once), and, for an unattended run,
`tools/loop-watchdog.sh`, which distinguishes a loop that is quietly working from one whose
session is dead and restarts only the second kind.

**You rule on:** whether the phase that was in flight resumes or gets re-scoped. A phase
interrupted mid-iteration is not automatically still the right phase.

**If it breaks:** if `HANDOFF.md` §1 no longer matches what the files say, trust the files and
rewrite §1 — `handoff-freshness` warns when the anchor has gone stale behind the commits, but
only the files are evidence.

