#!/usr/bin/env bash
# PreToolUse hook (matcher: Bash) — mechanism for the loop authority boundary (ORCHESTRATION §4):
# git pushes are allowed only where the project's .harness/push-policy says so.
# No policy file ⇒ silent allow (opt-in per project). Force-push needs an explicit grant.
#
# Policy format (one rule per line, comments with #):
#   origin feature/*            # remote + ref glob
#   origin main force-ok        # optional trailing 'force-ok' to permit --force
#   origin *                    # any ref on origin (matches bare `git push` too)
#
# Install:
#   cp push-guard.sh ~/.claude/hooks/ && chmod +x ~/.claude/hooks/push-guard.sh
#   settings.json: "hooks": { "PreToolUse": [ { "matcher": "Bash",
#     "hooks": [ { "type": "command", "command": "~/.claude/hooks/push-guard.sh" } ] } ] }

exec python3 - 3<&0 <<'PY'
import fnmatch, json, os, re, shlex, sys

try:
    data = json.load(open(3))
except Exception:
    sys.exit(0)

cmd = (data.get("tool_input") or {}).get("command", "") or ""
if not re.search(r"\bgit\b[^\n|;&]*\bpush\b", cmd):
    sys.exit(0)

root = os.environ.get("CLAUDE_PROJECT_DIR") or data.get("cwd") or os.getcwd()
policy_path = os.path.join(root, ".harness", "push-policy")
if not os.path.isfile(policy_path):
    sys.exit(0)  # project hasn't opted in

rules = []
for ln in open(policy_path, encoding="utf-8", errors="replace"):
    ln = ln.split("#", 1)[0].strip()
    if not ln:
        continue
    toks = ln.split()
    rules.append({"remote": toks[0],
                  "ref": toks[1] if len(toks) > 1 else "*",
                  "force_ok": "force-ok" in toks[2:] or (len(toks) > 1 and toks[1] == "force-ok")})

# parse (H1, ruling 2026-07-25): a real push has the TOKEN `push` after a git token in
# its segment — the substring ("push-policy" in a path or in a message) is not one. In a
# compound command each push segment is judged on its own: deny at the first one outside
# policy (the old "last matching segment" denied innocent gits and could have covered a
# real push in an earlier segment).
def is_push_seg(toks):
    gi = next((i for i, t in enumerate(toks) if t == "git" or t.endswith("/git")), None)
    return gi is not None and "push" in toks[gi + 1:]

pushes = []
for s in re.split(r"[|;&]|&&|\|\|", cmd):
    try:
        toks = shlex.split(s)
    except ValueError:
        toks = s.split()
    if is_push_seg(toks):
        pushes.append((s, toks))
if not pushes:
    sys.exit(0)  # "push" was only a substring: no real push in the command

def allowed(remote, ref, forced):
    for r in rules:
        if fnmatch.fnmatch(remote, r["remote"]) and (fnmatch.fnmatch(ref, r["ref"]) or r["ref"] == "*"):
            if forced and not r["force_ok"]:
                continue
            return True
    return False

verdict = None
for s, toks in pushes:
    i = toks.index("push")
    args = [t for t in toks[i + 1:] if not t.startswith("-")]
    forced = bool(re.search(r"(^|\s)(--force(-with-lease)?|-f)(\s|$)", s))
    remote = args[0] if args else "origin"
    ref = args[1] if len(args) > 1 else "*"      # bare push → current branch, unknowable here
    ref = ref.split(":", 1)[-1]                   # src:dst → judge the destination
    if not allowed(remote, ref, forced):
        verdict = (remote, ref, forced)
        break
if verdict is None:
    sys.exit(0)
remote, ref, forced = verdict

reason = (f"push-guard: `git push {remote} {ref}`" + (" with --force" if forced else "") +
          f" is outside {os.path.relpath(policy_path, root)}. Allowed: " +
          "; ".join(f"{r['remote']} {r['ref']}{' (force-ok)' if r['force_ok'] else ''}" for r in rules) +
          ". Per ORCHESTRATION §4 this is an authority edge: docket it instead of pushing.")

print(json.dumps({
    "hookSpecificOutput": {
        "hookEventName": "PreToolUse",
        "permissionDecision": "deny",
        "permissionDecisionReason": reason,
    }
}))
PY
