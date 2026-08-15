#!/usr/bin/env bash
# Test harness for hooks/ — the phase-1 stabilization gate (goal harness-completeness).
# Run: bash tests/run.sh          Exit 0 = all green (known-gaps report but don't fail).
#
# Every hook is bash→python reading the Claude Code hook JSON on fd 3, so each case is:
# pipe a JSON fixture into the script, assert exit code + stdout. Sandboxed: fake $HOME
# (firefight state file) and per-case project dirs (push-policy, HANDOFF); the runner
# unsets CLAUDE_PROJECT_DIR so hooks resolve the fixture cwd, not this repo.
#
# KNOWN-GAP cases assert the CURRENT (defective) behavior so the suite stays green while
# the defect is docketed; if a gap case fails, the hook changed — promote the case to a
# regular PASS assertion and resolve the docket entry.

set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOOKS="$ROOT/hooks"
SANDBOX="$(mktemp -d)"
trap 'rm -rf "$SANDBOX"' EXIT
export HOME="$SANDBOX/home"
mkdir -p "$HOME"
unset CLAUDE_PROJECT_DIR 2>/dev/null || true

PASS=0 FAIL=0 GAP=0 NAME=""

t()   { NAME="$1"; }
ok()  { PASS=$((PASS + 1)); printf 'PASS  %s\n' "$NAME"; }
bad() { FAIL=$((FAIL + 1)); printf 'FAIL  %s\n      %s\n' "$NAME" "$1"; }
gap() { GAP=$((GAP + 1)); printf 'GAP   %s\n      %s\n' "$NAME" "$1"; }

# run_hook <hook-basename> <json>  → sets OUT, RC
run_hook() {
  OUT="$(printf '%s' "$2" | bash "$HOOKS/$1" 2>/dev/null)"
  RC=$?
}

json_prompt() { python3 -c 'import json,sys; print(json.dumps({"prompt": sys.argv[1]}))' "$1"; }
json_cmd() {
  python3 -c '
import json, sys
d = {"tool_input": {"command": sys.argv[1]}}
if len(sys.argv) > 2 and sys.argv[2]:
    d["cwd"] = sys.argv[2]
print(json.dumps(d))' "$1" "${2:-}"
}
json_cwd() { python3 -c 'import json,sys; print(json.dumps({"cwd": sys.argv[1]}))' "$1"; }

assert_silent() {
  if [ "$RC" -eq 0 ] && [ -z "$OUT" ]; then ok; else bad "expected silent rc=0; got rc=$RC out=${OUT:0:140}"; fi
}
assert_contains() {
  case "$OUT" in *"$1"*) ok ;; *) bad "missing '$1' in: ${OUT:0:180}" ;; esac
}
assert_not_contains() {
  case "$OUT" in *"$1"*) bad "unexpected '$1' in: ${OUT:0:180}" ;; *) ok ;; esac
}
# assert JSON: permissionDecision==allow, updatedInput.command has no attribution, keeps $1
assert_stripped_keeps() {
  printf '%s' "$OUT" | python3 -c '
import json, sys
o = json.load(sys.stdin)
h = o["hookSpecificOutput"]
c = h["updatedInput"]["command"]
assert h["permissionDecision"] == "allow", "not allow"
for marker in ("Co-Authored-By", "Generated with", "Claude-Session"):
    assert marker not in c, marker + " survived"
assert sys.argv[1] in c, "lost original message"
' "$1" 2>/dev/null && ok || bad "strip contract violated: ${OUT:0:180}"
}
assert_deny() {
  printf '%s' "$OUT" | python3 -c '
import json, sys
o = json.load(sys.stdin)
h = o["hookSpecificOutput"]
assert h["permissionDecision"] == "deny"
assert "push-guard" in h["permissionDecisionReason"]
' 2>/dev/null && ok || bad "expected deny JSON, got rc=$RC: ${OUT:0:180}"
}

echo "== strip-ai-attribution.sh =="

t "strip: Co-Authored-By Claude removed, message kept"
run_hook strip-ai-attribution.sh "$(json_cmd 'git commit -m "fix: order totals

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"')"
assert_stripped_keeps "fix: order totals"

t "strip: 'Generated with Claude Code' removed"
run_hook strip-ai-attribution.sh "$(json_cmd 'git commit -m "feat: retry queue

