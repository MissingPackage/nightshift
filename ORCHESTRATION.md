# ORCHESTRATION — goals → loops → rulings

> The autonomy layer: how the pieces chain so work proceeds by goals and loops instead of
> prompts. Design invariant: **the deliberate voice is the interface; the 11pm voice is an
> input the mechanisms catch** (hook `firefight-catch`), so the worst sessions ride the same
> rails as the best ones. Files are the spine; conversations are disposable.

## 1. The spine (per goal)

```
<project>/.harness/goals/<slug>/
  GOAL.md      # the contract (/goal-brief output): DONE-WHEN, EVIDENCE, AUTHORITY, CONSTRAINTS
  PHASES.md    # ordered decomposition; one row = one loop-runnable phase (see §2)
  journal.md   # append-only work log (evidence snippets, done-reports)
  docket.md    # decisions pending; the loop appends, ONLY the user resolves (inline ruling + date)
  digests.md   # per-iteration 3-6 line digests; the morning report is the tail since the last ruling
```

The project root keeps exactly one `HANDOFF.md`; its §1 "next decidable" points at the active
goal and phase. Cross-goal state lives ONLY there — goals never read each other's directories.
That isolation is what makes a stuck goal non-contagious.

## 2. /goal → phases (decomposition)

Iteration 0 of every goal runs skill `goal-setup`: read GOAL.md → write PHASES.md, where every
phase must be **loop-runnable**:

1. **Mechanical done-when** — a command or artifact a verifier can check. Not "the API is
   clean"; "`pytest tests/api` green and `openapi.json` validates".
2. **Authority ⊆ the goal's grant**, with any excess marked `docket-born`: the phase exists but
   starts BLOCKED, so the decomposition can name work the goal has no authority to do without
   silently doing it.
3. **Sized to 1-4 iterations.** Bigger ⇒ split. The no-progress breaker in §4 punishes oversized
   phases by design.

Phases are sequential by default. `parallel-group: <n>` is allowed only with disjoint `owns:`
path sets — anything else serializes. Exclusive file ownership per parallel agent is the
condition that makes concurrent work safe; without it, two agents edit the same file and the
merge is a coin flip.

The decomposition is itself work product. Iteration 0 ends with a digest and, for **product**
goals, a `plan-check` docket entry: the user approves PHASES.md before iteration 1. It is a
60-second read, and it is the same gate as "stop and show me the file before executing".
**Research** goals skip plan-check and are prediction-gated instead — the agenda drives, and
each work package pre-registers what it expects to find before it runs.

## 3. Loop chaining and phase hand-off

One `/loop` instance drives the whole goal. Each iteration = skill `loop-iteration` with
"current phase" = the first row in PHASES.md that is READY.

Phase exit is a ritual, not a vibe: `loop-verifier` PASS on the phase's done-when → PHASES.md
row updated → `done` report + HANDOFF §1 refresh + digest. The next iteration re-anchors from
disk and simply finds the next READY row. **Chaining needs no memory of the previous phase
beyond what the ritual wrote** — which is the property that lets a loop survive context loss,
a crash, or a machine reboot.

Goal exit: all rows done → one final verifier pass against GOAL.md's DONE-WHEN (not against
the phases — this is what catches sum-of-parts ≠ whole) → `GOAL-REPORT.md` in done-report shape
at goal scale → notification → loop ends. A loop that ends any other way must say which state
in §4 it died in.

## 4. State machine (exact semantics)

```
Phase: READY → RUNNING → VERIFYING → {PASS → done | FAIL → RETRY | FAIL² → BLOCKED}
Goal:  ACTIVE → {DONE | PAUSED → (ruling) → ACTIVE | KILLED}
```

| Trigger (concrete) | Level | Action |
|---|---|---|
| verifier FAIL #1; transient tool error | **L0 retry** | one retry, **a new hypothesis is required in the journal** — a retry with the same plan is forbidden |
| out-of-scope finding; ambiguity with a safe default | **L1 docket + continue** | record `[ASSUMED]` in the journal + a docket entry; work proceeds |
| authority edge hit (merge, protected path, new dependency, schema or public-API change, anything owned by another team); verifier FAIL #2; budget ≥80% | **L2 docket + block phase** | phase → BLOCKED; the loop takes the next READY phase if one exists |
| secrets or destructive operation required; budget 100%; directives contradict; a second phase blocks; **no-progress breaker** | **L3 pause goal + notify** | goal → PAUSED; notification with the docket delta; the loop stops by design |

