#!/usr/bin/env bash
# SessionStart hook — kills re-orientation typing ("facciamo il punto", FM6): injects
# HANDOFF.md §1 (next decidable) and the active goal dirs at session start, if present.
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

goal_dirs = sorted(glob.glob(os.path.join(root, ".harness", "goals", "*")))

if not handoff and not goal_dirs:
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

def open_docket_items(path):
    # D5a: goal dockets use `## D<n>` entries closed by a `**RULING:** <text>` line;
    # an entry is OPEN while its ruling is the `_` placeholder. Bullet counting stays
    # as fallback for legacy bullet dockets.
    lines = open(path, encoding="utf-8", errors="replace").read().splitlines()
    rulings = [l.strip() for l in lines if l.strip().startswith("**RULING")]
    if rulings:
        n = 0
        for r in rulings:
            val = r.split(":**", 1)[-1].strip() if ":**" in r else ""
            if not val or val.startswith("_"):
                n += 1
        return n
    return sum(1 for l in lines if l.lstrip().startswith("- ") and "RULED" not in l)

_ROW_LIVE = re.compile(r"\|\s*\*{0,2}(ready|blocked|in[- ]progress)\*{0,2}\s*\|?\s*$", re.I)

def goal_is_live(gdir):
    """A goal asks for attention only if it is not paused and still has rows to do.
    Fixed 2026-08-12 on a finding by the session in another project: counting the dockets
    of CLOSED goals inflated the view (35 entries announced against 22 real)."""
    gm = os.path.join(gdir, "GOAL.md")
    try:
        if os.path.isfile(gm) and "STATUS: PAUSED" in open(
                gm, encoding="utf-8", errors="replace").read(600):
            return False
    except Exception:
        pass
    ph = os.path.join(gdir, "PHASES.md")
    if not os.path.isfile(ph):
        return True  # not yet decomposed: live by definition
    try:
        return any(_ROW_LIVE.search(l) for l in
                   open(ph, encoding="utf-8", errors="replace"))
    except Exception:
        return True

for g in goal_dirs:
    if not goal_is_live(g):
        continue
    slug = os.path.basename(g)
    docket = os.path.join(g, "docket.md")
    n_open = open_docket_items(docket) if os.path.isfile(docket) else 0
    parts.append(f"active goal '{slug}' — open docket items: {n_open}")

# C10 (2026-08-12): cross-project view of open decisions — 16 entries stuck 26 days in a
# project never reopened because the anchor only looked at the cwd. Things get brought
# to the PI, not waited for.
try:
    proj_root = os.path.expanduser(os.environ.get("HARNESS_PROJECTS_ROOT", "~/Projects"))
    others = []
    for proj in sorted(os.listdir(proj_root)) if os.path.isdir(proj_root) else []:
        pdir = os.path.join(proj_root, proj)
        if os.path.realpath(pdir) == os.path.realpath(root):
            continue
        total = 0
        for gdir in glob.glob(os.path.join(pdir, ".harness", "goals", "*")):
            if not goal_is_live(gdir):
                continue  # paused or already closed: not pending attention
            dk = os.path.join(gdir, "docket.md")
            if os.path.isfile(dk):
                total += open_docket_items(dk)
        if total:
            others.append((total, proj))
    if others:
        others.sort(reverse=True)
        listing = ", ".join(f"{name}: {n}" for n, name in others[:5])
        more = f" (+{len(others)-5} projects)" if len(others) > 5 else ""
        parts.append(f"open decisions in OTHER projects — {listing}{more}")
except Exception:
    pass  # the cross-project view must never break the anchor

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
