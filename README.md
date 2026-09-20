<p align="center">
  <img src="assets/nightshift-banner.png" alt="Nightshift" width="820">
</p>

<p align="center">
  <em>Your agent works the night shift. You keep the rulings.</em>
</p>

<p align="center">
  <a href="https://github.com/MissingPackage/nightshift/actions/workflows/gates.yml"><img alt="gates" src="https://github.com/MissingPackage/nightshift/actions/workflows/gates.yml/badge.svg"></a>
  <a href="LICENSE"><img alt="License: MIT" src="https://img.shields.io/badge/license-MIT-blue.svg"></a>
  <img alt="Version" src="https://img.shields.io/badge/version-2.0.0-6c4bf6">
  <img alt="Claude Code plugin" src="https://img.shields.io/badge/Claude%20Code-plugin%20%2B%20installer-6c4bf6">
  <img alt="Hook tests" src="https://img.shields.io/badge/hook%20tests-114%20passing-3fb950">
  <img alt="shellcheck" src="https://img.shields.io/badge/shellcheck-clean-3fb950">
  <img alt="Machine" src="https://img.shields.io/badge/objective%20%C2%B7%20distance%20%C2%B7%20kill%20tests-1f6feb">
</p>

---

**A harness for long-horizon Claude Code work.** One map per project with the objective and the
distance to it, a loop that kills ideas with cheap tests instead of certifying them, hooks that
catch the sessions where discipline usually goes first, and four kinds of decision that stay
yours.

Claude Code is very good for an hour. The problems start at hour nine, on day three, at 11pm
when something is broken and you have no patience left: context is lost, claims stop carrying
evidence, "done" starts meaning "I ran out of ideas", and a plan applied to 30% of its sites
reads as finished. Nightshift is the scaffolding for that part — **state lives in files, not in
the conversation**, so the next session re-anchors from disk and continues.

It runs on itself. Every convention here is enforced on this repository by the gates in
`tests/`.

**Version 2 changed the spine, on evidence.** Version 1.0 ran on a goal contract decomposed into
phases, a verifier grading every phase and a docket for every decision. Measured on one project
over six weeks, that produced four registry edits per code edit, half of all final messages
handing a decision back to the user, and 445k words of record: conformance, not distance
covered. Version 2 keeps the hooks, the agents and the workflows, and replaces the spine with
one map and the distance to the objective. The reasoning is at the top of
[`ORCHESTRATION.md`](ORCHESTRATION.md); the old spine is tag `v1.0.0`.

---

## What you get

