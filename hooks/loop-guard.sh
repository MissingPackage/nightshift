#!/usr/bin/env bash
# Stop hook — ruling C10 (2026-08-12, failure "closes with a summary but without scheduling":
# 24 manual relaunches in 24 days). If THIS session has an active loop (loop-state.json
# written by hooks/loop-state.sh) and the turn is closing without a new schedule nor a
# declared stop, BLOCK the close and say so. "Next iteration I'll do X" is not a schedule.
#
# Install:
#   cp loop-guard.sh ~/.claude/hooks/ && chmod +x ~/.claude/hooks/loop-guard.sh
#   settings.json: "hooks": { "Stop": [ { "hooks": [
#     { "type": "command", "command": "~/.claude/hooks/loop-guard.sh" } ] } ] }

exec python3 - 3<&0 <<'PY'
import json, os, sys, time

try:
    data = json.load(open(3))
except Exception:
    sys.exit(0)

# anti-recursion: if we are already continuing because of a Stop-hook block, let it through
if data.get("stop_hook_active"):
    sys.exit(0)

root = os.environ.get("CLAUDE_PROJECT_DIR") or data.get("cwd") or os.getcwd()
state_path = os.path.join(root, ".harness", "loop-state.json")
if not os.path.isfile(state_path):
    sys.exit(0)

try:
    state = json.load(open(state_path))
except Exception:
    sys.exit(0)

if state.get("status") != "active":
    sys.exit(0)
# block only the session that owns the loop: parallel sessions (e.g. an interactive
# chat in the same project) are left untouched
if state.get("session_id") and state.get("session_id") != data.get("session_id"):
    sys.exit(0)

# if ScheduleWakeup was called during this turn, loop-state has a next_wake in the
# future (30s of slack for execution time) → legitimate close
if int(state.get("next_wake_epoch") or 0) > time.time() - 30:
    sys.exit(0)

print(json.dumps({
    "decision": "block",
    "reason": "[loop-guard] This session is in a loop (.harness/loop-state.json) but the "
              "turn is closing without a schedule: the consumed wake-up was never "
              "replaced. Before closing: call ScheduleWakeup for the next iteration, or "
              "declare the loop finished with ScheduleWakeup{stop:true} and the reasons "
              "in the digest (skill loop-iteration, step 9). A summary that promises "
              "'next iteration' without scheduling it is the bug, not a pause.",
}))
PY
