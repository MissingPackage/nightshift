#!/usr/bin/env bash
# install-git-guards.sh — installs git-hooks/{commit-msg,pre-push} into the git hooks of
# ONE repo (ruling E1: per-repo, manual, NEVER called by install.sh — the git policy of
# your working repo stays your decision). For environments where Claude Code hooks are
# blocked (docs/ENTERPRISE.md §4); the guards also cover commits/pushes made by hand.
#
# Usage: tools/install-git-guards.sh [target-repo-dir]     (default: cwd)
# Idempotent; a different pre-existing hook is saved alongside (.pre-harness-<epoch>).

set -euo pipefail
SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET="${1:-$(pwd)}"
HOOKS_DIR="$(git -C "$TARGET" rev-parse --git-path hooks)"
case "$HOOKS_DIR" in /*) ;; *) HOOKS_DIR="$TARGET/$HOOKS_DIR" ;; esac
mkdir -p "$HOOKS_DIR"

for h in commit-msg pre-push; do
  dest="$HOOKS_DIR/$h"
  if [ -e "$dest" ] && ! cmp -s "$SRC/git-hooks/$h" "$dest"; then
    cp -p "$dest" "$dest.pre-harness-$(date +%s)"
    printf 'backup: existing %s saved alongside\n' "$h"
  fi
  if [ -e "$dest" ] && cmp -s "$SRC/git-hooks/$h" "$dest"; then
    printf 'unchanged: %s\n' "$h"
  else
    cp "$SRC/git-hooks/$h" "$dest"
    chmod +x "$dest"
    printf 'installed: %s -> %s\n' "$h" "$dest"
  fi
done
printf 'policy read at push time: <repo>/.harness/push-policy (absent = allow).\n'