| | | |
|---|---|---|
| **Work that outlives the session** | one map per project, `HANDOFF.md`: objective, current value, gap, levers, fog | a crash costs one iteration, not the thread |
| **Ideas killed cheaply** | every lever gets the cheapest test that can kill it; the dead are recorded with the number | the night is spent on what survived, and nobody re-proposes what died |
| **A loop that runs unattended** | re-anchor → biggest gap → kill tests → redraw the map → schedule the next | it keeps itself alive across sessions, and stops when the gap will not move |
| **Rigor where an error costs something** | `done` report, full suite, `adversarial-reviewer`, `loop-verifier` | at the boundary (PR, release, paper, deploy), never per iteration |
| **Deterministic multi-agent orchestration** | 5 workflows, drawn one by one in [`docs/WORKFLOWS.md`](docs/WORKFLOWS.md) | scripts with real control flow, not a prompt asking for parallelism |
| **Rails you never invoke** | 7 hooks, fired by events | discipline that survives the hour when you have none |
| **The surface** | 7 skills · 4 agents · 8 commands — named under [Surface](#surface) | small on purpose: descriptions compete for the model's attention |

The protocol is [`ORCHESTRATION.md`](ORCHESTRATION.md) — the map, the loop, the boundary — and
[`docs/COOKBOOK.md`](docs/COOKBOOK.md) has ten end-to-end workloads. Plus an installer with
drift detection, a 114-case hook regression suite, a status line, git guards, and systemd units
for scheduled runs.

**The single idea:** make the good path the default path, so that using it at 11pm requires no
willpower.

---

## Why this is not a skill collection

Four things a set of prompts cannot do, all of them mechanical:

- **The loop is steered by a number it cannot talk its way around.** The head line of the map is
  the objective in the project's own currency, the current value and the gap. A head line that
  has not moved in two sessions is the first thing discussed, before any other work.
- **The loop knows when to stop.** Two iterations without the gap moving and it changes lever;
  four and it stops and asks, because the objective or the ceiling may be wrong. A Stop hook
  refuses a close without a scheduled wake-up, and an external watchdog restarts a session that
  died, so it neither grinds until morning nor goes quiet.
- **Nothing ships on the agent's word.** At the boundary `loop-verifier` and
  `adversarial-reviewer` run in their own context, read-only, and return a verdict with the
  command they ran. A reviewer sharing the author's context reviews its own reasoning.
- **A fix that exists in the repo but is not installed does not exist.** `verify-install.sh`
  compares the installed surface against the source and fails when they diverge — a real
  two-day divergence is why that check is there, and CI proves it can still say no.

---

## Install

Two channels. They install the same surface; pick one, not both.

### A. As a plugin (recommended)

```sh
/plugin marketplace add MissingPackage/nightshift
/plugin install nightshift@nightshift
/nightshift-setup                            # restart the session first, so the command exists
```

Hooks are wired by `hooks/hooks.json` — nothing to merge by hand. `/nightshift-setup` adds the
three things a plugin cannot carry: the workflows, `~/.claude/ORCHESTRATION.md` (skills cite it
by that path), and the status line. It installs nothing the plugin already provides, and
`verify-install.sh --plugin` fails if a second copy is ever found.

### B. With the installer

```sh
git clone https://github.com/MissingPackage/nightshift
cd nightshift
./install.sh --dry-run     # see exactly what would change; writes nothing
./install.sh --settings    # install, and merge hooks + statusLine into settings.json
./verify-install.sh        # 41 checks
```

| Flag | Effect |
|---|---|
| *(none)* | install skills, agents, commands, workflows, hud into `~/.claude`. `settings.json` untouched — each hook's header carries the snippet to merge by hand. |
| `--settings` | also merge the hooks block and statusLine into `settings.json`. Idempotent, backs up first, never clobbers other keys or a custom statusLine. |
| `--with-vendored` | also install the four vendored third-party skills (see [Third-party](#third-party) below). Off by default. |
| `--enterprise` | file-based surface only, no hooks, `settings.json` untouched — for environments where managed settings block hooks. See [`docs/ENTERPRISE.md`](docs/ENTERPRISE.md). |
| `--plugin` | complement channel A instead of duplicating it: workflows, `ORCHESTRATION.md` and the status line only. What `/nightshift-setup` runs for you. |
| `--dry-run` | print what would change, write nothing. Composes with all of the above. |

Existing files that differ are backed up to `~/.claude/nightshift-backup-<epoch>/` before
overwrite; unchanged files are skipped, so a re-run reports `0 installed`.

### The global `CLAUDE.md` (both channels)

Neither channel touches `~/.claude/CLAUDE.md` — that file is yours, and no installer
should be merging prose into it. But the harness was not designed in a vacuum: the author
runs it paired with the global rules in [`templates/CLAUDE.md`](templates/CLAUDE.md), and
several conventions here (the debugging contract, the completion contract, act-then-report)
assume something like it is in force. Copy the template, fill the `⟨FILL⟩` slots, then
either merge it into your existing file or replace yours with it — which of the two is
right is your call, not the installer's.

### Verify it took (2 minutes)

`./verify-install.sh` checks the files. These three check the behaviour:

1. Start a session and type `done?` → a `[firefight-catch]` note appears telling the agent to
   answer with a report, not a bare yes.
2. `git push` to a remote your `.harness/push-policy` does not allow → denied.
3. Create a `HANDOFF.md` with a `## 1. Objective and distance` section → a new session echoes it back.

If any of these does nothing, the hooks are not registered: re-run with `--settings`, or check
that `settings.json` is valid JSON.

---

## Using it

This is the widest path through the harness — one objective from an idea to a merged branch,
with every hook that fires on its own and every point where it stops and waits for you. Nothing
below is a feature list: it is what a single objective actually does.

<p align="center"><img src="assets/full-flow.svg" alt="One objective end to end: brainstorming and spec-first, goal-brief drafting the head of the map with ASSUMED markers, HANDOFF.md holding objective, value, gap, levers and fog, then the loop running unattended: re-anchor from the map, take the biggest gap, the cheapest test that can kill each lever, winners built by hand or by a workflow, dead levers marked with the number, the map redrawn and the next iteration scheduled; then the boundary with the done report, second-opinion and pr-message before you merge, and the morning report; the hooks that fire at each stage on the left and the four kinds of decision that reach you on the right" width="820"></p>

### Long-horizon work — the map and the loop

```sh
/goal-brief add offline mode to the sync engine   # → the head of the map, with [ASSUMED] markers
                                                  # you edit it; resolving them IS the exercise
/loop /product-loop                               # it runs, and keeps itself alive
```

There is no approval step between the two. The map is `HANDOFF.md` at the project root: a head
line (the objective in the project's currency, the current value, the gap) and five sections —
levers (open, in progress, dead with the number), fog, decisions for you, landmines. The currency
depends on the project: an engine has a number against a physical ceiling, a product has a user
path that works end to end, research has a question and the contribution so far.

Each iteration: re-anchor from the map → take the biggest gap → list the levers (from the map,
from the agent's own head, from outside: papers, repos, docs, one pass before writing code) →
give each one the cheapest test that can kill it, minutes not hours → keep the winners, mark the
dead with the number → redraw the map, append three lines to `.harness/tried.md` → schedule the
next. State lives in those two files, so a crash costs one iteration, not the thread.

<p align="center"><img src="assets/loop-iteration.svg" alt="One iteration: re-anchor from the map, take the biggest gap and list the levers, give each lever the cheapest test that can kill it; a killed lever is marked dead with the number and the next one is taken, a surviving one leads to the map redrawn with tried.md and a digest, then either the next wake-up is scheduled while the gap is still open, or the loop stops and asks when the gap is stuck" width="900"></p>

**Two loops, different currencies.** `/loop /product-loop` is for shipping: the objective is a
user path that works end to end, one slice per iteration, work on a branch, merging to a shared
branch waits for you, and `consistency-sweep` catches a slice that applied a new pattern to only
some of its sites. `/loop /research-loop` is for finding out: the prediction is registered
**before** any spend, cost is estimated on a dry run first, results are graded against what was
predicted — negative results recorded with the same care as positive ones.

**Four kinds of decision reach you, and nothing else does:** irreversible actions, spend (money,
or more than about thirty minutes of machine), anything that goes public, a change to the
objective. They arrive in chat, at most three, each one line with the default that applies on a
bare "ok". Everything else the loop decides, executes and writes in the map.

The loop stops itself on purpose: **two iterations without the gap moving** and it changes
lever, **four** and it stops and asks whether the objective or the ceiling is wrong; **only
decisions left** and stopping *is* the correct ending, with the decisions named. It does not
grind until morning, and it does not invent scope to stay alive.

Read [`ORCHESTRATION.md`](ORCHESTRATION.md) for the spine, the iteration, the four kinds of
decision, the boundary and what is never automated.

Then read [`docs/COOKBOOK.md`](docs/COOKBOOK.md) for the ten recipes: nightly loop, research
campaign, greenfield build, firefight, pattern migration, deploy, second-opinion review, weekly
maintenance, taking over a codebase you did not write, and picking up a run that died.

### Multi-agent work — workflows

A workflow is a script that gives a run its **direction**; the run itself stays as dynamic as
the work is. The script owns the shape — who may run at once, what must finish before what,
which model does which job, where the ceiling is. What actually happens inside is decided at
runtime by agents reading real code: in `pattern-migration` a mapper returns a plan and the
script spawns **one fixer per site it found**, each with an exclusive set of files; in
`second-opinion` the refuters are spawned **one per surviving finding**. Neither width was
written down anywhere.

What the script guarantees, and an agent improvising cannot: exclusive file ownership inside a
wave, explicit models per job — never inherited from your session — a hard cap on fan-out, and
structured results validated against a schema. That last rule was paid for: one early run left
the multiplier to a downstream agent and reached 57 agents on a pattern a `grep` could have
counted.

The deepest is `sdd-conductor`: a spec becomes a task graph validated **in code** — disjoint file
ownership, acyclic dependencies, mechanically checkable done-when — then waves of implement and
adversarial review, patches applied only by the integrator, and a task that fails review blocked
and handed back to the caller without stopping the build. It is for a multi-file build with a
written spec; a single file or a lever test is done by hand.

**[`docs/WORKFLOWS.md`](docs/WORKFLOWS.md) has all five, each with its own diagram.**

### Feature work — one session

`brainstorming` if the design is open → `spec-first` → implement → at the boundary the `done`
skill produces a report you can audit: commands actually run with their real outcomes, what was
**not** verified and why, and what you should check by hand. A "done" without evidence is the
failure mode this exists to make impossible.

### Interrupt work — the 11pm path

Nothing to invoke. Paste the error. `firefight-catch` sees the shape of the message — bare
polling, a 4KB traceback with no framing, fix-verbs with no cause named, the same message sent
twice in three minutes — and injects the rails. `root-cause` then blocks any edit until the
agent can complete *"it fails because ___, shown by ___"*, and it acquires its own observations
instead of asking you to re-test.


---

## Configuration

**Your own rules.** [`templates/CLAUDE.md`](templates/CLAUDE.md) is a starting `~/.claude/CLAUDE.md`
with `⟨FILL⟩` slots. Delete what you will not enforce — an instruction you ignore costs
attention in every session forever.

**Your own language.** The `firefight-catch` triggers are English. Add any language without
editing the hook, in `~/.config/nightshift/firefight-patterns.json`:

```json
{
  "polling":   ["fatto", "finito", "ci sei"],
  "firefight": ["non funziona", "è rotto", "lo fa ancora"],
  "cause":     ["perché", "causa", "ipotesi"]
}
```

`cause` is the suppression list: a prompt that names a cause is not a firefight. A malformed
config never breaks your prompt — it is ignored.

**Push policy.** `.harness/push-policy` in each project is deny-all until you add a rule. Both
the `push-guard` hook and the `pre-push` git hook read the same file, so the policy holds for
manual pushes too. Install the git guards with `tools/install-git-guards.sh`.

**Notifications.** Optional phone push. See [`docs/notify-setup.md`](docs/notify-setup.md).

**Scheduled runs.** `tools/install-schedules.sh` plus the units in `systemd/` for the morning
report and the loop watchdog. See [`docs/nightly-loop.md`](docs/nightly-loop.md).

---

## Honest limits

- **The version 2 spine is young.** It replaced the first one on 2026-09-08, on the six-week
  measurement quoted above. What is measured is the cost of the old spine. That the map moves
  objectives faster is the author's experience over the unattended nights run on it since, not
  yet a published number.
- **No evals in this release.** The harness has a measurement design — two arms, installed
  versus vanilla, driven headless against synthetic fixtures with planted bugs, scored
  deterministically, reporting the *breaking point* of each discipline rather than an average.
  It exists and it works, but its fixtures are not in English, and translating fixtures changes
  the treatment rather than the presentation: scores measured on renamed identifiers are not
  comparable to the originals. Rebuilding it properly is still owed. Shipping a
  mistranslated measuring instrument would be worse than shipping none.
- **The hooks are tested; the skills are less so.** `tests/run.sh` drives every hook with real
  JSON fixtures (114 cases). Skills are prompt-shaped artifacts and are verified by use, not by
  assertion.
- **`--enterprise` is a reduced product, not the same product.** Where managed settings block
  hooks, you keep the file-based surface and lose the mechanical enforcement. What survives and
  what does not is enumerated in [`docs/ENTERPRISE.md`](docs/ENTERPRISE.md).

---

## Surface

What lands in `~/.claude`, by kind:

- **7 skills** — `root-cause` · `done` · `handoff` · `loop-iteration` · `goal-setup` ·
  `spec-first` · `peripheral-vision`. They trigger on their own; none of them needs invoking.
- **7 hooks** — `firefight-catch` · `session-anchor` · `push-guard` ·
  `handoff-freshness` · `loop-guard` · `loop-state` · `notify-ntfy`.
- **4 agents** — `loop-verifier` · `adversarial-reviewer` · `scout` · `consistency-sweep`. Each
  gets its own context, which is the point: a reviewer sharing the author's context reviews its
  own reasoning.
- **8 commands** — `/goal-brief` · `/handoff` · `/morning` · `/pr-message` · `/product-loop` ·
  `/research-loop` · `/weekly-maintenance` · `/nightshift-setup`.
- **5 workflows** — `sdd-conductor` · `pattern-migration` · `pattern-coverage` ·
  `second-opinion` · `research-campaign`.

The skill count is a budget, not a score. Descriptions compete for the model's attention, and
twenty skills means none of them fire reliably.

## Contributing

Run `bash tests/run.sh` before opening a PR — 114 cases, hooks driven by piped JSON fixtures.
CI runs that plus `tests/check-references.sh`, `tests/check-no-secrets.sh`, a sandbox install
and verify in all four modes, an idempotency check, a negative case proving the drift sensor
can still fail, and shellcheck. It needs no secrets and requests read-only permissions.

**If you fix a bug, show the new case failing without the fix.** Stash the fix, or point the
suite at the previous version of the file, and confirm the case goes red — then restore it and
confirm green. A case that passes both ways is not covering the bug; it is decoration that will
read as coverage forever.

This is not a style preference. Fixing the hook that parses shell commands produced three new
cases, and only *one* of them failed against the broken version — the other two never reached
the defective code path at all, because an earlier filter returned first. Measured only after
the fix, all three looked like proof. The same thing happened four times in two days on this
project, which is why it is written down here instead of remembered.
Hooks follow one shape (`bash` → `python3` heredoc reading hook JSON on fd 3) so the suite can
drive them. Skills, commands and agents follow the shapes already in `skills/`, `commands/`,
`agents/`: frontmatter, Overview, steps, Common mistakes.

Prose convention, in docs and commits alike: dense, evidence-first, no filler. A claim about an
artifact carries the command that produced it and what that command actually printed.

## Third-party

Everything in this repository is original work, with one deliberate exception:
[`skills/vendored/`](skills/vendored/README.md) holds four skills from
[superpowers](https://github.com/obra/superpowers) by Jesse Vincent (MIT), kept as local copies
with four documented local adaptations. They are **not installed by default** — pass
`--with-vendored` if you want them. That directory's README explains the adaptations, why they
are vendored rather than depended on, and how to use upstream directly instead.

## License

MIT — see [`LICENSE`](LICENSE). The vendored skills carry their own upstream MIT notice in
[`skills/vendored/LICENSE-superpowers`](skills/vendored/LICENSE-superpowers).
