#!/usr/bin/env bash
# check-workflows.sh — mechanical validation of workflows/*.workflow.js (phase 6 gate).
# The Workflow tool runtime executes the body inside an async function (top-level return
# and await are legal there): the syntax check replicates that wrapping, then node --check
# as ESM. Plus: literal meta block present with name/description; the titles in meta.phases
# actually appear in the body (phase('X') or opts {phase: 'X'}); no Date.now/Math.random/
# new Date() (they would break resume — forbidden by the tool contract).

set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fail=0
found=0

for f in "$ROOT"/workflows/*.workflow.js; do
  [ -f "$f" ] || continue
  found=$((found + 1))
  name="$(basename "$f")"

  if ! head -30 "$f" | grep -q '^export const meta = {'; then
    # shellcheck disable=SC2016  # literal backticks in the message, no expansion intended
    printf 'FAIL  %s: missing `export const meta = {` at the top\n' "$name"; fail=1
  fi
  for key in "name:" "description:"; do
    grep -q "^  $key" "$f" || { printf 'FAIL  %s: meta without %s\n' "$name" "$key"; fail=1; }
  done

  # wrapping faithful to the runtime, then ESM syntax check
  tmp="$(mktemp --suffix=.mjs)"
  {
    echo 'const args = {}, budget = {};'
    echo 'async function agent(){} async function parallel(){} async function pipeline(){}'
    echo 'function phase(){} function log(){} async function workflow(){}'
    echo 'export default (async () => {'
    sed 's/^export const meta/const meta/' "$f"
    echo '});'
  } > "$tmp"
  if node --check "$tmp" 2>/dev/null; then
    printf 'OK    %s: syntax (wrapped) valid\n' "$name"
  else
    printf 'FAIL  %s: node --check (wrapped):\n' "$name"
    node --check "$tmp" 2>&1 | sed 's/^/      /' | head -5
    fail=1
  fi
  rm -f "$tmp"

  # every meta.phases title must appear in the body
  while IFS= read -r title; do
    [ -z "$title" ] && continue
    if grep -q "phase: '$title'" "$f" || grep -q "phase('$title')" "$f"; then
      printf 'OK    %s: phase "%s" used in the body\n' "$name" "$title"
    else
      printf 'FAIL  %s: phase "%s" declared in meta but never used\n' "$name" "$title"; fail=1
    fi
  done <<EOF
$(grep -oE "title: '[^']+'" "$f" | sed "s/title: '//; s/'$//")
EOF

  if grep -nE 'Date\.now\(|Math\.random\(|new Date\(\)' "$f"; then
    printf 'FAIL  %s: resume-forbidden primitives (Date.now/Math.random/new Date)\n' "$name"; fail=1
  else
    printf 'OK    %s: no anti-resume primitive\n' "$name"
  fi
done

# --- sdd-conductor: Plan phase + BLOCKED paths EXECUTED with scripted agents (goal sdd-conductor f1-f2) ---
# The wrapping replicates the runtime; agent() answers by label-prefix from the fixture's
# __script => validations, pre-flight, review and integrate chains run on the REAL file.
run_conductor() { # $1 args-json-file · $2 budget-total ('' = no budget) → stdout; rc
  local tmp rc
  tmp="$(mktemp --suffix=.mjs)"
  {
    printf 'const args = %s;\n' "$(cat "$1")"
    if [ -n "$2" ]; then
      printf 'const budget = {total: %s, spent: () => 0, remaining: () => %s};\n' "$2" "$2"
    else
      echo 'const budget = {total: null, spent: () => 0, remaining: () => Infinity};'
    fi
    echo 'async function agent(p, o){ const k = (o && o.label) || ""; const s = args.__script || {}; for (const pat of Object.keys(s)) { if (k.startsWith(pat)) return s[pat]; } return args.__plan; }'
    echo 'async function parallel(thunks){ return Promise.all(thunks.map(fn => fn().catch(() => null))); }'
    echo 'async function pipeline(){} function phase(){} function log(){} async function workflow(){ return null; }'
    echo 'export default (async () => {'
    sed 's/^export const meta/const meta/' "$ROOT/workflows/sdd-conductor.workflow.js"
    echo '});'
  } > "$tmp"
  node --input-type=module -e "const m = await import('file://' + process.argv[1]); try { const r = await m.default(); console.log('RESULT ' + JSON.stringify(r)); } catch (e) { console.log('REJECTED: ' + e.message); process.exit(3); }" "$tmp" 2>&1
  rc=$?
  rm -f "$tmp"
  return $rc
}

FX="$ROOT/workflows/fixtures/sdd"
ck() { # $1 name · $2 expected-rc (0|3) · $3 required pattern in the output · $4 output
  if [ "$5" = "$2" ] && printf '%s' "$4" | grep -q "$3"; then
    printf 'OK    sdd-conductor: %s\n' "$1"
  else
    printf 'FAIL  sdd-conductor: %s — rc=%s (expected %s), out: %.200s\n' "$1" "$5" "$2" "$4"; fail=1
  fi
}

OUT="$(run_conductor "$FX/args-plan-only.json" '')"; ck 'valid plan stops at execute-args (Plan+preflight passed)' 3 'required args to execute' "$OUT" "$?"
OUT="$(run_conductor "$FX/args-owns-overlap.json" '')"; ck 'overlapping owns rejected' 3 'owns' "$OUT" "$?"
OUT="$(run_conductor "$FX/args-cycle.json" '')"; ck 'cyclic graph rejected' 3 'cyclic' "$OUT" "$?"
OUT="$(run_conductor "$FX/args-empty-donewhen.json" '')"; ck 'empty doneWhen rejected' 3 'doneWhen' "$OUT" "$?"
OUT="$(run_conductor "$FX/args-empty-tasks.json" '')"; ck 'empty plan rejected (defense beyond the schema)' 3 'empty plan' "$OUT" "$?"
OUT="$(run_conductor "$FX/args-plan-only.json" 300000)"; ck 'pre-flight rejects with the estimate printed' 3 'pre-flight.*estimate\|estimate.*pre-flight' "$OUT" "$?"
OUT="$(run_conductor "$FX/args-happy.json" '')"; ck 'happy path: 2 tasks integrated, green suite, status done' 0 '"status":"done".*"done":\["a","b"\]' "$OUT" "$?"
OUT="$(run_conductor "$FX/args-critical.json" '')"; ck 'critical surviving round 2 => task BLOCKED + docketEntry' 0 'done-with-blocked.*SDD-a' "$OUT" "$?"
OUT="$(run_conductor "$FX/args-conflict.json" '')"; ck 'patch-apply conflict => BLOCKED, never auto-resolved' 0 'patch-apply conflict' "$OUT" "$?"
OUT="$(run_conductor "$FX/args-steering.json" '')"; ck 'steering opt-in: stops after the first wave with nextWave' 0 'wave-complete.*"nextWave":\["b"\]' "$OUT" "$?"
OUT="$(run_conductor "$FX/args-suite-red.json" '')"; ck 'post-merge red suite => build stopped' 0 '"status":"blocked".*red suite' "$OUT" "$?"
OUT="$(run_conductor "$FX/args-verify-ko.json" '')"; ck 'independent verification fails a task => BLOCKED (anti lying-integrator)' 0 'independent post-merge verification failed' "$OUT" "$?"

[ "$found" -ge 2 ] || { printf 'FAIL  expected >=2 executable workflows, found %d\n' "$found"; fail=1; }
[ "$fail" -eq 0 ] && echo "== workflows: OK ($found file) ==" || echo "== workflows: FAIL =="
exit "$fail"
