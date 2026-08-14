#!/usr/bin/env bash
# Removes .harness/loop-state.json from a repo's branches — it is runtime, not source.
#
# Why it exists (observed in another project, 2026-08-14): a `git checkout` of a branch carrying a
# state with status "active" materializes it on disk, and the watchdog revives a loop
# deliberately stopped with stop:true. The watchdog now defends itself
# (mtime-vs-updated_epoch and staleness), but as long as the file stays tracked the
# fuse re-arms at every checkout.
#
# Works in PLUMBING: no checkout, no worktree touched, no user file moved. For each
# branch it builds a child commit without that path and moves the ref with a
# compare-and-swap on the old SHA.
#
# Branches CHECKED OUT in a worktree are skipped on purpose: moving their ref would
# leave that worktree's index with the file inside, and its first commit would put it
# back — re-arming the fuse instead of removing it. Clean them after pruning the
# worktree (`git worktree prune` / `git worktree remove`), re-running this script.
#
# Usage:  bash tools/purge-loop-state.sh [--dry-run] <repo>
# Rollback: the old SHAs end up in <repo>/.git/loop-state-purge-rollback.txt (and stay
# in the reflog); `git update-ref refs/heads/<branch> <old-sha>` puts everything back.

set -u
DRY=0
[ "${1:-}" = "--dry-run" ] && { DRY=1; shift; }
REPO="${1:-}"
[ -n "$REPO" ] || { echo "usage: $0 [--dry-run] <repo>" >&2; exit 2; }
git -C "$REPO" rev-parse --git-dir >/dev/null 2>&1 || { echo "not a git repo: $REPO" >&2; exit 2; }

PATHSPEC=".harness/loop-state.json"
# --absolute-git-dir, NOT --git-dir: with `-C <repo>` the latter prints a relative
# ".git", and the safety net ended up in the .git of WHOEVER RUNS the script instead of
# the target's (found by the session in another project on 2026-08-14, which went looking
# for it where the script said it had written it and didn't find it). A rollback you
# believe you have and don't is worse than no rollback.
ROLLBACK="$(git -C "$REPO" rev-parse --absolute-git-dir)/loop-state-purge-rollback.txt"
CHECKED_OUT="$(git -C "$REPO" worktree list --porcelain | awk '/^branch /{sub("refs/heads/","",$2); print $2}')"

done_n=0 skipped_n=0 clean_n=0
for ref in $(git -C "$REPO" for-each-ref --format='%(refname:short)' refs/heads); do
  git -C "$REPO" cat-file -e "$ref:$PATHSPEC" 2>/dev/null || { clean_n=$((clean_n + 1)); continue; }
  if printf '%s\n' $CHECKED_OUT | grep -qx "$ref"; then
    echo "SKIP     $ref (checked out in a worktree: prune it first, then rerun)"
    skipped_n=$((skipped_n + 1)); continue
  fi
  old="$(git -C "$REPO" rev-parse "$ref")"
  if [ "$DRY" = 1 ]; then echo "WOULD    $ref ($old)"; done_n=$((done_n + 1)); continue; fi

  idx="$(mktemp)"; rm -f "$idx"   # git wants a nonexistent path for a fresh index
  GIT_INDEX_FILE="$idx" git -C "$REPO" read-tree "$ref" || { echo "FAILED   $ref (read-tree)"; rm -f "$idx"; continue; }
  # NOT `git rm --cached`: that compares against the working tree and the main repo's
  # HEAD, and on a temporary index of ANOTHER branch it fails with "staged content
  # different from both the file and the HEAD". update-index touches only the index.
  GIT_INDEX_FILE="$idx" git -C "$REPO" update-index --force-remove "$PATHSPEC" \
    || { echo "FAILED   $ref (update-index)"; rm -f "$idx"; continue; }
  tree="$(GIT_INDEX_FILE="$idx" git -C "$REPO" write-tree)"; rm -f "$idx"
  # If commit-tree fails (typical: git identity missing) and it isn't intercepted, $new
  # stays empty and update-ref dies with "not a valid SHA1" — which the script reported
  # as "the branch moved under us", i.e. a false diagnosis of the wrong error.
  if ! new="$(git -C "$REPO" commit-tree "$tree" -p "$old" -m "chore: loop-state.json is runtime, not source

Tracked, a checkout of this branch puts it back on disk with status active and
the watchdog revives a loop deliberately stopped (observed in another project, 2026-08-14 00:01:34).
Removed from the index; the file on disk is not touched.")"; then
    echo "FAILED   $ref (commit-tree: git identity missing in $REPO?)"
    continue
  fi
  # The net BEFORE the jump, and with a speaking handle: a month from now whoever looks
  # for the rollback has a bare anonymous SHA unless you leave the commit title beside it.
  subject="$(git -C "$REPO" log -1 --format='%s' "$old" 2>/dev/null | cut -c1-100)"
  if ! printf '%s %s  %s\n' "$old" "$ref" "$subject" >> "$ROLLBACK"; then
    echo "FAILED   $ref (rollback not writable in $ROLLBACK: not moving the ref)"
    continue
  fi
  # -m: without a message the reflog line comes out anonymous ("@{09:26:56}:"), and the
  # reflog is the LAST net when the rollback file gets lost.
  git -C "$REPO" update-ref -m "purge loop-state.json (tools/purge-loop-state.sh)" \
      "refs/heads/$ref" "$new" "$old" \
    && { echo "CLEANED  $ref  $old → $new"; done_n=$((done_n + 1)); } \
    || echo "FAILED   $ref (update-ref: the branch moved under us)"
done

echo "— $done_n cleaned, $skipped_n skipped (worktree), $clean_n already clean"
[ "$DRY" = 1 ] || [ "$done_n" = 0 ] || echo "rollback: $ROLLBACK"
