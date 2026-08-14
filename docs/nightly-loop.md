# Nightly loop — wiring (R2, ruling B2: "sulla subscription finché non tocca i limiti")

Two routes, for two classes of repo. The pre-limit protocol (below) applies to both.

## A. Local repos (this repo) — systemd user timer

The harness repo is local and has a deny-all push-policy: a cloud schedule cannot see it.
The route is `systemd --user` + `claude -p`. The files are in `systemd/` (unit, timer,
nightly prompt). Activation — YOURS, one command:

```
systemctl --user link ~/Projects/harness/systemd/claude-nightly.service
systemctl --user link ~/Projects/harness/systemd/claude-nightly.timer
systemctl --user enable --now claude-nightly.timer
systemctl --user list-timers claude-nightly*        # confirm
journalctl --user -u claude-nightly.service -f      # log of the first run
```

The nightly prompt (systemd/nightly-prompt.md) re-anchors from HANDOFF+docket, runs ONE
iteration of decidable work (unattended test §4: never PI rulings, never pushes, never
live config), and always closes with commit+digest+HANDOFF+notification. With Telegram
active (B7 ✓), the morning digest reaches your phone.

## B. Repos on GitHub — cloud schedule

`/schedule` creates a cloud routine that survives sessions; the nightly goal must be
expressed as the routine's prompt (same skeleton as the nightly prompt). Prerequisite:
repo reachable from the cloud. For a repo you do not fully own, settle authority first (
repo).

## Pre-limit protocol (from the Insights report, B2)

Your month's #1 friction: 6+ sessions dead on limits mid-task, manual resume.
Rules (now also in skills/loop-iteration):
1. **Checkpoint on clean boundaries**: every iteration closes with commit+digest+HANDOFF —
   an interruption always lands on restartable state (already our standard).
2. **Pre-limit check**: before a long operation (subagent fan-out, multi-run eval, new
   phase), ask whether the session's limits can carry it; on concrete doubt, clean
   hand-back NOW. One fewer iteration beats a half-done merge.
3. **Resume without 'continue'**: the next run (timer/schedule) restarts FROM DISK
   (HANDOFF §1 + docket): no human prompt required. If a run dies dirty, the next one
   finds the worktree and says so in the digest instead of feigning cleanliness.

## Budget (ruling B2)

Subscription, up to the limits: no artificial token cap; the operational cap is
TimeoutStartSec=4h in the unit + the pre-limit protocol. If the limits bite too hard,
the screw to turn is OnCalendar (frequency), not iteration depth.
