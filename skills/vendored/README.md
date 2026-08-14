# Vendored skills — provenance and local adaptations

These four skills are **not original work**. They are local copies of
[superpowers](https://github.com/obra/superpowers) v6.3.0 by Jesse Vincent, MIT licensed —
see [`LICENSE-superpowers`](./LICENSE-superpowers). Everything else in this repository is
original; this directory is the exception, and it is kept separate for exactly that reason.

| Skill | Local adaptations |
|---|---|
| `brainstorming` | 3 — see below |
| `subagent-driven-development` | 1 — see below |
| `writing-plans` | none (verbatim v6.3.0) |
| `writing-skills` | none (verbatim v6.3.0) |

Every adaptation is marked inline with an HTML comment starting `nightshift drift`, stating
what was changed and why. A local copy means no auto-updates: re-diff against upstream
periodically, and read the drift notes before taking an upstream change wholesale.

## Why these four are vendored rather than depended on

Installing the full superpowers plugin gives you all 14 of its skills. Four of those overlap
with Nightshift's own — `systematic-debugging` with `root-cause`, `verification-before-completion`
with `done`, `executing-plans` with `loop-iteration`, and `using-superpowers` is pure discovery
overhead here — so the standing skill surface would go to 21 with duplicated triggers competing
for the model's attention. Claude Code has no per-skill install granularity: a plugin's skills
are all available once it is installed. Vendoring these four is how you get them without the
other ten.

**If you would rather have upstream directly**, that is a good choice too — it gets you
updates for free. Install it and delete this directory:

```sh
/plugin marketplace add obra/superpowers
/plugin install superpowers
rm -rf ~/.claude/skills/vendored     # or skip --with-vendored at install time
```

Just don't run both: you would get four skills twice, in two versions.

## Cross-references to skills that are not here

These files refer to sibling superpowers skills that Nightshift does not ship —
`superpowers:test-driven-development`, `superpowers:finishing-a-development-branch`,
`superpowers:using-git-worktrees`, `superpowers:executing-plans`,
`superpowers:requesting-code-review`, `superpowers:systematic-debugging`.

Those references resolve only if you also install upstream. Left alone they are dead pointers,
so treat them as reading suggestions rather than instructions. Where Nightshift has its own
answer, use it: `root-cause` covers systematic debugging, `done` covers
verification-before-completion, and `loop-iteration` covers executing plans phase by phase.

## The adaptations, and the reasoning

**`brainstorming` 1/3 — description retuned.** Upstream: *"You MUST use this before any
creative work."* Recent Claude models over-trigger on `You MUST … any` phrasing and invoke the
skill inside work that is already past the design gate. The trigger is now descriptive and the
HARD-GATE carries an explicit exception instead. *This is an observation about upstream that is
still true there; if you use upstream directly, consider retuning the description locally.*

**`brainstorming` 2/3 — the architectural exit forks by scale.** Upstream hardwires
`writing-plans` as the only terminal state, which presupposes a plan is the terminal artifact.
Under this harness, project-sized work terminates in a goal contract instead: `PHASES.md` is
where a roadmap gets built, not presupposed.

**`brainstorming` 3/3 — the fork is scoped to brainstorming's own exit.** Inside an
already-decomposed goal, every PHASES row is feature-sized by construction, so re-applying the
fork per row would always select `writing-plans` and stack a plan document on top of a plan.
Phase execution belongs to `loop-iteration`.

**`subagent-driven-development` — "Rulings, not stalls" scoped to granted authority.** Upstream
v6.3.0 tells the agent to decide conflicts, ambiguities, plan defects and cap overruns itself,
stopping for only four things. Under this harness the goal contract names an authority boundary,
and `ORCHESTRATION.md` §4 routes an authority edge to the docket with the phase blocked. Without
this scoping the skill and the protocol would give opposite instructions on the same event. The
principle upstream is right about survives: a session parked on a question the agent had the
authority to answer costs the user their whole day and buys nothing.
