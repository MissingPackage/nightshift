---
description: Write the PR description for the current branch to pr-description.md (file, not chat)
---

Analyze every commit on this branch versus its base (default: dev) and write the PR
description to `pr-description.md` at the repo root — a FILE, because chat formatting dies on
paste (the "me lo scrivi in un md?" ritual, automated).

Structure: **Summary** (3 bullets max) · **What changed** (grouped by area, with the why for
each non-obvious choice) · **Challenges & how they were resolved** (only real ones) ·
**Test plan** (checkboxes: what was run with results, what the reviewer should run) ·
**Breaking changes / migrations** (or "none").

Rules: derive from the actual diff and commit history, not from memory of the session; no AI
attribution anywhere; if the branch mixes unrelated work, say so at the top and recommend the
split rather than papering over it. End by printing only the file path and the Summary bullets.

$ARGUMENTS
