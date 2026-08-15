#!/usr/bin/env bash
# verify-install.sh — automates the README "Verify it took" checks that do not need a live
# Claude session. Run after ./install.sh; checks the installed surface under $HOME/.claude.
# Exit 0 = installed surface sound. WARN lines don't fail the run (they flag the manual
# steps: settings registration, plugins). The two live-session checks §C.9 keeps for you:
# "new session shows only your skills" and "session start echoes HANDOFF §1 in-session".
# --enterprise: grade an ./install.sh --enterprise surface — hook presence, hook
# fixtures and settings-registration checks are skipped (docs/ENTERPRISE.md §6).
# --plugin: grade an ./install.sh --plugin surface (plugin installed + complement). What the
# plugin owns is checked for ABSENCE here: a copy in ~/.claude on top of the plugin's is a
# double surface, and for hooks a double firing.

set -u

DEST="${HOME}/.claude"
PASS=0 FAIL=0 WARN=0
ENTERPRISE=0
PLUGIN=0
for arg in "$@"; do
  case "$arg" in
    --enterprise) ENTERPRISE=1 ;;
    --plugin) PLUGIN=1 ;;
    *) printf 'verify-install.sh: unknown flag: %s\n' "$arg" >&2; exit 2 ;;
  esac
done
if [ "$ENTERPRISE" -eq 1 ] && [ "$PLUGIN" -eq 1 ]; then
  printf 'verify-install.sh: --enterprise excludes --plugin (install.sh refuses that combination too)\n' >&2
  exit 2
fi

ok()   { PASS=$((PASS + 1)); printf 'PASS  %s\n' "$1"; }
bad()  { FAIL=$((FAIL + 1)); printf 'FAIL  %s\n      %s\n' "$1" "$2"; }
warn() { WARN=$((WARN + 1)); printf 'WARN  %s\n      %s\n' "$1" "$2"; }

# --- presence + mode ---
if [ "$ENTERPRISE" -eq 1 ]; then
  ok "enterprise mode: hook checks skipped by design (managed settings block them)"
elif [ "$PLUGIN" -eq 1 ]; then
  # The plugin owns hooks/skills/agents/commands. Finding them HERE too is the defect this
  # mode exists to catch: two copies of every hook, fired twice per event.
  dup=""
  for h in strip-ai-attribution firefight-catch session-anchor push-guard handoff-freshness notify-ntfy loop-state loop-guard; do
    [ -e "$DEST/hooks/$h.sh" ] && dup="$dup hooks/$h.sh"
  done
  for s in root-cause 'done' handoff loop-iteration peripheral-vision spec-first goal-setup; do
    [ -e "$DEST/skills/$s/SKILL.md" ] && dup="$dup skills/$s"
  done
  for a in loop-verifier scout consistency-sweep adversarial-reviewer; do
    [ -e "$DEST/agents/$a.md" ] && dup="$dup agents/$a.md"
  done
  for c in research-loop product-loop goal-brief handoff pr-message weekly-maintenance; do
    [ -e "$DEST/commands/$c.md" ] && dup="$dup commands/$c.md"
  done
  if [ -z "$dup" ]; then
    ok "plugin mode: no second copy of what the plugin provides"
  else
    bad "plugin-owned surface duplicated in ~/.claude" \
        "these exist in both the plugin and ~/.claude — every duplicated hook fires twice:$dup
  → remedy: remove them from ~/.claude, or drop the plugin and use ./install.sh alone"
  fi
else
  for h in strip-ai-attribution firefight-catch session-anchor push-guard handoff-freshness notify-ntfy; do
    f="$DEST/hooks/$h.sh"
    if [ -x "$f" ]; then ok "hook $h.sh present+executable"; else bad "hook $h.sh" "missing or not executable at ${f#"$HOME"/}"; fi
  done
fi

if [ "$PLUGIN" -eq 0 ]; then
  for s in root-cause 'done' handoff loop-iteration peripheral-vision spec-first goal-setup; do
    f="$DEST/skills/$s/SKILL.md"
    if [ -f "$f" ]; then ok "skill $s"; else bad "skill $s" "missing ${f#"$HOME"/}"; fi
  done