🤖 Generated with [Claude Code](https://claude.com/claude-code)"')"
assert_stripped_keeps "feat: retry queue"

t "strip: Claude-Session trailer removed"
run_hook strip-ai-attribution.sh "$(json_cmd 'git commit -m "chore: bump deps

Claude-Session: https://claude.ai/code/session_ABC"')"
assert_stripped_keeps "chore: bump deps"

t "strip: escaped \\n attribution form removed"
run_hook strip-ai-attribution.sh "$(json_cmd 'git commit -m "fix: x\n\nCo-Authored-By: Claude <noreply@anthropic.com>"')"
assert_stripped_keeps "fix: x"

t "strip: clean commit passes silently"
run_hook strip-ai-attribution.sh "$(json_cmd 'git commit -m "fix: plain human commit"')"
assert_silent

t "strip: human co-author untouched"
run_hook strip-ai-attribution.sh "$(json_cmd 'git commit -m "pair work

Co-Authored-By: Example Reviewer <reviewer@example.com>"')"
assert_silent

t "strip: non-commit git command ignored"
run_hook strip-ai-attribution.sh "$(json_cmd 'git push origin master')"
assert_silent

t "strip: non-git command ignored"
run_hook strip-ai-attribution.sh "$(json_cmd 'echo "Co-Authored-By: Claude"')"
assert_silent

t "strip: invalid JSON input is a silent no-op"
run_hook strip-ai-attribution.sh 'this is not json'
assert_silent

echo "== firefight-catch.sh =="

t "firefight: 'done?' triggers the polling note"
run_hook firefight-catch.sh "$(json_prompt 'done?')"
assert_contains "Polling detected"

t "firefight: bare 'Done' triggers polling (case-insensitive)"
run_hook firefight-catch.sh "$(json_prompt 'Done')"
assert_contains "Polling detected"

t "firefight: 'any update?' triggers polling"
run_hook firefight-catch.sh "$(json_prompt 'any update?')"
assert_contains "Polling detected"

t "firefight: large traceback paste triggers the root-cause note"
run_hook firefight-catch.sh "$(python3 -c 'import json; print(json.dumps({"prompt": "log dump\nTraceback (most recent call last):\n" + "x" * 4200}))')"
assert_contains "Large paste"

t "firefight: fix-verb without cause triggers the firefight note"
run_hook firefight-catch.sh "$(json_prompt 'it is still broken, just fix it')"
assert_contains "Firefight phrasing"

t "firefight: fix-verb WITH stated cause stays silent"
run_hook firefight-catch.sh "$(json_prompt 'it is broken because the token expired - renew it')"
assert_silent

t "firefight: normal prompt stays silent"
run_hook firefight-catch.sh "$(json_prompt 'add an email field to the signup form')"
assert_silent

t "firefight: command-wrapper (<) prompt ignored"
run_hook firefight-catch.sh "$(json_prompt '<command-message>loop</command-message>')"
assert_silent

t "firefight: whitespace-only prompt ignored"
run_hook firefight-catch.sh "$(json_prompt '   ')"
assert_silent

t "firefight: extra patterns from user config fire (multilingual extension point)"
mkdir -p "$SANDBOX/.config/nightshift"
printf '%s' '{"polling":["fatto"],"firefight":["non funziona"],"cause":["perche"]}' \
  > "$SANDBOX/.config/nightshift/firefight-patterns.json"
OUT="$(printf '%s' "$(json_prompt 'fatto')" | HOME="$SANDBOX" bash "$ROOT/hooks/firefight-catch.sh" 2>&1)"; RC=$?
assert_contains "Polling detected"

t "firefight: user-config cause word suppresses the firefight note"
OUT="$(printf '%s' "$(json_prompt 'non funziona perche il token e scaduto')" | HOME="$SANDBOX" bash "$ROOT/hooks/firefight-catch.sh" 2>&1)"; RC=$?
assert_silent

t "firefight: malformed user config never breaks the prompt"
printf '%s' 'not json{{' > "$SANDBOX/.config/nightshift/firefight-patterns.json"
OUT="$(printf '%s' "$(json_prompt 'add a retry to the uploader')" | HOME="$SANDBOX" bash "$ROOT/hooks/firefight-catch.sh" 2>&1)"; RC=$?
assert_silent
rm -f "$SANDBOX/.config/nightshift/firefight-patterns.json"

t "firefight: identical resend within 3 min is flagged"
run_hook firefight-catch.sh "$(json_prompt 'retry the staging deploy')"
FIRST_RC=$RC FIRST_OUT=$OUT
run_hook firefight-catch.sh "$(json_prompt 'retry the staging deploy')"
if [ "$FIRST_RC" -eq 0 ] && [ -z "$FIRST_OUT" ]; then
  assert_contains "identical to one sent"
else
  bad "first send was not silent: rc=$FIRST_RC out=$FIRST_OUT"
fi

echo "== session-anchor.sh =="

P1="$SANDBOX/proj-handoff"; mkdir -p "$P1"
printf '# HANDOFF — x\n\n## 1. Next decidable\nApprove PHASES row 3.\n\n## 2. State delta\nsecret-should-not-leak\n' > "$P1/HANDOFF.md"
t "anchor: HANDOFF §1 injected"
run_hook session-anchor.sh "$(json_cwd "$P1")"
assert_contains "Approve PHASES row 3"
t "anchor: §2 not leaked (stops at next header)"
run_hook session-anchor.sh "$(json_cwd "$P1")"
assert_not_contains "secret-should-not-leak"

P2="$SANDBOX/proj-empty"; mkdir -p "$P2"
t "anchor: no HANDOFF, no goals → silent"
run_hook session-anchor.sh "$(json_cwd "$P2")"
assert_silent

P3="$SANDBOX/proj-goals"; mkdir -p "$P3/.harness/goals/g1"
printf -- '- decide retention window\n- decide event schema\n- RULED 07-01: keep UPSERT\n' > "$P3/.harness/goals/g1/docket.md"
t "anchor: bullet-docket open items counted"
run_hook session-anchor.sh "$(json_cwd "$P3")"
case "$OUT" in # NB: non-ASCII is \u-escaped in the JSON, keep patterns ASCII-only
  *"active goal 'g1'"*"open docket items: 2"*) ok ;;
  *) bad "expected g1 with 2 open items: ${OUT:0:180}" ;;
esac

P4="$SANDBOX/proj-agenda"; mkdir -p "$P4/research"
printf '# AGENDA\n\n## 1. Next decidable\nGrade WP7 prediction.\n' > "$P4/research/AGENDA.md"
t "anchor: research/AGENDA.md fallback works"
run_hook session-anchor.sh "$(json_cwd "$P4")"
assert_contains "Grade WP7 prediction"

t "anchor: HANDOFF + goals both reported"
mkdir -p "$P1/.harness/goals/g2"
printf -- '- open item\n' > "$P1/.harness/goals/g2/docket.md"
run_hook session-anchor.sh "$(json_cwd "$P1")"
case "$OUT" in
  *"Approve PHASES row 3"*"active goal 'g2'"*) ok ;;
  *) bad "expected both HANDOFF §1 and goal line: ${OUT:0:200}" ;;
esac

# --- ex known-gaps, promoted to PASS after ruling D5 "both approved" (2026-07-10) ---
P5="$SANDBOX/proj-header-docket"; mkdir -p "$P5/.harness/goals/g3"
printf '## D1 · plan-check\n**RULING:** _\n\n## D2 · thing\n**RULING:** _(scegli tu)\n\n## D3 · done\n**RULING:** approvato 07-10\n' > "$P5/.harness/goals/g3/docket.md"
t "anchor: '## D' docket — unresolved RULING placeholders counted (D5a)"
run_hook session-anchor.sh "$(json_cwd "$P5")"
case "$OUT" in
  *"open docket items: 2"*) ok ;;
  *) bad "expected 2 open (2 placeholders, 1 resolved): ${OUT:0:160}" ;;
esac

P6="$SANDBOX/proj-crash"; mkdir -p "$P6"
printf '# H\n\n## \n## 1. Next decidable\nx\n' > "$P6/HANDOFF.md"
t "anchor: bare '## ' line degrades instead of crashing (D5b)"
run_hook session-anchor.sh "$(json_cwd "$P6")"
if [ "$RC" -eq 0 ]; then
  assert_contains "Next decidable"
else
  bad "hook still exits $RC on malformed header"
fi

echo "== push-guard.sh =="

pg_proj() { # $1 name, $2 policy content ('' = no policy file)
  local d="$SANDBOX/pg-$1"
  mkdir -p "$d/.harness"
  [ -n "$2" ] && printf '%s\n' "$2" > "$d/.harness/push-policy"
  printf '%s' "$d"
}

