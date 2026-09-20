---
name: handoff
description: Use when ending a work session that changed project state, when the user says "facciamo il punto"/"a che punto siamo"/"riprendiamo", when starting work in a project that has a HANDOFF.md, or after a crash/context loss when prior state must be reconstructed.
---

# The Map (HANDOFF.md)

## Overview

`HANDOFF.md` at the project root is the map: the single document a human on a phone and a fresh
agent re-enter from in five minutes. It replaces goal contracts, phases, dockets, journals and
digests. History lives in git and in `.harness/tried.md`. (Projects with a `research/AGENDA.md`
keep that file as the map; never both.)

## On session start

Read it before exploring. Trust its head line and its "next" unless the repo contradicts it; if
it does, say so and fix the map first: a stale map is worse than none.

## The shape (under 150 lines, plain language, titles never IDs, no em dashes)

```
# HANDOFF — <project>   (updated <date>)

## 1. Objective and distance
<objective in the project's currency> · now: <value> · ceiling/reference: <value> · gap: <x>
Next: the single next lever to try and why.
(engine: a table model | host | now | ceiling | gap; product: the user path and what works;
research: the question and the contribution so far)

## 2. Levers
- Open: one line each, expected gain, the kill test
- In progress: what is being tried right now
- Dead: name, number, reason, date (so nobody re-proposes them)

## 3. Fog
Known unknowns, one line each.

## 4. Decisions for the user
At most three, only the four kinds (irreversible, spend, public, objective), each with the
default applied on a bare "ok". Dissent recorded here in one line, attributed.

## 5. Landmines
What the next session must not do or must know.
```

## On session end (state changed)

Refresh in place, never append. Move dead levers to "Dead" with their number. If the head line
did not move, say so in the head line ("gap unchanged since <date>"). Keep under 150 lines; the
Stop hook `handoff-freshness` warns beyond that and when the repo is newer than the map.
Write it with the Edit tool: the user may read it on a phone, where it renders as an app diff.

## "Facciamo il punto"

Answer from the map plus `git log` and `.harness/tried.md`, then refresh the map so the answer
is durable. Do not rebuild the picture from scratch.

## Common mistakes

- Appending forever → refresh in place.
- Recording work done instead of distance to the objective: that is tried.md's job.
- Listing every open question as a decision: only the four kinds are decisions.
- Restating decisions taken elsewhere: one line, attributed, done.
