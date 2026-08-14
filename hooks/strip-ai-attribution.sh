#!/usr/bin/env bash
# PreToolUse hook (matcher: Bash) — mechanically enforce "no AI attribution in commits".
# Receives the tool-call JSON on stdin. If it is a git commit whose message contains AI
# attribution lines, rewrites the command to strip them (allow + updatedInput).
# Never blocks a commit; silent no-op for everything else.
#
# Install (user scope):
#   cp strip-ai-attribution.sh ~/.claude/hooks/ && chmod +x ~/.claude/hooks/strip-ai-attribution.sh
#   ~/.claude/settings.json:
#     "hooks": { "PreToolUse": [ { "matcher": "Bash",
#       "hooks": [ { "type": "command", "command": "~/.claude/hooks/strip-ai-attribution.sh" } ] } ] }

# fd3 = the hook's real stdin (the heredoc below takes over fd0)
exec python3 - 3<&0 <<'PY'
import json, re, sys

try:
    data = json.load(open(3))
except Exception:
    sys.exit(0)

cmd = (data.get("tool_input") or {}).get("command", "") or ""
if "git" not in cmd or "commit" not in cmd:
    sys.exit(0)

ATTRIB = re.compile(
    r"(\\n|\n|^)[ \t]*("
    r"\U0001F916?[ \t]*Generated with \[?Claude[^\n\"']*"
    r"|Co-Authored-By:[^\n\"']*(?:[Cc]laude|[Aa]nthropic)[^\n\"']*"
    r"|Claude-Session:[^\n\"']*"
    r")",
)

if not ATTRIB.search(cmd):
    sys.exit(0)

new_cmd = ATTRIB.sub("", cmd)

print(json.dumps({
    "hookSpecificOutput": {
        "hookEventName": "PreToolUse",
        "permissionDecision": "allow",
        "updatedInput": {"command": new_cmd},
    },
    "systemMessage": "strip-ai-attribution: removed AI attribution lines from commit message.",
}))
PY