t "guard: no policy file → silent allow"
D=$(pg_proj none '')
run_hook push-guard.sh "$(json_cmd 'git push origin master' "$D")"
assert_silent

D=$(pg_proj feat 'origin feature/*')
t "guard: matching ref glob allowed"
run_hook push-guard.sh "$(json_cmd 'git push origin feature/login' "$D")"
assert_silent
t "guard: non-matching ref denied"
run_hook push-guard.sh "$(json_cmd 'git push origin main' "$D")"
assert_deny
t "guard: force on allowed ref w/o force-ok denied"
run_hook push-guard.sh "$(json_cmd 'git push -f origin feature/login' "$D")"
assert_deny
t "guard: compound command still guarded (last push segment)"
run_hook push-guard.sh "$(json_cmd 'cd /tmp && git commit -m ok && git push origin main' "$D")"
assert_deny
t "guard: wrong remote denied"
run_hook push-guard.sh "$(json_cmd 'git push upstream feature/login' "$D")"
assert_deny

D=$(pg_proj force 'origin main force-ok')
t "guard: force-ok rule permits --force"
run_hook push-guard.sh "$(json_cmd 'git push --force origin main' "$D")"
assert_silent
t "guard: refspec src:dst judged by destination"
run_hook push-guard.sh "$(json_cmd 'git push origin HEAD:main' "$D")"
assert_silent

D=$(pg_proj any 'origin *')
t "guard: bare 'git push' allowed by origin-* rule"
run_hook push-guard.sh "$(json_cmd 'git push' "$D")"
assert_silent

D=$(pg_proj deny '# deny-all: no rules')
t "guard: comment-only policy denies everything"
run_hook push-guard.sh "$(json_cmd 'git push origin master' "$D")"
assert_deny

t "guard: non-push git command ignored (policy present)"
run_hook push-guard.sh "$(json_cmd 'git status' "$D")"
assert_silent

t "guard: substring 'push' in a path is not a push (H1)"
run_hook push-guard.sh "$(json_cmd 'git diff -- .harness/push-policy' "$D")"
assert_silent

t "guard: substring 'push' inside a commit message is not a push (H1)"
run_hook push-guard.sh "$(json_cmd 'git commit -m "docs: explain push-policy"' "$D")"
assert_silent

t "guard: compound: real push + innocent push-substring segment still denied (H1)"
run_hook push-guard.sh "$(json_cmd 'git push origin master && git diff -- .harness/push-policy' "$D")"
assert_deny

# A heredoc BODY is data, not command (peer session report + repro, 2026-08-15). H1 covered
# the substring vector; this is a different one: the body's words were lexed as TOKENS, so
# "run the gate on every push and pull request" in a commit message parsed as
# `git push and pull` and denied the legitimate push standing next to it. The first repro
# written for this used && and passed green on the broken hook — the failing shape needs the
# newline form, because re.split() does not (and must not) split on newlines.
D=$(pg_proj heredoc 'origin main')

t "guard: heredoc body naming push is not a push; the real one is allowed (newline form)"
run_hook push-guard.sh "$(json_cmd $'git commit -q -F - <<\'EOF\'\nfeat: gate\n\nrun the gate on every push and pull request\nEOF\ngit push origin main' "$D")"
assert_silent

t "guard: same shape via && (body lands after the separator)"
run_hook push-guard.sh "$(json_cmd $'git commit -q -F - <<\'EOF\' && git push origin main\nrun it on every push and pull request\nEOF' "$D")"
assert_silent

t "guard: embedded source with literal backslash-n does not glue the ref"
run_hook push-guard.sh "$(json_cmd $'python3 - <<\'PY\'\ncmd = "git commit -F - && git push origin main\\nfeat: gate"\nPY' "$D")"
assert_silent

t "guard: heredoc feeding a shell keeps its body under watch"
run_hook push-guard.sh "$(json_cmd $'bash <<\'EOF\'\ngit push origin release/v9\nEOF' "$D")"
assert_deny

t "guard: shell by absolute path also keeps its body under watch"
run_hook push-guard.sh "$(json_cmd $'/bin/sh <<\'EOF\'\ngit push origin release/v9\nEOF' "$D")"
assert_deny

# regression of the fix itself: a bare \bsh\b matched the ".sh" of a path on the opener
# line, so any command naming a shell script kept its body under the lexer — which is how
# the commit carrying this very fix got denied
t "guard: a .sh path on the opener line is not a shell-fed heredoc"
run_hook push-guard.sh "$(json_cmd $'git add hooks/push-guard.sh && git commit -q -F - <<\'EOF\'\nreported by a peer, a legitimate push of its own\nEOF' "$D")"
assert_silent

# the heredoc belongs to the LAST command opened before the <<, not to any shell named
# earlier in the chain: `bash gate.sh && git commit -F - <<EOF` is the shape of every
# repo with a suite (run the gate, commit, push) and it was denied
t "guard: a real shell earlier in the chain does not own git commit's heredoc"
run_hook push-guard.sh "$(json_cmd $'bash tests/run.sh && git commit -q -F - <<\'EOF\' && git push origin main\nrun it on every push and pull request\nEOF' "$D")"
assert_silent

t "guard: shell at the tail of a pipe does own its heredoc"
run_hook push-guard.sh "$(json_cmd $'cat prelude.txt | bash <<\'EOF\'\ngit push origin release/v9\nEOF' "$D")"
assert_deny

t "guard: shell as the last command of a chain does own its heredoc"
run_hook push-guard.sh "$(json_cmd $'git add -A && bash <<\'EOF\'\ngit push origin release/v9\nEOF' "$D")"
assert_deny


t "guard: unterminated heredoc is fail-closed (the push is still seen)"
run_hook push-guard.sh "$(json_cmd $'git commit -F - <<\'EOF\'\ngit push origin release/v9' "$D")"
assert_deny

t "guard: line continuation is whitespace, not a remote named newline"
run_hook push-guard.sh "$(json_cmd $'git push \\\n  origin main' "$D")"
assert_silent

t "guard: a second newline-separated push out of policy is judged too"
run_hook push-guard.sh "$(json_cmd $'git push origin main\ngit push origin release/v9' "$D")"
assert_deny

t "guard: a second, forced push after a lawful one is judged too"
run_hook push-guard.sh "$(json_cmd $'git push origin main\ngit push --force origin main' "$D")"
assert_deny

t "guard: invalid JSON input is a silent no-op"
run_hook push-guard.sh 'nope'
assert_silent

echo "== handoff-freshness.sh =="

