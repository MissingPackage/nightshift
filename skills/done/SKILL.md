---
name: done
description: Use when about to claim a task is complete, fixed, implemented, or ready to merge/deploy/push — and when the user asks "fatto?", "finito?", "possiamo mergiare?", or "quanto rischio a pushare?". Use before ending any session or loop iteration that changed code.
---

# Definition of Done

## Overview

Completion claims in this workspace follow one report shape. It exists because the user had to extract the same facts by hand after every change ("Hai fatto tutti i test? ... Cosa devo controllare io a mano? Come testo le modifiche?" — typed for five months).

**A "done" without this report is not done. Fill every section; write "none" rather than omitting one.**

## The completion report (required shape)

```
## Done: <one-line what>

**Evidence** — commands actually run, with outcomes:
- unit: <command> → <result>
- integration: <command> → <result>   (requires real services, e.g. Docker Compose)
- lint/format: <command> → <result>
- build/other gates: <...>

**Not verified** — what was NOT checked and why:
- <item — reason>   (write "nothing" only if truly nothing)

**Your manual check** — what the user should verify by hand, and exactly how:
- <step-by-step, copy-pasteable>

**Conventions & docs** — project rules touched by this change:
- <e.g. domain events emitted for every new mutation? docs/ADR updated per project procedure? migrations?> → <status>

**Residue** — new issues noticed, out-of-scope, logged where:
- <item → Linear/docket ref, or "none">
```

## Rules

- The report is written for the user, who often reads it **on a phone**: plain language, every project term explained in half a line or dropped, no bare sigla — docket items and phases are cited by their **title**, the ID at most in parentheses. Inside a goal loop, open with the trajectory line — objective was at X, is at Y, Z moves it next.
- Evidence means **fresh output from this session**, not "tests passed earlier" or "should pass".
- A gate you skipped, reported honestly under **Not verified**, is acceptable. A gate silently omitted is a false claim.
- Partial completion → say "Partially done", keep the same shape, list the remainder.
- Risk questions ("quanto rischio a pushare?") → answer with this report plus a one-line risk verdict grounded in the Not-verified section.

## Rationalizations

| Excuse | Reality |
|---|---|
| "Small change, report is overkill" | Small changes broke the cluster twice. The report takes 60 seconds. |
| "Tests passed before my last edit" | Then they haven't tested your last edit. Re-run. |
| "The user will test it anyway" | He tests what you TELL him to test. That's the Manual-check section's job. |
| "I'll just say done and details on request" | The requests are exactly the four questions this shape answers. Pre-empt them. |
