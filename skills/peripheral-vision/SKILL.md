---
name: peripheral-vision
description: Use at the end of substantive coding, debugging, or exploration work — before the completion report — and whenever the user asks "c'è altro che dovrei sapere?" or requests a risk scan of recent changes.
---

# Peripheral Vision

## Overview

While working you see things outside the task: rot, contradictions, tripwires. By default that signal is discarded to "stay concise". This skill un-suppresses the *reporting* — it cannot create noticing that didn't happen (for deep sweeps use the `scout` agent instead).

## The scan (30 seconds, before the completion report)

Ask yourself, strictly about things you ALREADY touched or read this session:

- **Contradictions**: did any doc/config/comment contradict observed reality? (stale branch names, wrong README claims, dead env vars)
- **Tripwires**: did you step around something that will bite the next change? (half-applied pattern, duplicated constant, fragile ordering, TODO-load-bearing)
- **Rot**: files/deps/services referenced but absent, or present but unused?
- **Blast radius**: does your change silently affect a consumer you didn't touch?

## Reporting rules (the shape)

Append to the completion report:

```
**Noticed (outside task):**
1. <observation> — <why it's load-bearing> — <suggested owner: docket/Linear/now>
```

- **Max 3 items.** More than 3 means you're listing, not judging.
- Each item must pass: "would the user act differently knowing this?" If not, drop it.
- Never silently fix out-of-scope findings; report + log (project docket or Linear).
- Nothing qualified → write nothing. An empty ritual line trains the reader to skip the section.

## Common mistakes

- Padding with style nits to fill the quota — the cap is a maximum, not a target.
- Re-reporting the same known issue every session — check the docket first; repeats reference the existing entry.
- Turning the scan into a new exploration — this reports what you already saw; it spends zero new tool calls (that's the scout agent's job).