HF="$SANDBOX/proj-fresh"; mkdir -p "$HF"
# HOME is the sandbox: no global gitconfig ⇒ per-repo identity mandatory
(cd "$HF" && git init -q && git config user.email t@t && git config user.name t \
  && printf 'x\n' > code.py && printf '# H\n' > HANDOFF.md && git add -A && git commit -qm c1)
t "freshness: HANDOFF updated after the last commit → silence"
sleep 1; touch "$HF/HANDOFF.md"
run_hook handoff-freshness.sh "$(json_cwd "$HF")"
assert_silent

t "freshness: commit after HANDOFF → warning with the delta"
(cd "$HF" && sleep 1 && printf 'y\n' >> code.py && git add -A && git commit -qm c2)
run_hook handoff-freshness.sh "$(json_cwd "$HF")"
assert_contains "handoff-freshness"

t "freshness: dirty uncommitted files → warning with the name INTACT"
(cd "$HF" && touch "$HF/HANDOFF.md" && printf 'z\n' >> code.py)
run_hook handoff-freshness.sh "$(json_cwd "$HF")"
case "$OUT" in # the name must be whole: "ode.py" = strip/porcelain regression (it5)
  *"code.py"*) assert_contains "uncommitted" ;;
  *) bad "filename truncated or absent: ${OUT:0:160}" ;;
esac

t "freshness: project without HANDOFF → silence"
NF="$SANDBOX/proj-nofresh"; mkdir -p "$NF"
(cd "$NF" && git init -q && git config user.email t@t && git config user.name t \
  && printf 'a\n' > f && git add -A && git commit -qm c)
run_hook handoff-freshness.sh "$(json_cwd "$NF")"
assert_silent

t "freshness: non-git directory → silence"
NG="$SANDBOX/proj-nogit"; mkdir -p "$NG"; printf '# H\n' > "$NG/HANDOFF.md"
run_hook handoff-freshness.sh "$(json_cwd "$NG")"
assert_silent

t "freshness: invalid JSON → silent no-op"
run_hook handoff-freshness.sh 'garbage'
assert_silent

echo "== notify-ntfy.sh =="

t "notify: no config → mute (opt-in)"
run_hook notify-ntfy.sh "$(json_prompt 'x')"
assert_silent

t "notify: config + DRY → payload printed with the message"
mkdir -p "$HOME/.config/harness"
printf 'https://ntfy.example/topic-test\n' > "$HOME/.config/harness/notify.conf"
OUT="$(printf '{"message":"test digest","cwd":"/x/proj"}' | HARNESS_NOTIFY_DRY=1 bash "$HOOKS/notify-ntfy.sh" 2>/dev/null)"; RC=$?
case "$OUT" in
  *'"dry": true'*'test digest'*) ok ;;
  *) bad "dry payload missing: ${OUT:0:160}" ;;
esac

t "notify: empty config → mute"
: > "$HOME/.config/harness/notify.conf"
run_hook notify-ntfy.sh '{"message":"x"}'
assert_silent

t "notify: broken JSON with config → mute"
printf 'https://ntfy.example/t\n' > "$HOME/.config/harness/notify.conf"
run_hook notify-ntfy.sh 'garbage'
assert_silent
rm -f "$HOME/.config/harness/notify.conf"

echo "== tools/docket.sh =="

DK="$SANDBOX/proj-docket"; mkdir -p "$DK/.harness/goals/g1" "$DK/.harness/goals/g2"
printf '# DOCKET\n\n## D1 · format choice\nbla 2026-07-01 bla\n**RULING:** _\n\n## D2 · already decided\n**RULING:** approved 07-02\n' > "$DK/.harness/goals/g1/docket.md"
printf '# DOCKET\n\n## X1 · what to do\n**RULING:** _(you tell me)\n' > "$DK/.harness/goals/g2/docket.md"

t "docket: list shows OPEN and ruled with id and goal"
OUT="$(CLAUDE_PROJECT_DIR="$DK" bash "$ROOT/tools/docket.sh" list 2>&1)"; RC=$?
case "$OUT" in
  *"OPEN "*g1*D1*|*OPEN*D1*) case "$OUT" in *ruled*D2*) ok ;; *) bad "ruled D2 missing: ${OUT:0:160}" ;; esac ;;
  *) bad "OPEN D1 missing: ${OUT:0:160}" ;;
esac

t "docket: list --open excludes the ruled"
OUT="$(CLAUDE_PROJECT_DIR="$DK" bash "$ROOT/tools/docket.sh" list --open 2>&1)"; RC=$?
case "$OUT" in
  *D2*) bad "D2 (ruled) shows up in --open" ;;
  *D1*X1*|*D1*) assert_contains "X1" ;;
esac

t "docket: rule fills the placeholder with date and signature"
G2_BEFORE="$(cat "$DK/.harness/goals/g2/docket.md")"
CLAUDE_PROJECT_DIR="$DK" bash "$ROOT/tools/docket.sh" rule D1 "approving proposal A" >/dev/null 2>&1
if grep -q '^\*\*RULING:\*\* approving proposal A (20.*via docket-cli)' "$DK/.harness/goals/g1/docket.md"; then ok; else bad "ruling not written: $(grep RULING "$DK/.harness/goals/g1/docket.md" | head -1)"; fi

t "docket: rule touches neither sibling entries nor other goals (anti-corruption it4)"
if grep -q '## D2' "$DK/.harness/goals/g1/docket.md" && grep -q 'approved 07-02' "$DK/.harness/goals/g1/docket.md" \
   && [ "$G2_BEFORE" = "$(cat "$DK/.harness/goals/g2/docket.md")" ]; then
  ok
else
  bad "corruption: D2 or g2 altered by the rule on D1"
fi

t "docket: rule refuses an already-ruled entry and leaves the file alone"
BEFORE="$(cat "$DK/.harness/goals/g1/docket.md")"
if CLAUDE_PROJECT_DIR="$DK" bash "$ROOT/tools/docket.sh" rule D2 "overwriting" >/dev/null 2>&1; then
  bad "exit 0 on an already-ruled entry"
else
  [ "$BEFORE" = "$(cat "$DK/.harness/goals/g1/docket.md")" ] && ok || bad "file modified despite the refusal"
fi

t "docket: rule on a nonexistent id fails"
if CLAUDE_PROJECT_DIR="$DK" bash "$ROOT/tools/docket.sh" rule ZZ9 "dunno" >/dev/null 2>&1; then bad "exit 0 on a nonexistent id"; else ok; fi

