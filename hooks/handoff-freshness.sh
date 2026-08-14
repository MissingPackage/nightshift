#!/usr/bin/env bash
# Stop hook — R12 (receipts: stale-HANDOFF incident it5+it9 of goal harness-completeness).
# At session end: if the repo changed AFTER the last update of HANDOFF.md, warn with the
# delta (severity WARN — never blocks; B6). "A stale hand-off is worse than none."
#
# Install:
#   cp handoff-freshness.sh ~/.claude/hooks/ && chmod +x ~/.claude/hooks/handoff-freshness.sh
#   settings.json: "hooks": { "Stop": [ { "hooks": [
#     { "type": "command", "command": "~/.claude/hooks/handoff-freshness.sh" } ] } ] }

exec python3 - 3<&0 <<'PY'
import json, os, subprocess, sys

try:
    data = json.load(open(3))
except Exception:
    sys.exit(0)

root = os.environ.get("CLAUDE_PROJECT_DIR") or data.get("cwd") or os.getcwd()
handoff = os.path.join(root, "HANDOFF.md")
if not os.path.isfile(handoff):
    sys.exit(0)  # project without a handoff: nothing to check

def git(*args, raw=False):
    # raw=True for positional output (porcelain): strip would eat the leading status
    # space and l[3:] would truncate the filename's first char (found by verifier it5)
    try:
        r = subprocess.run(["git", "-C", root, *args], capture_output=True, text=True, timeout=10)
        if r.returncode != 0:
            return None
        return r.stdout if raw else r.stdout.strip()
    except Exception:
        return None

last_commit_ts = git("log", "-1", "--format=%ct")
if last_commit_ts is None:
    sys.exit(0)  # not a git repo

h_mtime = os.path.getmtime(handoff)
dirty = git("status", "--porcelain", raw=True) or ""
dirty_files = [l[3:] for l in dirty.splitlines() if l.strip() and "HANDOFF.md" not in l]

# C10 (2026-08-12): the ≤80-line limit lived only inside the never-executed weekly
# ritual — result: a 644-line HANDOFF injected at EVERY session start. Now it lives here.
try:
    n_lines = sum(1 for _ in open(handoff, encoding="utf-8", errors="replace"))
except Exception:
    n_lines = 0
oversize = n_lines > 80

stale_vs_commit = int(last_commit_ts) > int(h_mtime)
if not stale_vs_commit and not dirty_files and not oversize:
    sys.exit(0)

delta = []
if oversize:
    delta.append(f"HANDOFF.md is at {n_lines} lines (limit 80): it is a re-entry document, "
                 "not a journal — history goes to digests/journal, the map stays here")
if stale_vs_commit:
    names = git("log", f"--since=@{int(h_mtime)}", "--name-only", "--format=") or ""
    changed = sorted({n for n in names.splitlines() if n.strip() and n != "HANDOFF.md"})
    if not changed:
        sys.exit(0)  # the only post-handoff commits touched HANDOFF alone
    delta.append(f"{len(changed)} files committed after HANDOFF.md: " + ", ".join(changed[:8]) + ("…" if len(changed) > 8 else ""))
if dirty_files:
    delta.append(f"{len(dirty_files)} uncommitted files: " + ", ".join(dirty_files[:8]) + ("…" if len(dirty_files) > 8 else ""))

if stale_vs_commit or dirty_files:
    msg = ("[handoff-freshness] HANDOFF.md is older than the repo state — "
           "FULL refresh before closing (skill: handoff). Delta: " + " · ".join(delta))
else:
    msg = "[handoff-freshness] " + " · ".join(delta)
print(json.dumps({"systemMessage": msg}))
PY
