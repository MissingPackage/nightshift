---
name: handoff
description: Use when ending a work session that changed project state, when the user says "facciamo il punto"/"a che punto siamo"/"riprendiamo", when starting work in a project that has a HANDOFF.md, or after a crash/context loss when prior session state must be reconstructed.
---

# Session Hand-off

## Overview

Project state must survive the session. This skill replaces hand-transplanting context between sessions ("In un'altra sessione claude ha identificato…") and re-deriving it after crashes.

The artifact is `HANDOFF.md` at the project root (or `research/AGENDA.md` where that convention already exists — never both).

## On session start (project has HANDOFF.md / AGENDA.md)

Read it BEFORE exploring. Trust its "next decidable" unless the repo contradicts it — if it does, say so and update it: a stale hand-off is worse than none.

## On session end (state changed)

Refresh — do not append-only — `HANDOFF.md` as a **map** (form adopted 2026-08-12, ruling
"verbale del disegno workflow", from wayfinder's shared-map idea):

```
# HANDOFF — <project>   (updated <date>)

## 1. Next decidable
The single next action, with enough context to re-enter cold in five minutes —
this stays FIRST: it is what session-anchor injects and what a fresh /loop
session re-anchors on. If everything is user-gated: say so, list the open
decisions by TITLE.

## 2. Map
- **Destination**: the goal objective in 1-2 lines, and the distance from it NOW
  (the trajectory line).
- **Decisions so far**: an index — one line per decision, title + where it lives
  (docket path). Gist and link, never restate: a decision lives in exactly one place.
- **Fog**: what is not yet specified — the known unknowns, so scope emerges here
  instead of leaking into work.
- **Out of scope**: deliberately excluded, so it stops being re-proposed.

## 3. Landmines
- things the next session must NOT do / must know (broken invariants,
  half-applied patterns, env quirks discovered)
```

Keep it under 80 lines — the Stop hook `handoff-freshness` now warns beyond that.
It is a re-entry document, not a journal: narrative history lives in `digests.md`
(append-only, one entry per cycle), decisions live in the docket, technical trace
in the journal. Older material moves there or gets deleted — section 1 is the
contract, history is not. Write PI-facing files with the Edit tool, not shell
heredocs: the user may read them on a phone, where they render as app diffs.

## "Facciamo il punto" requests

Answer FROM the hand-off + `git log` + task tracker — then refresh the file so the answer is durable. Do not rebuild the picture from scratch each time.

## Common mistakes

- Appending forever → unreadable; refresh in place.
- Writing a roadmap → this is the NEXT step, not the plan.
- Resolving docket items yourself → they are user-gated by definition.
- Leaving it stale after a big change → update is part of "done" (see skill: done, Residue).
