#!/usr/bin/env bash
# check-no-secrets.sh — refuses to let credential shapes, machine-local paths, or personal
# email addresses land in a public repository. Runs in CI on every push and pull request,
# and locally as part of the gate set.
#
# Scope, deliberately: this checks SHAPES, not a list of names. A denylist of the names you
# want kept private would itself have to live here, in public, which publishes exactly what
# it is meant to protect. Project-specific identifier checks belong upstream, in whatever
# private tooling produces or reviews the contribution — not in this file.
#
# Usage: bash tests/check-no-secrets.sh [path]     (default: repo root)
# Exit:  0 clean · 1 findings

set -uo pipefail
ROOT="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
SELF="$(basename "${BASH_SOURCE[0]}")"
findings=0

report() { findings=$((findings + 1)); printf 'FAIL  %s\n%s\n' "$1" "$(printf '%s\n' "$2" | sed 's/^/      /' | head -12)"; }

scan() { # <label> <regex> [allow-regex to filter out]
  local out err
  err="$(mktemp)"
  out="$(grep -rInE "$2" "$ROOT" \
        --exclude-dir=.git --exclude-dir=node_modules --exclude="$SELF" 2>"$err")"
  # a pattern grep cannot compile is a check that silently never fires — louder than a finding
  if [ -s "$err" ]; then
    report "SCANNER BROKEN: $1" "$(cat "$err")"
    rm -f "$err"; return 0
  fi
  rm -f "$err"
  [ -n "${3:-}" ] && out="$(printf '%s' "$out" | grep -vE "$3")"
  out="$(printf '%s' "$out" | cut -c1-160)"
  [ -n "$out" ] && report "$1" "$out"
  return 0
}

# credential shapes
scan "JWT-shaped token"        'eyJ[A-Za-z0-9_-]{16,}\.[A-Za-z0-9_-]{16,}'
scan "OpenAI-style API key"    'sk-[A-Za-z0-9]{32,}'
scan "GitHub token"            'gh[pousr]_[A-Za-z0-9]{30,}'
scan "AWS access key id"       'AKIA[0-9A-Z]{16}'
scan "Slack token"             'xox[baprs]-[0-9A-Za-z-]{10,}'
scan "private key block"       'BEGIN (RSA |EC |OPENSSH |DSA |PGP )?PRIVATE KEY'
scan "assigned secret literal" '(api[_-]?key|secret|passwd|password|token)[[:space:]]*[:=][[:space:]]*["'"'"'][^"'"'"'{$][^"'"'"']{7,}["'"'"']'

# machine-local leakage: an absolute home path pins the author's username and layout
scan "absolute home path"      '/(home|Users)/[a-z][a-z0-9_-]{1,31}/'

# real email addresses. ERE has no negative lookahead, so the allowlist is a second pass:
# example.com/.org (RFC 2606 reserved) and GitHub noreply are fine.
# noreply@ is allowed too: the attribution-stripping fixtures must contain the literal
# trailer they strip, or they would be testing nothing.
scan "personal email address"  '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}' \
                               'noreply@|@users\.noreply\.github\.com|@example\.(com|org)|@[a-z]+\.example'

if [ "$findings" -eq 0 ]; then
  printf '== no-secrets: OK ==\n'
  exit 0
fi
printf '\n== no-secrets: %d finding(s) — do not publish ==\n' "$findings"
exit 1
