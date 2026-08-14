---
name: root-cause
description: Use when the user reports something broken, pastes an error/log/traceback/console output, says "non funziona"/"lo fa ancora"/"c'è un bug", or when a previous fix did not survive re-testing. Also use before editing code in response to any failure you have not yet reproduced.
---

# Root Cause Before Fixes

## Overview

A fix without a named cause is a bet placed with the user's time. This contract exists because symptom-patching cost real projects days (a voice-pipeline saga: same bug "fixed" five times; a CMS integration: the same console error re-pasted four times in ten minutes).

**Core principle: no edit until you can say "the failure happens because X, and here is the evidence."**

**Loop first (2026-08-12):** for any non-trivial bug, the first artifact is the feedback
loop, not the hypothesis — a tight pass/fail reproduction that goes red on THIS bug,
then minimized. With that loop in hand the cause will be found; without it, hypotheses
are bets. The fix is verified by re-running the loop (inside a goal, the verifier
re-runs it too — the repro outlives the session).

## The contract

1. **State the hypothesis and its evidence.** One sentence each. If you have no evidence, name the observation that would discriminate between candidate causes — then go collect it.
2. **Collect observations yourself.** Logs, `curl`, `kubectl logs/exec`, DB queries, playwright, re-running the failing command, reading the SDK source in `.venv`. Ask the user to observe only what genuinely requires a human (audio quality, physical devices).
3. **Framework/SDK suspected → current docs first.** Read the library's current documentation (context7 / dedicated MCP / `--help`) before archaeology in your own code. Version-check: the installed version, not your memory of the API.
4. **Cause unknown → one change at a time.** Verify each change against the original reproduction before the next. Batched speculative changes destroy attribution ("troppe variabili in gioco" = this rule was skipped).
5. **Declare the verification.** After the fix: how you re-ran the original failure and what you observed. If you could not re-verify, say so explicitly — never imply a fix is confirmed.

## Red flags — STOP, you are symptom-patching

- You are about to edit code and cannot complete: "it fails because ___, shown by ___".
- Your explanation contains "probably" / "should" with no observation behind it.
- You are asking the user to reload/re-test/paste something a tool of yours can observe.
- This is the second fix attempt for the same symptom.
- You are adding a guard/retry/try-except around the place where the error *appears*.

## Rationalizations

| Excuse | Reality |
|---|---|
| "The fix is obvious from the traceback" | The traceback shows where it died, not why. Feb saga: five "obvious" fixes, zero survived re-test. |
| "Reading docs is slower than trying" | Docs turn N guess-cycles into 1. The turn-taking bug was in the framework's documented behavior all along. |
| "I'll batch these likely fixes to save time" | Attribution dies; when one works you won't know which, and the hunt gets abandoned. |
| "The user can test it faster than I can" | Every human round-trip costs minutes and truncated pastes. Your sensors are faster and lossless. |
| "It's urgent, no time for process" | Urgency is precisely when a second wrong fix costs a demo. The contract IS the fast path. |

## When NOT to use

Pure typo/lint/import errors with self-evident cause and a one-line fix — fix them, but still re-run the failing command yourself.