t "docket: rule on an id ambiguous across goals fails"
printf '\n## D1 · namesake in g2\n**RULING:** _\n' >> "$DK/.harness/goals/g2/docket.md"
if CLAUDE_PROJECT_DIR="$DK" bash "$ROOT/tools/docket.sh" rule D1 "which one?" >/dev/null 2>&1; then bad "exit 0 on an ambiguous id"; else ok; fi

echo "== git-hooks (E1): commit-msg + pre-push =="

GH="$SANDBOX/git-guards"; mkdir -p "$GH"
MSG="$GH/msg.txt"

t "git commit-msg: strips Co-Authored-By, keeps message"
printf 'fix: order totals\n\nCo-Authored-By: Claude Fable 5 <noreply@anthropic.com>\n' > "$MSG"
bash "$ROOT/git-hooks/commit-msg" "$MSG" 2>/dev/null
if grep -q 'fix: order totals' "$MSG" && ! grep -q 'Co-Authored-By' "$MSG"; then ok; else bad "attribution survived or message lost: $(cat "$MSG")"; fi

t "git commit-msg: clean message untouched"
printf 'feat: nothing special\n' > "$MSG"
GM_BEFORE="$(cat "$MSG")"
bash "$ROOT/git-hooks/commit-msg" "$MSG" 2>/dev/null
[ "$GM_BEFORE" = "$(cat "$MSG")" ] && ok || bad "clean message modified"

GR="$GH/repo"; mkdir -p "$GR"; git -C "$GR" init -q 2>/dev/null
SHA_A="aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
ZERO40="$(python3 -c 'print("0"*40)')"

t "git pre-push: deny-all policy denies"
mkdir -p "$GR/.harness"; printf '# deny-all\n' > "$GR/.harness/push-policy"
if ( cd "$GR" && printf 'refs/heads/master %s refs/heads/master %s\n' "$SHA_A" "$ZERO40" | bash "$ROOT/git-hooks/pre-push" origin git@example:x ) 2>/dev/null; then
  bad "expected exit != 0 under deny-all"
else ok; fi

t "git pre-push: matching rule allows"
printf 'origin master\n' > "$GR/.harness/push-policy"
if ( cd "$GR" && printf 'refs/heads/master %s refs/heads/master %s\n' "$SHA_A" "$ZERO40" | bash "$ROOT/git-hooks/pre-push" origin git@example:x ) 2>/dev/null; then
  ok
else bad "expected exit 0 on matching rule"; fi

t "git pre-push: branch outside rule denied"
if ( cd "$GR" && printf 'refs/heads/feat %s refs/heads/feat %s\n' "$SHA_A" "$ZERO40" | bash "$ROOT/git-hooks/pre-push" origin git@example:x ) 2>/dev/null; then
  bad "expected exit != 0 on non-matching ref"
else ok; fi

t "git pre-push: no policy file → allow"
rm "$GR/.harness/push-policy"
if ( cd "$GR" && printf 'refs/heads/master %s refs/heads/master %s\n' "$SHA_A" "$ZERO40" | bash "$ROOT/git-hooks/pre-push" origin git@example:x ) 2>/dev/null; then
  ok
else bad "expected exit 0 without policy"; fi

echo "== loop reliability (C10): loop-state + loop-guard + handoff-80 =="

LP="$SANDBOX/loopproj"; mkdir -p "$LP/.harness"
lp_json() { # session_id extra_python_dict_items...
  python3 -c 'import json,sys; d={"session_id":sys.argv[1],"cwd":sys.argv[2]}; d.update(json.loads(sys.argv[3])); print(json.dumps(d))' "$1" "$LP" "$2"
}

t "loop-state: ScheduleWakeup → active state with future next_wake"
run_hook loop-state.sh "$(lp_json s1 '{"tool_name":"ScheduleWakeup","tool_input":{"delaySeconds":600,"prompt":"continue the loop"}}')"
if [ "$RC" -eq 0 ] && python3 -c '
import json,sys,time
s=json.load(open(sys.argv[1]+"/.harness/loop-state.json"))
sys.exit(0 if s["status"]=="active" and s["session_id"]=="s1" and s["next_wake_epoch"]>time.time()+60 else 1)' "$LP"; then ok
else bad "state absent or malformed after the schedule"; fi

t "loop-guard: fresh schedule → close permitted"
run_hook loop-guard.sh "$(lp_json s1 '{}')"
if [ "$RC" -eq 0 ] && [ -z "$OUT" ]; then ok; else bad "unexpected block with next_wake in the future: $OUT"; fi

t "loop-guard: wake-up consumed and not replaced → BLOCK"
python3 -c '
import json,sys,time
p=sys.argv[1]+"/.harness/loop-state.json"; s=json.load(open(p))
s["next_wake_epoch"]=int(time.time())-120; json.dump(s,open(p,"w"))' "$LP"
run_hook loop-guard.sh "$(lp_json s1 '{}')"
if printf '%s' "$OUT" | grep -q '"decision": *"block"'; then ok; else bad "expected block, got: $OUT"; fi

t "loop-guard: DIFFERENT session in the same project → never blocked"
run_hook loop-guard.sh "$(lp_json other '{}')"
if [ "$RC" -eq 0 ] && [ -z "$OUT" ]; then ok; else bad "blocked a session that doesn't own the loop"; fi

t "loop-guard: stop_hook_active → lets it through (anti-recursion)"
run_hook loop-guard.sh "$(lp_json s1 '{"stop_hook_active":true}')"
if [ "$RC" -eq 0 ] && [ -z "$OUT" ]; then ok; else bad "block during the post-block continuation"; fi

t "loop-state: ScheduleWakeup stop:true → stopped state, guard stays quiet"
run_hook loop-state.sh "$(lp_json s1 '{"tool_name":"ScheduleWakeup","tool_input":{"stop":true}}')"
run_hook loop-guard.sh "$(lp_json s1 '{}')"
if [ "$RC" -eq 0 ] && [ -z "$OUT" ] && python3 -c '
import json,sys; s=json.load(open(sys.argv[1]+"/.harness/loop-state.json"))
sys.exit(0 if s["status"]=="stopped" else 1)' "$LP"; then ok
else bad "declared stop not recorded or guard blocking anyway"; fi

t "session-anchor: closed and paused goals excluded from the decision count"
SA="$SANDBOX/anchorproj"; mkdir -p "$SA/.harness/goals"/{live,closed,paused}
printf '# H\n\n## 1. Next decidable\nx\n' > "$SA/HANDOFF.md"
for g in live closed paused; do
  printf '## D1 · entry\n**RULING:** _\n' > "$SA/.harness/goals/$g/docket.md"
