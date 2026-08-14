#!/usr/bin/env bash
# UserPromptSubmit hook — catches the "11pm voice": the session you start when something is
# on fire and you have no patience left. Those sessions are where the discipline goes first,
# so this hook puts them back on the same rails as your best ones. It injects steering
# context; it never blocks the prompt.
#
# It fires on four shapes:
#   (a) bare polling            "done?"                    -> answer with a done-report, not yes/no
#   (b) big paste, thin framing 4KB of traceback, no ask   -> root-cause before any edit
#   (c) fix-verbs with no cause "just fix it, still broken" -> no fix without "it fails because ___"
#   (d) duplicate resend <3min  same text twice            -> you resent because nothing started
#
# Install (plugin): nothing to do — hooks/hooks.json wires it.
# Install (manual):
#   cp firefight-catch.sh ~/.claude/hooks/ && chmod +x ~/.claude/hooks/firefight-catch.sh
#   settings.json: "hooks": { "UserPromptSubmit": [ { "hooks": [
#     { "type": "command", "command": "~/.claude/hooks/firefight-catch.sh" } ] } ] }
#
# ADD YOUR LANGUAGE. The patterns below are English. If you work in another language, the
# hook reads extra patterns from ~/.config/nightshift/firefight-patterns.json — no need to
# edit this file. Each key holds a list of regex fragments merged into the defaults:
#
#   {
#     "polling":   ["fatto", "finito", "allora", "ci sei", "hai finito"],
#     "firefight": ["non funziona", "è rotto", "lo fa ancora", "stesso errore", "fixa\\w*"],
#     "cause":     ["perché", "perche", "causa", "ipotesi"]
#   }
#
# (That example is Italian, and it is a real one — "fatto?" is the single most common way
# this hook earns its keep.) "cause" is the negative list: a prompt that names a cause is
# NOT a firefight, so anything you add there suppresses (c).

exec python3 - 3<&0 <<'PY'
import hashlib, json, os, re, sys, time

try:
    data = json.load(open(3))
except Exception:
    sys.exit(0)

prompt = data.get("prompt", "") or ""
if not prompt.strip() or prompt.lstrip().startswith("<"):  # command wrappers / injected XML
    sys.exit(0)

# --- patterns: English defaults + optional user additions -------------------------------
POLLING = [
    r"done", r"finished", r"ready", r"any update", r"update", r"status",
    r"are you done", r"you done", r"is it done", r"anything yet", r"there yet",
    r"well", r"so", r"and\?",
]
FIREFIGHT = [
    r"just fix it", r"fix it", r"it'?s broken", r"is broken", r"broken",
    r"does ?n'?t work", r"not working", r"still broken", r"still failing",
    r"still does ?n'?t", r"same error", r"same issue", r"again", r"it'?s still",
]
CAUSE = [
    r"because", r"why", r"hypothesis", r"root cause", r"cause", r"due to",
    r"caused by", r"i think it'?s", r"suspect",
]

try:
    cfg_path = os.path.expanduser("~/.config/nightshift/firefight-patterns.json")
    if os.path.exists(cfg_path):
        cfg = json.load(open(cfg_path))
        POLLING += [str(p) for p in cfg.get("polling", [])]
        FIREFIGHT += [str(p) for p in cfg.get("firefight", [])]
        CAUSE += [str(p) for p in cfg.get("cause", [])]
except Exception:
    pass  # a broken config must never break the prompt

def alt(pats):
    return "|".join(pats)

notes = []

# (a) bare polling — the whole message is "are we there yet"
if re.fullmatch(r"\s*(%s)\s*[?_.!]*\s*" % alt(POLLING), prompt, re.I):
    notes.append(
        "Polling detected. Do not answer with a bare yes/no: reply with the done-report "
        "(skill: done) or the current HANDOFF/digest state. If work is still running, say "
        "exactly what is running and when the next checkpoint lands."
    )

# (b) large paste, thin framing
first_line = prompt.split("\n", 1)[0]
looks_dumpy = bool(re.search(r"Traceback|ERROR|Exception|HTTP/1\.|GET /|\bat .+\.py\", line", prompt))
if len(prompt) > 4000 and (looks_dumpy or len(first_line.strip()) < 60):
    notes.append(
        "Large paste with little framing. Apply skill root-cause BEFORE any edit: state "
        "hypothesis + evidence, then acquire further observations with your own tools (logs, "
        "curl, kubectl, browser automation, database) — do not ask the user to re-test or "
        "paste more."
    )

# (c) fix-verbs with no cause named
if re.search(r"\b(%s)\b" % alt(FIREFIGHT), prompt, re.I) \
   and not re.search(r"\b(%s)\b" % alt(CAUSE), prompt, re.I):
    notes.append(
        "Firefight phrasing without a stated cause. Skill root-cause applies: no fix "
        "until you can complete 'it fails because ___, shown by ___'. If this symptom was "
        "already 'fixed' once, stop patching — escalate to a full investigation with one "
        "change at a time."
    )

# (d) duplicate send within 3 minutes
try:
    state_path = os.path.expanduser("~/.claude/hooks/.firefight-state.json")
    os.makedirs(os.path.dirname(state_path), exist_ok=True)
    norm = re.sub(r"\s+", " ", prompt.strip().lower())
    h = hashlib.sha256(norm.encode()).hexdigest()
    now = time.time()
    prev = {}
    if os.path.exists(state_path):
        prev = json.load(open(state_path))
    if prev.get("hash") == h and now - float(prev.get("ts", 0)) < 180:
        notes.append(
            "This message is identical to one sent under 3 minutes ago — almost "
            "certainly a resend because nothing visibly started. Acknowledge current state in "
            "one line; do NOT restart or fork the work."
        )
    json.dump({"hash": h, "ts": now}, open(state_path, "w"))
except Exception:
    pass

if not notes:
    sys.exit(0)

print(json.dumps({
    "hookSpecificOutput": {
        "hookEventName": "UserPromptSubmit",
        "additionalContext": "[firefight-catch] " + " | ".join(notes),
    }
}))
PY
