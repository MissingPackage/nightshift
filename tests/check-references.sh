#!/usr/bin/env bash
# check-references.sh — reference closure for docs/COOKBOOK.md (phase 5 gate).
# Every command/skill/agent/hook the blueprints name must resolve to a file in this repo,
# be a native Claude Code command, or be a DECLARED external. Exit 0 = closed.
#
# Extraction: tokens inside backtick spans. Two classes:
#   /name        → commands/name.md | NATIVE | EXTERNAL
#   bare-name    → skills/<n>/SKILL.md | skills/vendored/<n>/SKILL.md | agents/<n>.md
#                  | hooks/<n>.sh | commands/<n>.md | VOCAB (protocol words, not artifacts)
# Unknown bare tokens that don't resolve are IGNORED unless they look artifact-like
# (kebab-case, ≥4 chars) — those fail, so a renamed skill can't dangle silently.

set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BP="$ROOT/docs/COOKBOOK.md"

NATIVE="/goal /loop"
EXTERNAL="/codex"                                  # external plugin: named in the cookbook, lives outside this repoC.7
VOCAB="plan-check mystery done-report goal-brief force-ok push-policy project"

fail=0
resolve_slash() {
  local t="$1"
  case " $NATIVE $EXTERNAL " in *" $t "*) return 0 ;; esac
  [ -f "$ROOT/commands/${t#/}.md" ]
}
resolve_bare() {
  local t="$1"
  case " $VOCAB " in *" $t "*) return 0 ;; esac
  [ -f "$ROOT/skills/$t/SKILL.md" ] || [ -f "$ROOT/skills/vendored/$t/SKILL.md" ] \
    || [ -f "$ROOT/agents/$t.md" ] || [ -f "$ROOT/hooks/$t.sh" ] || [ -f "$ROOT/commands/$t.md" ]
}

# tokens inside backtick spans, split on whitespace
# shellcheck disable=SC2016  # literal backticks in the grep pattern, not expansion
TOKENS="$(grep -oE '`[^`]+`' "$BP" | tr -d '`' | tr ' ' '\n' | sort -u)"

while IFS= read -r tok; do
  [ -z "$tok" ] && continue
  case "$tok" in
    /*)
      t="$(printf '%s' "$tok" | grep -oE '^/[a-z][a-z-]*' || true)"
      [ -z "$t" ] && continue
      if resolve_slash "$t"; then
        printf 'OK    %s\n' "$t"
      else
        printf 'FAIL  %s (nessuna commands/%s.md, non nativo, non esterno dichiarato)\n' "$t" "${t#/}"
        fail=1
      fi
      ;;
    *)
      printf '%s' "$tok" | grep -qE '^[a-z][a-z0-9]*(-[a-z0-9]+)+$' || continue
      if resolve_bare "$tok"; then
        printf 'OK    %s\n' "$tok"
      else
        printf 'FAIL  %s (artifact-like, non risolve in skills/ agents/ hooks/ commands/ né VOCAB)\n' "$tok"
        fail=1
      fi
      ;;
  esac
done <<EOF
$TOKENS
EOF

# single-word artifacts can't be told from prose mechanically — curated CORE list,
# checked for existence directly (a rename breaks this loudly instead of silently)
for core in scout:agents/scout.md done:skills/done/SKILL.md handoff:skills/handoff/SKILL.md \
            loop-verifier:agents/loop-verifier.md; do
  name="${core%%:*}" path="${core#*:}"
  if [ -f "$ROOT/$path" ]; then
    printf 'OK    %s (core)\n' "$name"
  else
    printf 'FAIL  %s (core artifact missing: %s)\n' "$name" "$path"
    fail=1
  fi
done

[ "$fail" -eq 0 ] && echo "== reference closure: OK ==" || echo "== reference closure: FAIL =="
exit "$fail"
