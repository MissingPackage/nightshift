#!/usr/bin/env bash
# SessionStart hook — kills re-orientation typing ("facciamo il punto"): injects the map head
# (HANDOFF.md §1) at session start, plus the count of decisions waiting in §4, if present.
#
# Install:
#   cp session-anchor.sh ~/.claude/hooks/ && chmod +x ~/.claude/hooks/session-anchor.sh
#   settings.json: "hooks": { "SessionStart": [ { "hooks": [
#     { "type": "command", "command": "~/.claude/hooks/session-anchor.sh" } ] } ] }

exec python3 - 3<&0 <<'PY'
import glob, json, os, re, sys

try:
    data = json.load(open(3))
except Exception:
    data = {}

root = os.environ.get("CLAUDE_PROJECT_DIR") or data.get("cwd") or os.getcwd()

handoff = None
for name in ("HANDOFF.md", os.path.join("research", "AGENDA.md")):
    p = os.path.join(root, name)
    if os.path.isfile(p):
        handoff = p
        break

if not handoff:
    sys.exit(0)

parts = []
if handoff:
    lines = open(handoff, encoding="utf-8", errors="replace").read().splitlines()
    keep, started = [], False
    try:
        for ln in lines:
            if ln.startswith("## "):
                if started:
                    break  # end of §1
                toks = ln.split()
                if (len(toks) > 1 and "1" in toks[1][:2]) or "next" in ln.lower():
                    started = True
                    keep.append(ln)
                    continue
            if started:
                keep.append(ln)
            if len(keep) >= 40:
                break
    except Exception:
        keep = []  # malformed header must degrade, never crash (D5b)
    section = "\n".join(keep).strip() or "\n".join(lines[:25])
    parts.append(f"{os.path.relpath(handoff, root)} — current anchor:\n{section}")

# 2026-09-08: the anchor injects the map head (HANDOFF §1) and the count of decisions waiting
# in §4, nothing else. The per-goal docket listing and the cross-project decision counts are
# gone with the goal/docket spine (ORCHESTRATION §1): announcing 8 goals and 41 open decisions
# at every start put the session in the clerk's chair before the first prompt.
if handoff:
    try:
        text = open(handoff, encoding="utf-8", errors="replace").read()
        m = re.search(r"^## 4\.?[^\n]*\n(.*?)(?=^## |\Z)", text, re.S | re.M)
        if m:
            n_dec = sum(1 for l in m.group(1).splitlines() if l.lstrip().startswith(("- ", "* ", "1", "2", "3")))
            if n_dec:
                parts.append(f"decisions waiting in HANDOFF §4: {n_dec}")
    except Exception:
        pass

# A fix that exists in the repo and doesn't run on the machine doesn't exist (the user's
# permanent rule, 2026-08-14; paid for that morning: hooks/loop-state.sh fixed here and
# two days stale in ~/.claude/hooks). install.sh --dry-run compares with cmp and writes
# nothing: here we only look at the verdict, and only in the repo that has that installer.
try:
    inst = os.path.join(root, "install.sh")
    if os.path.isfile(inst):
        import subprocess
        r = subprocess.run(["bash", inst, "--dry-run"], capture_output=True, text=True,
                           timeout=20, cwd=root)
        pend = [l.split(": ", 1)[1] for l in r.stdout.splitlines()
                if l.startswith("would install:")]
        if pend:
            shown = ", ".join(pend[:4]) + (f" (+{len(pend)-4})" if len(pend) > 4 else "")
            parts.append("ATTENTION — %d files fixed in the repo are NOT in effect on the "
                         "machine: %s. Remedy: ./install.sh" % (len(pend), shown))
except Exception:
    pass  # the drift sensor must never break the anchor

print(json.dumps({
    "hookSpecificOutput": {
        "hookEventName": "SessionStart",
        "additionalContext": "[session-anchor] Re-anchor from disk before exploring.\n" + "\n\n".join(parts),
    }
}))
PY
