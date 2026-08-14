---
description: Turn a raw goal idea into a structured /goal contract (draft, then hand back for approval)
---

Take my raw goal below and draft the structured goal contract I will feed to /goal. Do NOT start executing the goal — the deliverable of this command is the contract text, printed for my review.

Draft it in exactly this shape, filling gaps with your best inference from the repo state and flagging every inference with `[ASSUMED]` so I can correct it:

```
GOAL: <one sentence, outcome not activity>

DONE WHEN (all measurable):
- <condition 1 — verifiable by a command/artifact, not by judgment>
- <condition 2>

EVIDENCE OF DONE: <exact commands/artifacts that will prove each condition>

AUTHORITY GRANTED:
- may do autonomously: <e.g. create branches, open PRs, run tests, spend up to €X>
- must docket (never do): <e.g. merge to dev, touch deploy repo, change public APIs, delete >30-day-old code>

CONSTRAINTS: <standing rules that apply — attribution, protected paths, budget, conventions>

WORKING PROTOCOL: follow skills loop-iteration + done; verifier gate per cycle; digest every cycle; stop-by-design when the remaining work is docket-gated.

CONTEXT ANCHORS: <files to read first: HANDOFF.md, tracker query, specs>
```

Rules for the draft: split heterogeneous objectives into separate goals (a goal with "and also…" chains loses its completion condition); reject any DONE-WHEN that a verifier could not check mechanically — rewrite it until it is checkable; keep AUTHORITY explicit even when it feels obvious — implied authority is how unwanted merges happen.

Raw goal: $ARGUMENTS
