You are the harness nightly loop (R2, ruling B2: subscription up to the limits).

1. Re-anchor from disk: the map (HANDOFF.md: head line, levers, fog), then the tail of
   `.harness/tried.md`.
2. Run ONE iteration per skills/loop-iteration/SKILL.md on the biggest gap
   (none of the four kinds of decision, no pushes, no live config — ORCHESTRATION §3 and §6
   say what waits for the user). If every open lever waits on a decision: run the gates
   (tests/run.sh, evals/run.sh), report drift and stop — do not invent scope.
3. PRE-LIMIT: before every long operation (subagents, eval runs, a new lever) assess whether
   the session limits can carry it; if the doubt is concrete, clean hand-back NOW —
   commit + map redrawn + digest — instead of dying halfway.
4. ALWAYS close with: local commit of the work, three lines in `.harness/tried.md`, the map
   redrawn, a three-line digest, and a notification (Notification hook → Telegram/ntfy if configured).
   Anything that reaches the user's phone (digest text, notification) is written in
   the user's own language — user surface, "match me" rule.