done
printf '| 1 | phase | dw | none | src | ready |\n' > "$SA/.harness/goals/live/PHASES.md"
printf '| 1 | phase | dw | none | src | **done** |\n' > "$SA/.harness/goals/closed/PHASES.md"
printf '| 1 | phase | dw | none | src | ready |\n' > "$SA/.harness/goals/paused/PHASES.md"
printf 'GOAL: x\nSTATUS: PAUSED (test)\n' > "$SA/.harness/goals/paused/GOAL.md"
run_hook session-anchor.sh "$(printf '{"cwd":"%s"}' "$SA")"
if printf '%s' "$OUT" | grep -q "active goal 'live'" &&
   ! printf '%s' "$OUT" | grep -q "active goal 'closed'" &&
   ! printf '%s' "$OUT" | grep -q "active goal 'paused'"; then ok
else bad "expected only the live goal: $(printf '%s' "$OUT" | head -c 200)"; fi

t "handoff-freshness: HANDOFF fresh but over 80 lines → warn"
HF="$SANDBOX/hf80"; mkdir -p "$HF"; git -C "$HF" init -q
printf 'x\n' > "$HF/f.txt"; git -C "$HF" add f.txt
git -C "$HF" -c user.email=t@t -c user.name=t commit -qm x
python3 -c 'open("'"$HF"'/HANDOFF.md","w").write("## 1. Next decidable\n"+"line\n"*99)'
run_hook handoff-freshness.sh "$(python3 -c 'import json,sys; print(json.dumps({"cwd":sys.argv[1]}))' "$HF")"
if printf '%s' "$OUT" | grep -q 'limit 80'; then ok; else bad "no warn on a 100-line HANDOFF: $OUT"; fi

t "session-anchor: repo ahead of the machine → drift warning (rule 2026-08-14)"
DR="$SANDBOX/driftproj"; mkdir -p "$DR"
printf '# H\n\n## 1. Next decidable\nx\n' > "$DR/HANDOFF.md"
printf '#!/usr/bin/env bash\necho "would install: hooks/foo.sh"\necho "would install: workflows/x.js"\n' > "$DR/install.sh"
run_hook session-anchor.sh "$(printf '{"cwd":"%s"}' "$DR")"
if printf '%s' "$OUT" | grep -q 'NOT in effect' && printf '%s' "$OUT" | grep -q 'hooks/foo.sh'; then ok
else bad "no drift warning: $(printf '%s' "$OUT" | head -c 200)"; fi

t "session-anchor: surface aligned → no warning (no noise when all is well)"
printf '#!/usr/bin/env bash\necho "install.sh: 0 installed, 55 unchanged"\n' > "$DR/install.sh"
run_hook session-anchor.sh "$(printf '{"cwd":"%s"}' "$DR")"
if printf '%s' "$OUT" | grep -q 'NOT in effect'; then bad "drift warning on a clean surface: $OUT"
else ok; fi

echo "== loop-watchdog: who is alive and who isn't (field report, 2026-08-14) =="
# The watchdog is not a hook: it is driven via env (roots, sidecar, state, log all
# overridable) and --dry-run, so no case revives a real session.
WD_SID="s0000000-aaaa-bbbb-cccc-000000000001"

# wd_case <name> <wake_off> <upd_off> <mtime_off> <transcript_off> <sidecar_off|none>
# Offsets in seconds relative to NOW (negative = past). Prints the case's base dir.
wd_case() {
  python3 - "$SANDBOX" "$WD_SID" "$@" <<'PY'
import json, os, sys, time
sandbox, sid, name = sys.argv[1], sys.argv[2], sys.argv[3]
wake, upd, fm, tr, sc = sys.argv[4:9]
now = time.time()
base = os.path.join(sandbox, "wd", name)
proj = os.path.join(base, "roots", "proj")
harness = os.path.join(proj, ".harness")
projects = os.path.join(base, "projects")
os.makedirs(harness, exist_ok=True)
sp = os.path.join(harness, "loop-state.json")
json.dump({"status": "active", "session_id": sid, "next_wake_epoch": int(now + float(wake)),
           "prompt": "continue the loop", "updated_epoch": int(now + float(upd))}, open(sp, "w"))
os.utime(sp, (now + float(fm),) * 2)
# Real layout: ~/.claude/projects/<cwd-with-dashes>/<sid>.jsonl and, alongside, the
# <sid>/ directory with subagents/, subagents/workflows/<runId>/, tool-results/.
sess = os.path.join(projects, proj.replace("/", "-"), sid)
os.makedirs(os.path.dirname(sess + ".jsonl"), exist_ok=True)
open(sess + ".jsonl", "w").write("{}\n")
os.utime(sess + ".jsonl", (now + float(tr),) * 2)
if sc != "none":
    wf = os.path.join(sess, "subagents", "workflows", "wf_test")
    os.makedirs(wf, exist_ok=True)
    open(os.path.join(wf, "agent-a1.jsonl"), "w").write("{}\n")
    os.utime(os.path.join(wf, "agent-a1.jsonl"), (now + float(sc),) * 2)
print(base)
PY
}

# wd_run <base> → OUT (watchdog stdout in dry-run)
wd_run() {
  OUT="$(HARNESS_WATCH_ROOTS="$1/roots" HARNESS_CLAUDE_PROJECTS="$1/projects" \
         HARNESS_WATCH_ATTEMPTS="$1/attempts.json" HARNESS_WATCH_LOG="$1/wd.log" \
         bash "$ROOT/tools/loop-watchdog.sh" --dry-run --verbose 2>/dev/null)"
}

t "loop-watchdog: workflow sidecar still growing = session ALIVE (defect 3)"
# 70 min of transcript silence, but the workflow is writing NOW: the case measured at
# 02:03 on ae3ad6a9, which produced the fourth ghost session.
B="$(wd_case livewf -600 -4200 -4200 -4200 -5)"; wd_run "$B"
if printf '%s' "$OUT" | grep -q RESUME; then bad "revived a session with a live sidecar: $OUT"
else ok; fi

t "loop-watchdog: silence everywhere (transcript AND sidecar) → RESUME"
B="$(wd_case dead -600 -4200 -4200 -4200 -4200)"; wd_run "$B"
if printf '%s' "$OUT" | grep -q 'RESUME.*no activity'; then ok
else bad "truly dead loop not revived: $OUT"; fi

