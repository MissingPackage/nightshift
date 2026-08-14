---
name: spec-first
description: Use when starting any feature or product slice expected to take more than a session — when the user describes something to build ("facciamo", "creiamo", "voglio una pagina/feature"), before implementation planning, or when a goal phase lacks a written spec.
---

# Spec First

## Overview

The spec shape below is salvaged from this workspace's own best specs (the Feb 2026 MVP voice
pipeline, a research-site brief) — the SpecKit engine is retired, the shape earned its
keep. A spec is the PI's judgment made editable; the draft saves typing, the edit IS the judgment.

## The shape (write to `specs/<slug>.md`, or `.harness/goals/<slug>/SPEC.md` when goal-bound)

```
# <Feature name>
## Overview            — one paragraph: what and why now
## User stories        — each: As/I want/so that + Acceptance criteria that are
                         OBSERVABLE BEHAVIORS (a tester could check each box)
## Read first          — table: What | Where | Why (files the implementer must
                         understand before writing code)
## Non-goals           — what this slice deliberately does NOT do
## Hard constraints    — tech, UX, budget, deadline ("demo tra X giorni" goes HERE,
                         not in a firefight message later)
## Open questions      — every inference marked [ASSUMED: …]; unresolved = not approved
```

## Rules

- Acceptance criteria must be checkable without interpretation ("routing happens silently — no
  voice prompt about choosing a mode" is checkable; "good UX" is not).
- Draft fast, mark every guess `[ASSUMED]`, and hand back for editing. **Never proceed to
  implementation with unresolved `[ASSUMED]` markers** — the user's edit of those markers is
  the load-bearing judgment, not a formality.
- The Read-first table is for the NEXT agent, not the user: real paths, one-line why each.
- Slice scope: if the stories exceed what SDD can verify in a few tasks, split the spec.

## When NOT to use

Bug fixes (skill: root-cause), one-file changes, research experiments (predictions +
directive files own that lane).
