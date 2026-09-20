# ORCHESTRATION — the map, the loop, the boundary

> The autonomy layer: how long-horizon work proceeds by objective and distance instead of by
> prompts. Design invariant: **the deliberate voice is the interface; the 11pm voice is an input
> the mechanisms catch** (hook `firefight-catch`), so the worst sessions ride the same rails as
> the best ones. Files are the spine; conversations are disposable.
>
> This is the second spine. The first (goal contract → phases → a verifier per phase → a docket
> for everything outside the contract) was measured on one project over six weeks: four registry
> edits per code edit, half of all final messages handing a decision back to the user, 445k words
> of record, and a coordinator whose mandated output was the registry itself. It produced
> conformance, not distance covered. The unit of control is now the **distance to the
> objective**. The first spine is tag `v1.0.0`.

## 1. The spine (per project)

```
<project>/HANDOFF.md                # THE MAP, under 150 lines (shape: skill handoff)
<project>/.harness/tried.md         # append-only, three lines per experiment: lever, result, verdict
<project>/.harness/loop-state.json  # runtime, written by hooks (gitignored)
<project>/.harness/push-policy      # optional; deny-all until the user edits it
```

No goal directories, no phase table, no docket, no journal, no digest file. A project coming from
v1.0 moves them to `.harness/_old/`. History is git.

The map has one head line and five sections. Head line: **the objective in the project's
currency, the current value, the gap.** Currency by project type: engine → a number against a
physical ceiling; product → a user path that works end to end; research → the question and the
contribution so far. Sections: levers (open / in progress / dead with the number), fog (known
unknowns), decisions for the user (at most three, four kinds only), landmines. A map whose head
line has not moved in two sessions is the first thing to discuss, before any other work.

## 2. The iteration (skill loop-iteration)

Re-anchor from the map → take the biggest gap → list levers: from the map, from the agent's own
head, from outside (papers, repos, docs: one pass before writing code) → for each, the cheapest
test that can kill it (minutes, not hours) → keep the winners, mark the dead with the number →
redraw the map, append to tried.md → three-line digest → schedule the next wake-up or declare the
stop. Fix what you meet on the path. Implement directly; delegate only what is parallel or bulk.

No verifier per iteration: the internal control is the kill test. Two iterations without the gap
moving → change lever. Four → stop and ask: the objective or the ceiling may be wrong.

## 3. Decisions

Four kinds reach the user: irreversible, spend (money, or more than ~30 minutes of machine),
public, change of objective. Batched in chat, at most three, each one line with the default that
applies on a bare "ok". Everything else is decided, executed and written in the map or in
tried.md. Dissent is one line in the map, attributed. A "standby" said in chat becomes a line in
the map, written without asking. The map is the record; chat is the medium.

## 4. The boundary

Rigor lives where an error costs something outside the repo: PR to a shared branch, release,
paper, public numbers, deploy to shared infrastructure. There, and only there: the completion
report (skill done), the full suite, certification runs on final code, an adversarial review
(agent adversarial-reviewer) when the change deserves distrust, a final verification against the
objective (agent loop-verifier) before a release or a paper. Documentation duties are set by the
project's CLAUDE.md and are part of the boundary, not of the iteration.

## 5. The night

One session per project. The loop keeps itself alive: ScheduleWakeup as the last action of every
turn, the Stop hook `loop-guard` that refuses a close without a schedule, and the external
watchdog timer (`tools/install-schedules.sh`). A user typing "restart the loop" is a harness
incident, not a user error. A night is judged by the map delta in the morning: the scheduled
`/morning` report reads the maps and the tails of tried.md. Cost discipline: the model of every
subagent is explicit (the strongest model implements and reviews, a cheaper one does mechanical
work); the coordinator stays on the session model. A workflow (sdd-conductor) is for a multi-file
build with a written spec; a single file, a variant or a lever test is done by hand.

Interrupt-driven work (a bug at 11pm) needs nothing invoked: paste it. `firefight-catch` and
`root-cause` put the session on the rails.

## 6. Never automated

Merge to shared branches · deploy and infrastructure mutations, and anything owned by someone
else · spend beyond the cap · repository visibility and publishing · deleting committed work
under 30 days old · changing the objective. Anything else the loop decides and records.

### The atrophy ledger

Automation of judgment has a cost, and the honest move is to name it. Each mitigation is
mechanical, because a moral resolution ("I'll be more careful") decays silently.

1. **Diff-reading atrophy.** A user who works by objectives rather than by reading diffs is making
   a legitimate choice; the counterweight is the weekly adversarial audit of one commit chosen at
   random, no cherry-picking (`/weekly-maintenance`).
2. **Spec-writing atrophy.** `goal-brief` and `spec-first` draft *for* the user. Drafts arrive
   with `[ASSUMED]` markers that are resolved by editing: the edit is the exercise.
3. **Debugging forensics atrophy.** `root-cause` plus sensors mean the user rarely traces anything
   by hand again. Keep one mystery a month and solve it by hand before reading the analysis.
4. **Manual coding atrophy.** The deepest one, and the hardest to mechanize. Naming it is the
   point: an unnamed trade is one nobody can decide about.