fi

# vendored superpowers four — OPTIONAL (install.sh --with-vendored). Verified only when
# present: a default install carries this project's own skills and nothing third-party.
if [ -f "$DEST/skills/brainstorming/SKILL.md" ]; then
  for s in subagent-driven-development writing-plans brainstorming writing-skills; do
    f="$DEST/skills/$s/SKILL.md"
    if [ -f "$f" ] && grep -q 'vendored: superpowers' "$f"; then
      ok "vendored skill $s (provenance present)"
    else
      bad "vendored skill $s" "missing or lacks provenance header at ${f#"$HOME"/}"
    fi
  done
  if [ -f "$DEST/skills/subagent-driven-development/scripts/task-brief" ]; then
    ok "vendored skills installed recursively (nested scripts/ present)"
  else
    bad "vendored nesting" "skills/subagent-driven-development/scripts/task-brief missing — flat copy?"
  fi
else
  ok "vendored skills absent (default install: own skills only)"
fi

if [ "$PLUGIN" -eq 0 ]; then
  for a in loop-verifier scout consistency-sweep adversarial-reviewer; do
    f="$DEST/agents/$a.md"
    if [ -f "$f" ]; then ok "agent $a"; else bad "agent $a" "missing ${f#"$HOME"/}"; fi
  done

  for c in research-loop product-loop goal-brief handoff pr-message weekly-maintenance; do
    f="$DEST/commands/$c.md"
    if [ -f "$f" ]; then ok "command /$c"; else bad "command /$c" "missing ${f#"$HOME"/}"; fi
  done
fi

# protocol reference — cited by skills as ~/.claude/ORCHESTRATION.md, so it is required in
# every mode. In plugin mode it is one of the three things the complement exists to carry.
if [ -f "$DEST/ORCHESTRATION.md" ]; then
  ok "protocol reference ORCHESTRATION.md"
else
  bad "protocol reference" "missing .claude/ORCHESTRATION.md — skills cite it by that path"
fi

# executable workflows (R9): present and with a meta block at the top
for w in pattern-coverage second-opinion research-campaign; do
  f="$DEST/workflows/$w.workflow.js"
  if [ -f "$f" ] && head -30 "$f" | grep -q '^export const meta = {'; then
    ok "workflow $w (meta ok)"
  else
    bad "workflow $w" "missing or lacks meta block at ${f#"$HOME"/}"
  fi
done

# statusline (nightshift-hud, §C.6ter): present and parseable
f="$DEST/hud/nightshift-hud.mjs"
if [ ! -f "$f" ]; then
  bad "statusline nightshift-hud.mjs" "missing ${f#"$HOME"/}"
elif command -v node >/dev/null 2>&1 && ! node --check "$f" 2>/dev/null; then
  bad "statusline nightshift-hud.mjs" "node --check failed (syntax error)"
else
  ok "statusline nightshift-hud.mjs present"
fi

# --- salience budget: installed skills ≤ 12 (README: "skill count is a budget") ---
n_skills=$(find "$DEST/skills" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l)
if [ "$n_skills" -le 12 ]; then
  ok "installed skill surface ≤ 12 (found $n_skills)"
else
  bad "installed skill surface" "$n_skills skills installed — over the §C.4 cap of 12; prune"
fi

