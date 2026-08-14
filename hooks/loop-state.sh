#!/usr/bin/env bash
# PostToolUse hook (matcher: ScheduleWakeup) — ruling C10 (2026-08-12, failure "schedules
# and the wake-up never arrives", case ffbce7a6). MECHANICAL loop bookkeeping: every
# ScheduleWakeup is recorded in <project>/.harness/loop-state.json (stop:true ⇒
# status stopped). No model discipline required: the hook writes the state.
# Read by: hooks/loop-guard.sh (Stop) and tools/loop-watchdog.sh (external timer).
#
# Install:
#   cp loop-state.sh ~/.claude/hooks/ && chmod +x ~/.claude/hooks/loop-state.sh
#   settings.json: "hooks": { "PostToolUse": [ { "matcher": "ScheduleWakeup", "hooks": [
#     { "type": "command", "command": "~/.claude/hooks/loop-state.sh" } ] } ] }

exec python3 - 3<&0 <<'PY'
import json, os, sys, time

try:
    data = json.load(open(3))
except Exception:
    sys.exit(0)

if data.get("tool_name") != "ScheduleWakeup":
    sys.exit(0)

root = os.environ.get("CLAUDE_PROJECT_DIR") or data.get("cwd") or os.getcwd()
harness = os.path.join(root, ".harness")
if not os.path.isdir(harness):
    sys.exit(0)  # not a harness project: no state to keep

tin = data.get("tool_input") or {}
now = time.time()
state_path = os.path.join(harness, "loop-state.json")

# loop-state.json is RUNTIME, not source: versioning it arms a fuse. A `git checkout`
# of a branch carrying it with status "active" rewrites it on disk, and the watchdog —
# correctly reading "active" — revives a loop deliberately stopped with stop:true
# (observed in another project, 2026-08-14 00:01:34; 19 branches of that repo still carry an active
# state). The file ignores itself: a .gitignore inside .harness/ touches neither goals/
# nor push-policy, which do belong tracked.
ignore_path = os.path.join(harness, ".gitignore")
try:
    lines = open(ignore_path).read().splitlines() if os.path.isfile(ignore_path) else []
    if "loop-state.json" not in [l.strip() for l in lines]:
        with open(ignore_path, "a") as f:
            f.write(("" if not lines or lines[-1] == "" else "\n") + "loop-state.json\n")
except Exception:
    pass  # as below: bookkeeping must never break the loop

if tin.get("stop"):
    state = {
        "status": "stopped",
        "session_id": data.get("session_id", ""),
        "updated_epoch": int(now),
        "updated": time.strftime("%Y-%m-%dT%H:%M:%S%z", time.localtime(now)),
    }
else:
    try:
        delay = float(tin.get("delaySeconds") or 0)
    except Exception:
        delay = 0.0
    # the runtime clamps to [60, 3600]; mirror the clamp so we never record absurd waits
    delay = max(60.0, min(3600.0, delay)) if delay else 0.0
    if not delay:
        sys.exit(0)
    wake = now + delay
    state = {
        "status": "active",
        "session_id": data.get("session_id", ""),
        "next_wake_epoch": int(wake),
        "next_wake": time.strftime("%Y-%m-%dT%H:%M:%S%z", time.localtime(wake)),
        "prompt": (tin.get("prompt") or "")[:2000],
        "updated_epoch": int(now),
        "updated": time.strftime("%Y-%m-%dT%H:%M:%S%z", time.localtime(now)),
    }

try:
    tmp = state_path + ".tmp"
    with open(tmp, "w") as f:
        json.dump(state, f, indent=1)
    os.replace(tmp, state_path)
except Exception:
    pass  # bookkeeping must never break the loop itself
sys.exit(0)
PY
