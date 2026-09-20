---
name: goal-setup
description: Use when a project starts a new objective or campaign, when a project has no HANDOFF.md map yet, or when the objective changes — it writes the map (head line, levers, fog) that every loop iteration re-anchors on.
---

# Start a Map

## Overview

A new objective starts with a map, not a contract. The map is `HANDOFF.md` at the project root
(shape in skill handoff, protocol in `ORCHESTRATION.md` §1). This skill writes the first version
and takes ten minutes; the loop redraws it from then on.

## Steps

1. **The head line.** The objective in the project's currency, the current value, the gap.
   Engine: a number against a physical ceiling (bandwidth, compute), per model and host.
   Product: the user path that must work end to end, and what works today. Research: the
   question, and the contribution so far. If the ceiling is unknown, finding it is the first lever.
2. **Levers.** From three sources, in one pass each: what the previous sessions left (git log,
   old maps, `.harness/tried.md`), what you think (including combinations), what others did
   (papers, repos, docs: a real search, cited). Each lever: one line, expected gain, the test that
   kills it in minutes. Order by expected gain over cost of the kill test.
3. **Fog.** The known unknowns: what nobody measured or understood. One line each.
4. **Decisions for the user.** Only the four kinds (irreversible, spend, public, objective).
   At most three, with the default. Present them in chat now, phone format.
5. **Landmines.** What the next session must not do or must know: env quirks, hosts, broken
   invariants, protected paths, territory owned by someone else.
6. **Start.** `.harness/tried.md` created if missing. Digest of three lines. Then the first
   iteration (skill loop-iteration) begins in the same session, unless a decision of the four
   kinds blocks it.

## Common mistakes

- A head line without a number or an observable: "make it faster" is not an objective.
- A lever list without the outside pass: the best lever is usually in someone's repo.
- A phase plan: rows, done-whens, estimates. The map has no phases; the loop picks the biggest
  gap each time.
- Asking approval of the map before starting: only the four kinds are questions.