# --- self-containment: installed skills must cite neither absent files nor ruling
# siglas (the docket does NOT get installed). Found 2026-08-13: goal-setup cited a
# nonexistent "ORCHESTRATION.md §2" plus ~20 unresolvable "ruling C7/C9" citations. ---
dangling=""
for f in "$DEST"/skills/*/SKILL.md; do
  [ -f "$f" ] || continue
  case "$(basename "$(dirname "$f")")" in humanizer|writing-plans|subagent-driven-development|writing-skills|brainstorming) continue ;; esac
  grep -qE '\(ruling [A-Z][0-9]+\)' "$f" && dangling="$dangling $(basename "$(dirname "$f")"):sigla"
  for ref in $(grep -oE '\b[A-Z][A-Z-]+\.md' "$f" | sort -u); do
    [ -f "$DEST/$ref" ] || [ -f "$DEST/skills/$(basename "$(dirname "$f")")/$ref" ] || {
      case "$ref" in GOAL.md|PHASES.md|HANDOFF.md|AGENDA.md|CLAUDE.md|MEMORY.md|GLOSSARY.md|SPEC.md|README.md) ;; # per-project, not installed
        *) dangling="$dangling $(basename "$(dirname "$f")"):$ref" ;; esac; }
  done
done
if [ -z "$dangling" ]; then
  ok "installed skills self-contained (no dangling refs/siglas)"
else
  bad "installed skills reference what isn't installed" "$dangling"
fi

# --- workflow: the documented Invoke line must name EVERY field the code demands.
# Twin class of the dead references: declared contract ≠ real contract (found
# 2026-08-13 by whoever invoked research-campaign the way they had understood it). ---
wf_drift=""
for f in "$DEST"/workflows/*.workflow.js; do
  [ -f "$f" ] || continue
  wname=$(basename "$f" .workflow.js)
  header=$(sed -n '1,25p' "$f")
  # required fields = those cited in the "required args: {...}" errors before the '?'
  # (marker moved from Italian "args richiesti" in the C12 English wave — sources and
  #  this grep are shared derived state and moved together, 2026-08-14)
  req=$(grep -o "required args[^']*" "$f" | grep -o '{[^}]*}' | tr ',' '\n' \
        | grep -oE '^\s*\{?\s*[a-zA-Z]+' | tr -d '{ ' | sort -u)
  for field in $req; do
    printf '%s' "$header" | grep -q "$field" || wf_drift="$wf_drift $wname:$field"
  done
done
if [ -z "$wf_drift" ]; then
  ok "workflow Invoke lines name every required arg"
else
  bad "workflow docs drift from code" "required fields not documented in the header:$wf_drift"
fi

# --- repo → machine drift: what is fixed HERE must be in effect THERE.
# On 2026-08-14 hooks/loop-state.sh was fixed in the repo and two days stale in
# ~/.claude/hooks: the fix existed and didn't run, and no check said so. The sensor was
# already there (install.sh --dry-run compares with cmp): nobody was looking at it. ---
SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -x "$SRC_DIR/install.sh" ] || [ -f "$SRC_DIR/install.sh" ]; then
  # The dry-run must model the SAME install this surface came from, or the parts a mode
  # deliberately excludes read as drift: under --enterprise, hooks/ is skipped by design and a
  # plain --dry-run reports all 8 of them as "not in effect". Same for vendored, which is
  # opt-in — a default install must not be told it is missing what it chose not to take.
  drift_flags=""
  [ "$ENTERPRISE" -eq 1 ] && drift_flags="--enterprise"
  [ "$PLUGIN" -eq 1 ] && drift_flags="--plugin"
  [ -f "$DEST/skills/brainstorming/SKILL.md" ] && drift_flags="$drift_flags --with-vendored"
  # shellcheck disable=SC2086  # word splitting is the point: 0-2 flags
  drift="$(bash "$SRC_DIR/install.sh" --dry-run $drift_flags 2>/dev/null | grep '^would install:' | sed 's/^would install: /  /')"
  if [ -z "$drift" ]; then
    ok "installed surface == repo (no fix that exists only here)"
  else
    bad "the repo is ahead of the machine: changes not in effect" \
        "$(printf '%s\n' "$drift" | head -10)
  → remedy: ./install.sh"
  fi
fi

# --- functional fixtures (hooks behave, not just exist) ---
if [ "$PLUGIN" -eq 1 ]; then
  warn "plugin mode: hook fixtures skipped" "the hooks run from the plugin root, not ~/.claude/hooks — drive them with: bash tests/run.sh"
fi
if [ "$ENTERPRISE" -eq 0 ] && [ "$PLUGIN" -eq 0 ]; then
SB="$(mktemp -d)"
trap 'rm -rf "$SB"' EXIT

out=$(printf '{"prompt": "done?"}' | bash "$DEST/hooks/firefight-catch.sh" 2>/dev/null || true)
case "$out" in
  *"Polling detected"*) ok "firefight-catch: 'done?' triggers the polling note" ;;
  *) bad "firefight-catch functional" "no polling context on 'done?': ${out:0:120}" ;;
esac

out=$(printf '%s' '{"tool_input":{"command":"git commit -m \"x\n\nCo-Authored-By: Claude <noreply@anthropic.com>\""}}' \
      | bash "$DEST/hooks/strip-ai-attribution.sh" 2>/dev/null || true)
case "$out" in
  *updatedInput*) case "$out" in *Co-Authored-By*Claude*Co-Authored-By*) bad "strip-ai-attribution functional" "attribution survived" ;; *) ok "strip-ai-attribution: strips Co-Authored-By" ;; esac ;;
  *) bad "strip-ai-attribution functional" "no rewrite emitted: ${out:0:120}" ;;
esac

mkdir -p "$SB/proj/.harness"
printf '# deny-all\n' > "$SB/proj/.harness/push-policy"
out=$(printf '{"tool_input":{"command":"git push origin main"},"cwd":"%s"}' "$SB/proj" \
      | CLAUDE_PROJECT_DIR="$SB/proj" bash "$DEST/hooks/push-guard.sh" 2>/dev/null || true)
case "$out" in
  *'"deny"'*) ok "push-guard: deny-all policy denies" ;;
  *)          bad "push-guard functional" "expected deny, got: ${out:0:120}" ;;
esac

printf '# H\n\n## 1. Next decidable\nsentinel-anchor-check\n' > "$SB/proj/HANDOFF.md"
out=$(printf '{"cwd":"%s"}' "$SB/proj" | CLAUDE_PROJECT_DIR="$SB/proj" bash "$DEST/hooks/session-anchor.sh" 2>/dev/null || true)
case "$out" in
  *sentinel-anchor-check*) ok "session-anchor: emits HANDOFF §1" ;;
  *)                       bad "session-anchor functional" "sentinel not echoed: ${out:0:120}" ;;
esac
fi

# --- manual-step reminders (never fail) ---
if [ "$ENTERPRISE" -eq 1 ]; then
  warn "enterprise mode" "hooks unregistered by design; run the on-site policy checklist (docs/ENTERPRISE.md §5)"
elif [ "$PLUGIN" -eq 1 ]; then
  SETTINGS="$DEST/settings.json"
  if [ -f "$SETTINGS" ]; then
    # A hook registered BOTH by the plugin and by settings.json fires twice. The complement
    # never writes them; anything found here came from a plain --settings run on top.
    reg=""
    for h in strip-ai-attribution firefight-catch session-anchor push-guard handoff-freshness loop-state loop-guard notify-ntfy; do
      grep -q "$h" "$SETTINGS" 2>/dev/null && reg="$reg $h"
    done
    if [ -z "$reg" ]; then
      ok "settings.json registers no hook (the plugin does that)"
    else
      bad "hooks registered twice" "settings.json also registers:$reg — each fires once per registration
  → remedy: remove the nightshift hooks block from settings.json; ./install.sh --plugin --settings never writes it"
    fi
    if grep -q 'nightshift-hud' "$SETTINGS" 2>/dev/null; then
      ok "settings.json sets the nightshift-hud statusLine"
    else
      warn "statusLine not set" "run ./install.sh --plugin --settings (a plugin cannot set it)"
    fi
  else
    warn "settings.json absent" "statusLine pending: ./install.sh --plugin --settings"
  fi
else
SETTINGS="$DEST/settings.json"
if [ -f "$SETTINGS" ]; then
  for h in strip-ai-attribution firefight-catch session-anchor push-guard handoff-freshness loop-state loop-guard; do
    if grep -q "$h" "$SETTINGS" 2>/dev/null; then
      ok "settings.json references $h"
    else
      warn "settings.json: $h not registered" "merge the snippet from hooks/$h.sh header (manual step §C.3)"
    fi
  done
else
  warn "settings.json absent" "hook registration pending (manual step §C.1/§C.3)"
fi
fi

printf '\n== verify-install: %d pass, %d fail, %d warn ==\n' "$PASS" "$FAIL" "$WARN"
[ "$FAIL" -eq 0 ]