**No-progress breaker:** two consecutive iterations on the same phase without a *verified*
delta (verifier-graded — journal-only churn counts as none) ⇒ BLOCKED at L2, and PAUSED at L3
if it was the only READY phase. This is the guard against an overnight loop burning until
morning on one wedged step.

**The unattended test** — the concrete routing rule. A step runs without the user iff ALL five
hold:

1. **Reversible** — branch-local; no push beyond the goal's branch; no external side effects
   outside the goal's allowed list.
2. **In-authority** — within GOAL.md's grant; touches no gated item (§5, left column).
3. **Mechanically verifiable** — a gate or verifier can grade it tonight. If "done" needs human
   eyes, it is a docket item, not a step.
4. **Within budget** — the remaining token or currency cap covers it.
5. **Attributable** — single-change discipline preserved; no speculative batches, because a
   batch that fails tells you nothing about which change failed.

Fail any one ⇒ the step becomes a docket entry. Never a judgment call the loop makes on the
user's behalf.

## 5. Supervision map

**Gated — never automated, no matter how confident the loop is:**

merge or release to shared branches · architecture rulings and ontology admissions · roadmap or
scope additions (features the goal did not name) · deploy and infrastructure mutations, and
anything owned by another team · spend beyond cap · repository visibility and publishing ·
taste verdicts on the product · goal kill or re-scope · deleting committed work less than 30
days old.

**Toil — deleted entirely**, each with the mechanism that replaces it:

| Toil | Replaced by |
|---|---|
| typing status updates | `digests.md` + HANDOFF §1 |
| "done yet?" polling | notification on L3/DONE + the digest tail |
| relaying pasted logs | the sensors section of the project's CLAUDE.md + `root-cause` rule 2 |
| brief and PR boilerplate | `goal-brief`, `spec-first`, `pr-message` |
| reconstructing progress | HANDOFF §1 |
| the verification interrogation | the `done` report |
| cross-session transplant | the `handoff` skill |
| re-explaining conventions | project CLAUDE.md + hooks |

### The atrophy ledger — where convenience trades against the user's own skill

Automation of judgment has a cost, and the honest move is to name it rather than pretend it
away. Each item below is a real trade; the mitigation is mechanical, because a moral resolution
("I'll be more careful") is the kind that decays silently.

1. **Diff-reading atrophy.** If verifier PASSes are always trusted, you stop reading code. A
   user who wants to work by objectives rather than read diffs is making a legitimate choice —
   but then the counterweight must be mechanical: a **periodic adversarial audit** that turns an
   independent agent loose on one randomly chosen verifier-PASSed slice, no cherry-picking. Any
   audit that contradicts a verifier PASS is a harness incident: tighten the verifier that day.
2. **Spec-writing atrophy.** `goal-brief` and `spec-first` draft *for* you, so the muscle that
   wrote specs from scratch weakens. Mitigation: drafts arrive with `[ASSUMED]` markers that must
   be resolved by editing. The edit is the exercise. Never approve a draft with unresolved
   `[ASSUMED]`.
3. **Debugging forensics atrophy.** `root-cause` plus sensors mean you rarely trace anything by
   hand again. Mitigation: docket entries tagged `mystery` are yours — solve one per month by
   hand before reading the loop's analysis.
4. **Manual coding atrophy.** The deepest one, and the hardest to mechanize. Periodic-challenge
   tools exist for it; whether to run one is a personal call. Naming it here is the point — an
   unnamed trade is one you cannot decide about.

## 6. The daily contract

Nothing here depends on the user's initiative, which is the design goal: the good path must be
the default path, so that using it at 11pm requires no willpower.

- **Evening** — `/goal-brief` → edit the draft (resolve every `[ASSUMED]`) → `/goal` +
  `/loop /product-loop`. The loop keeps itself alive: schedule-as-last-action, the `loop-guard`
  Stop hook, and an external watchdog (`tools/install-schedules.sh`). A user typing "restart the
  loop" is a harness incident, not a user error.
- **Morning** — the report *arrives* (scheduled `/morning`): a cross-goal digest plus open
  decisions in one-line-each format. The user answers in chat; the agent writes the record.
- **Weekly** — scheduled `/weekly-maintenance`: docket triage, the adversarial audit, hook
  health, memory hygiene.
- **Blocking decisions** reach the user as a notification plus a chat question the moment they
  block. Everything else waits for the morning report.
- **Research** — the same shape with `/research-loop`; rulings take the form of hand-back memos.
- **Interrupt-driven work** (a bug at 11pm) — just paste it. `firefight-catch` and `root-cause`
  put the session on the rails. The user states the goal, never the process.