t "loop-watchdog: state materialized after being written (git checkout) → SKIP"
# updated_epoch from an hour ago, file written to disk now: signature of a checkout.
B="$(wd_case checkout -3000 -3600 0 -4200 -4200)"; wd_run "$B"
if printf '%s' "$OUT" | grep -q 'SKIP.*checkout/copy'; then ok
else bad "expected refusal of the copied state, got: $OUT"; fi

t "loop-watchdog: wake-up overdue by 7 hours = staleness, not lateness → SKIP"
B="$(wd_case stale -25200 -28800 -28800 -28800 -28800)"; wd_run "$B"
if printf '%s' "$OUT" | grep -q 'SKIP.*staleness'; then ok
else bad "expected refusal for staleness, got: $OUT"; fi

t "loop-watchdog: headless_dead holds only for the session we had pushed (defect 2)"
# Previous push on ANOTHER session + transcript written now: before, prev_unit alone
# was enough to skip the liveness check ("RESUME ... transcript idle for 0 min").
B="$(wd_case sticky -600 -4200 -4200 -5 none)"
python3 -c 'import json,sys,time
json.dump({sys.argv[1]+"/roots/proj": {"epoch": int(time.time())-1200,
          "unit": "harness-resume-old-1", "sid": "OTHER-SESSION"}}, open(sys.argv[2],"w"))' \
  "$B" "$B/attempts.json"
wd_run "$B"
if printf '%s' "$OUT" | grep -q RESUME; then bad "pushed into a session that is writing: $OUT"
else ok; fi

t "loop-watchdog: truly dead headless loop → restarts without waiting the 15 min"
B="$(wd_case headless -600 -4200 -4200 -600 none)"
python3 -c 'import json,sys,time
json.dump({sys.argv[1]+"/roots/proj": {"epoch": int(time.time())-1200,
          "unit": "harness-resume-ours-1", "sid": sys.argv[3]}}, open(sys.argv[2],"w"))' \
  "$B" "$B/attempts.json" "$WD_SID"
wd_run "$B"
if printf '%s' "$OUT" | grep -q RESUME; then ok
else bad "dead headless loop not restarted (regression on the case C10 existed to cure): $OUT"; fi

echo "== purge-loop-state: the safety net must be WHERE it says it is =="
PG="$SANDBOX/purgerepo"; mkdir -p "$PG/.harness"
git -C "$PG" init -q
# identity in the repo, not only on the commit: $HOME is fake and commit-tree demands it
git -C "$PG" config user.email t@t; git -C "$PG" config user.name t
printf 'x\n' > "$PG/f.txt"; printf '{"status":"active"}\n' > "$PG/.harness/loop-state.json"
git -C "$PG" add -A; git -C "$PG" commit -qm "commit with tracked state"
git -C "$PG" branch free
git -C "$PG" worktree add -q -b busy "$SANDBOX/purgewt" >/dev/null 2>&1
PG_OUT="$(cd "$SANDBOX" && bash "$ROOT/tools/purge-loop-state.sh" "$PG" 2>&1)"

t "purge-loop-state: the rollback lands in the TARGET's .git, not the launcher's"
if [ -f "$PG/.git/loop-state-purge-rollback.txt" ] && [ ! -f "$SANDBOX/.git/loop-state-purge-rollback.txt" ]; then ok
else bad "rollback not in the target (or written in the cwd): $(ls "$PG/.git" | tr '\n' ' ')"; fi

t "purge-loop-state: every rollback line carries a SHA AND a readable title"
if grep -q 'commit with tracked state' "$PG/.git/loop-state-purge-rollback.txt" 2>/dev/null; then ok
else bad "rollback without a speaking handle: $(cat "$PG/.git/loop-state-purge-rollback.txt" 2>/dev/null)"; fi

t "purge-loop-state: the reflog doesn't stay anonymous"
if git -C "$PG" reflog show free 2>/dev/null | grep -q 'purge loop-state.json'; then ok
else bad "reflog line without a message: $(git -C "$PG" reflog show free 2>/dev/null | head -2)"; fi

t "purge-loop-state: free branch cleaned, worktree branch skipped"
if ! git -C "$PG" cat-file -e 'free:.harness/loop-state.json' 2>/dev/null &&
   git -C "$PG" cat-file -e 'busy:.harness/loop-state.json' 2>/dev/null &&
   printf '%s' "$PG_OUT" | grep -q 'SKIP     busy'; then ok
else bad "expected free cleaned and busy skipped: $PG_OUT"; fi

t "purge-loop-state: idempotent (second pass touches nothing)"
if bash "$ROOT/tools/purge-loop-state.sh" "$PG" 2>&1 | grep -q '^— 0 cleaned'; then ok
else bad "second pass not a no-op"; fi

echo "== workflows: check-workflows.sh (folded into this gate 2026-08-14) =="
# A sensor nobody runs doesn't exist: this runner sat OUTSIDE the gate, so the C12 marker
# wave broke 6 of its assertions silently while run.sh stayed green — found by the wave-2
# translator, not by any gate. Its result now counts here.
t "check-workflows: mechanical validation of workflows/*.workflow.js"
if bash "$ROOT/tests/check-workflows.sh" >/dev/null 2>&1; then ok
else bad "$(bash "$ROOT/tests/check-workflows.sh" 2>&1 | grep '^FAIL' | head -3)"; fi

echo "== plugin complement: what a plugin cannot carry, and must not carry twice =="
# The plugin channel delivers skills/agents/commands/hooks and nothing else — no workflows,
# no ORCHESTRATION.md at the path the skills cite, no statusLine. install.sh --plugin fills
# exactly that gap and refuses to install what the plugin already owns, because a second copy
# of a hook is a hook that fires twice. Every case below fails against a version without the
# flag (unknown flag ⇒ exit 2), which is what makes them evidence rather than decoration.
PC="$SANDBOX/plugin-complement"

t "install --plugin: installs workflows + ORCHESTRATION.md + hud"
PC1="$PC/a"; mkdir -p "$PC1"
HOME="$PC1" bash "$ROOT/install.sh" --plugin >/dev/null 2>&1
if [ -f "$PC1/.claude/workflows/sdd-conductor.workflow.js" ] &&
   [ -f "$PC1/.claude/ORCHESTRATION.md" ] &&
   [ -f "$PC1/.claude/hud/nightshift-hud.mjs" ]; then ok
else bad "complement incomplete: $(find "$PC1/.claude" -type f 2>/dev/null | wc -l) files installed"; fi

