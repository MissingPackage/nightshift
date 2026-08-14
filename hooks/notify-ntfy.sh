#!/usr/bin/env bash
# Notification hook — one-way push fallback over ntfy (one-way; "a 10-line
# ntfy hook beats reinstalling OMC"). OPT-IN: silent until ~/.config/harness/notify.conf
# exists with the topic URL. Never blocking: 5s timeout, errors stay quiet.
# Test: HARNESS_NOTIFY_DRY=1 prints the payload instead of POSTing.
#
# Install:
#   cp notify-ntfy.sh ~/.claude/hooks/ && chmod +x ~/.claude/hooks/notify-ntfy.sh
#   settings.json: "hooks": { "Notification": [ { "hooks": [
#     { "type": "command", "command": "~/.claude/hooks/notify-ntfy.sh" } ] } ] }

exec python3 - 3<&0 <<'PY'
import json, os, subprocess, sys

conf = os.path.expanduser("~/.config/harness/notify.conf")
if not os.path.isfile(conf):
    sys.exit(0)  # opt-in: no config, no noise
url = open(conf, encoding="utf-8").read().strip()
if not url:
    sys.exit(0)

try:
    data = json.load(open(3))
except Exception:
    sys.exit(0)

msg = (data.get("message") or data.get("notification") or
       f"claude-code: {data.get('hook_event_name', 'event')} in {os.path.basename(data.get('cwd') or '')}")
msg = msg[:900]

if os.environ.get("HARNESS_NOTIFY_DRY"):
    print(json.dumps({"dry": True, "url": url, "message": msg}))
    sys.exit(0)

try:
    subprocess.run(["curl", "-fsS", "--max-time", "5", "-d", msg, url],
                   capture_output=True, timeout=8)
except Exception:
    pass  # a lost notification is not worth a blocked session
sys.exit(0)
PY