t "install --plugin: installs NOTHING the plugin already provides"
# The ORCHESTRATION.md precondition is load-bearing: without it a version that refuses the
# flag and installs nothing at all would pass this case for the wrong reason.
dupes=""
for p in hooks skills agents commands; do
  [ -d "$PC1/.claude/$p" ] && dupes="$dupes $p"
done
if [ -f "$PC1/.claude/ORCHESTRATION.md" ] && [ -z "$dupes" ]; then ok
elif [ ! -f "$PC1/.claude/ORCHESTRATION.md" ]; then bad "nothing was installed at all — vacuous pass avoided"
else bad "plugin-owned dirs created by the complement:$dupes"; fi

t "install --plugin --settings: sets statusLine, writes NO hooks block (double-firing guard)"
PC2="$PC/b"; mkdir -p "$PC2"
HOME="$PC2" bash "$ROOT/install.sh" --plugin --settings >/dev/null 2>&1
if grep -q 'nightshift-hud' "$PC2/.claude/settings.json" 2>/dev/null &&
   ! grep -q 'firefight-catch' "$PC2/.claude/settings.json" 2>/dev/null; then ok
else bad "settings.json wrong: $(tr -d '\n' < "$PC2/.claude/settings.json" 2>/dev/null | head -c 200)"; fi

t "install: --plugin and --enterprise are refused together, and says why"
# Asserting only the non-zero exit would pass on a version that rejects --plugin as unknown:
# same verdict, different reason. The message is what discriminates.
XOUT="$(HOME="$PC/c" bash "$ROOT/install.sh" --plugin --enterprise 2>&1)"
if [ -n "$XOUT" ] && printf '%s' "$XOUT" | grep -q -- '--enterprise excludes --plugin'; then ok
else bad "expected the exclusivity message, got: ${XOUT:0:120}"; fi

t "verify --plugin: PASSes on a complement-only surface"
if HOME="$PC2" bash "$ROOT/verify-install.sh" --plugin >/dev/null 2>&1; then ok
else bad "$(HOME="$PC2" bash "$ROOT/verify-install.sh" --plugin 2>&1 | grep '^FAIL' | head -2)"; fi

t "verify --plugin: FAILs when the plugin-owned surface is duplicated in ~/.claude"
PC3="$PC/d"; mkdir -p "$PC3"
HOME="$PC3" bash "$ROOT/install.sh" --plugin >/dev/null 2>&1
HOME="$PC3" bash "$ROOT/install.sh" >/dev/null 2>&1     # the mistake: both channels, one machine
# Again the message, not the exit code: an unknown-flag exit 2 is also non-zero.
if HOME="$PC3" bash "$ROOT/verify-install.sh" --plugin 2>&1 | grep -q 'plugin-owned surface duplicated'; then ok
else bad "the duplicated surface was not named"; fi

t "verify --plugin: FAILs when settings.json registers hooks the plugin already registers"
PC4="$PC/e"; mkdir -p "$PC4"
HOME="$PC4" bash "$ROOT/install.sh" --plugin >/dev/null 2>&1
HOME="$PC4" bash "$ROOT/install.sh" --settings >/dev/null 2>&1   # merges the hooks block too
if HOME="$PC4" bash "$ROOT/verify-install.sh" --plugin 2>&1 | grep -q 'hooks registered twice'; then ok
else bad "double registration not reported"; fi

# The duplication above is reachable by accident — install the plugin, then clone and run the
# installer the README shows. The default must refuse it, not produce it.
PCG="$PC/guard"; mkdir -p "$PCG/.claude"
printf '{"enabledPlugins": {"nightshift@nightshift": true}}\n' > "$PCG/.claude/settings.json"

t "install: refuses the full surface when the plugin is already installed"
GOUT="$(HOME="$PCG" bash "$ROOT/install.sh" 2>&1)"
if printf '%s' "$GOUT" | grep -q 'PLUGIN is already installed' && [ ! -d "$PCG/.claude/skills" ]; then ok
else bad "expected a refusal and no files; got: ${GOUT:0:140}"; fi

t "install --plugin: still allowed on a machine that has the plugin"
if HOME="$PCG" bash "$ROOT/install.sh" --plugin >/dev/null 2>&1 &&
   [ -f "$PCG/.claude/workflows/sdd-conductor.workflow.js" ] && [ ! -d "$PCG/.claude/skills" ]; then ok
else bad "the complement was blocked by the duplication guard"; fi

t "install --force: the override installs the full surface anyway"
if HOME="$PCG" bash "$ROOT/install.sh" --force >/dev/null 2>&1 &&
   [ -f "$PCG/.claude/skills/root-cause/SKILL.md" ]; then ok
else bad "--force did not override the guard"; fi

t "verify: a drift check that could not run says so instead of reporting agreement"
# $PCG now has the plugin AND a --force'd full surface, so a default --dry-run refuses. The
# sensor must not read that silence as "installed surface == repo".
if HOME="$PCG" bash "$ROOT/verify-install.sh" 2>&1 | grep -q 'drift check could not run'; then ok
else bad "the refused dry-run was read as a clean surface"; fi

t "install: a leftover plugin cache with the plugin NOT enabled does not block the install"
# Measured on a real machine: `marketplace add` alone, or an uninstall, leaves the cache
# directory behind. Keying the guard on that directory blocked installs where no plugin ran.
PCL="$PC/leftover"; mkdir -p "$PCL/.claude/plugins/cache/nightshift/nightshift/1.0.0/.claude-plugin"
printf '{"name":"nightshift"}' > "$PCL/.claude/plugins/cache/nightshift/nightshift/1.0.0/.claude-plugin/plugin.json"
printf '{"enabledPlugins": {"nightshift@nightshift": false}}\n' > "$PCL/.claude/settings.json"
if HOME="$PCL" bash "$ROOT/install.sh" >/dev/null 2>&1 &&
   [ -f "$PCL/.claude/skills/root-cause/SKILL.md" ]; then ok
else bad "a disabled plugin with a leftover cache blocked the installer"; fi

t "/nightshift-setup: the command ships and names the flag it drives"
if [ -f "$ROOT/commands/nightshift-setup.md" ] &&
   grep -q -- '--plugin' "$ROOT/commands/nightshift-setup.md" &&
   grep -q 'CLAUDE_PLUGIN_ROOT' "$ROOT/commands/nightshift-setup.md"; then ok
else bad "commands/nightshift-setup.md missing or does not drive install.sh --plugin"; fi

echo
printf '== summary: %d pass, %d fail, %d known-gap ==\n' "$PASS" "$FAIL" "$GAP"
[ "$FAIL" -eq 0 ]
