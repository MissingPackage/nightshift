#!/usr/bin/env bash
# install.sh — installs the Nightshift surface into ~/.claude. Idempotent; never touches
# settings.json or plugins unless you ask (live-config mutations are yours by default).
# Respects $HOME, so it sandbox-tests cleanly. See README.md "Install".
#
# Usage:
#   ./install.sh                 install hooks/skills/agents/commands/workflows/hud into ~/.claude
#   ./install.sh --settings      ...and also safely MERGE hooks + statusLine into settings.json
#                                (idempotent, backs up, never clobbers other keys or a custom statusLine)
#   ./install.sh --plugin        complement an installed PLUGIN: only what a plugin cannot carry
#                                (workflows, statusline, ORCHESTRATION.md). Skills/agents/commands/
#                                hooks are skipped — the plugin already provides them, and a second
#                                copy in ~/.claude would double every hook and every entry. With
#                                --settings it merges the statusLine ONLY, never the hooks block.
#                                Driven for you by the /nightshift-setup command.
#   ./install.sh --with-vendored ...and also the four vendored superpowers skills
#                                (third-party, MIT — see skills/vendored/README.md). Off by
#                                default: the default surface is 100% this project's own work.
#   ./install.sh --enterprise    file-based surface ONLY (skills/agents/commands/workflows/hud):
#                                no hooks/, settings.json untouched — for environments where
#                                managed settings block hooks (docs/ENTERPRISE.md). Excludes --settings.
#   ./install.sh --dry-run       print what would change, write nothing (composes with the above)
#
# Behavior: existing files that differ are backed up to ~/.claude/nightshift-backup-<epoch>/
# before overwrite; unchanged files are skipped (re-run ⇒ "0 installed" and no backup dir).
# After installing, run ./verify-install.sh. If you did not pass --settings, each hook's header
# carries the settings.json snippet to merge by hand — that edit stays yours.

set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEST="${HOME}/.claude"
DRY=0
SETTINGS=0
ENTERPRISE=0
VENDORED=0
PLUGIN=0
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY=1 ;;
    --settings) SETTINGS=1 ;;
    --enterprise) ENTERPRISE=1 ;;
    --with-vendored) VENDORED=1 ;;
    --plugin) PLUGIN=1 ;;
    *) printf 'install.sh: unknown flag: %s\n' "$arg" >&2; exit 2 ;;
  esac
done
if [ "$ENTERPRISE" -eq 1 ] && [ "$SETTINGS" -eq 1 ]; then
  printf 'install.sh: --enterprise excludes --settings (the settings merge only carries hooks+statusLine, both blocked there)\n' >&2
  exit 2
fi
if [ "$ENTERPRISE" -eq 1 ] && [ "$PLUGIN" -eq 1 ]; then
  printf 'install.sh: --enterprise excludes --plugin (managed settings that block hooks block a plugin too; install the file surface plainly)\n' >&2
  exit 2
fi

STAMP="$(date +%s)"
BACKUP="${DEST}/nightshift-backup-${STAMP}"
installed=0 skipped=0 backed_up=0

say() { printf '%s\n' "$*"; }

# copy_one <src-file> <dest-file> [exec]
copy_one() {
  local s="$1" d="$2" mode="${3:-}"
  if [ -f "$d" ] && cmp -s "$s" "$d"; then
    skipped=$((skipped + 1))
    return 0
  fi
  if [ "$DRY" -eq 1 ]; then
    say "would install: ${d#"$HOME"/}"
    installed=$((installed + 1))
    return 0
  fi
  if [ -f "$d" ]; then
    mkdir -p "$BACKUP/$(dirname "${d#"$DEST"/}")"
    cp -p "$d" "$BACKUP/${d#"$DEST"/}"
    backed_up=$((backed_up + 1))
  fi
  mkdir -p "$(dirname "$d")"
  cp "$s" "$d"
  [ "$mode" = "exec" ] && chmod +x "$d"
  installed=$((installed + 1))
  say "installed: ${d#"$HOME"/}"
}

# hooks (executable) — skipped in enterprise mode (managed settings block them) and in
# plugin mode (hooks/hooks.json already registered them from the plugin root: a second
# copy here plus a settings entry makes every hook fire twice)
if [ "$ENTERPRISE" -eq 0 ] && [ "$PLUGIN" -eq 0 ]; then
  for f in "$SRC"/hooks/*.sh; do
    copy_one "$f" "$DEST/hooks/$(basename "$f")" exec
  done
fi

# skills — own always, vendored only with --with-vendored (third-party; see
# skills/vendored/README.md). Recursive: vendored skills nest scripts/ and examples/.
# The vendored/ dir itself is a container, not a skill.
# In plugin mode the plugin owns the own skills; the vendored four are nested one level
# deeper than plugin discovery reaches, so they stay this installer's job when asked for.
SKILL_DIRS=("$SRC"/skills/vendored/*/)   # never empty: keeps set -u happy on bash 3.2
[ "$VENDORED" -eq 0 ] && SKILL_DIRS=("$SRC"/skills/vendored)   # a container, skipped below
[ "$PLUGIN" -eq 0 ] && SKILL_DIRS+=("$SRC"/skills/*/)
for d in "${SKILL_DIRS[@]}"; do
  [ -d "$d" ] || continue
  name="$(basename "$d")"
  [ "$name" = "vendored" ] && continue
  [ -f "$d/SKILL.md" ] || continue
  while IFS= read -r -d '' f; do
    rel="${f#"$d"}"
    if [ -x "$f" ]; then
      copy_one "$f" "$DEST/skills/$name/$rel" exec
    else
      copy_one "$f" "$DEST/skills/$name/$rel"
    fi
  done < <(find "$d" -type f -print0)
done

# protocol reference — skills cite "~/.claude/ORCHESTRATION.md §2"; without this copy the
# reference is dead in the installed surface (found 2026-08-13 by a session following
# the protocol by reconstructing it from second-hand citations in the dockets). Installed in
# EVERY mode, plugin included: the citation names a path in ~/.claude, and a plugin puts its
# own copy somewhere the skill never looks.
copy_one "$SRC/ORCHESTRATION.md" "$DEST/ORCHESTRATION.md"

# agents + commands — the plugin carries both; a second copy would show every entry twice
if [ "$PLUGIN" -eq 0 ]; then
  for f in "$SRC"/agents/*.md; do
    copy_one "$f" "$DEST/agents/$(basename "$f")"
  done

  for f in "$SRC"/commands/*.md; do
    copy_one "$f" "$DEST/commands/$(basename "$f")"
  done
fi

# executable workflows — docs/COOKBOOK.md stays documentation, not installed
for f in "$SRC"/workflows/*.workflow.js; do
  [ -f "$f" ] || continue
  copy_one "$f" "$DEST/workflows/$(basename "$f")"
done

# statusline (nightshift-hud) — self-contained Node, travels with the manifest (portability,
# 2026-07-19). settings.json registration stays manual (§C.1); snippet in the script header.
for f in "$SRC"/hud/*.mjs; do
  [ -f "$f" ] || continue
  copy_one "$f" "$DEST/hud/$(basename "$f")"
done

say ""
say "install.sh: ${installed} installed, ${skipped} unchanged, ${backed_up} backed up$( [ "$DRY" -eq 1 ] && printf ' (dry-run: nothing written)')"
[ "$backed_up" -gt 0 ] && say "backups: ${BACKUP#"$HOME"/}"

# settings merge (opt-in via --settings): hooks block + statusLine only, idempotent,
# backed up, never clobbers other keys or a custom statusLine. Plugins/MCP (§C.7) are NOT
# settings.json and stay manual. bash -> python3 heredoc (repo hook convention).
if [ "$SETTINGS" -eq 1 ]; then
  say ""
  DEST="$DEST" DRY="$DRY" PLUGIN="$PLUGIN" python3 - <<'PY'
import json, os, sys, shutil, time
DEST = os.environ["DEST"]; DRY = os.environ.get("DRY") == "1"
PLUGIN = os.environ.get("PLUGIN") == "1"
sp = os.path.join(DEST, "settings.json")
HOOKS = {
    "PreToolUse": [("Bash", ["strip-ai-attribution.sh", "push-guard.sh"])],
    "UserPromptSubmit": [(None, ["firefight-catch.sh"])],
    "SessionStart": [(None, ["session-anchor.sh"])],
    "PostToolUse": [("ScheduleWakeup", ["loop-state.sh"])],
    "Stop": [(None, ["handoff-freshness.sh", "loop-guard.sh"])],
    "Notification": [(None, ["notify-ntfy.sh"])],
}
hdir = os.path.join(DEST, "hooks")
sl_cmd = "node " + os.path.join(DEST, "hud", "nightshift-hud.mjs")
data = {}
if os.path.isfile(sp):
    try:
        data = json.load(open(sp))
    except Exception as e:
        print("settings-merge: settings.json is invalid JSON (%s); refusing to touch it" % e, file=sys.stderr)
        sys.exit(1)
before = json.dumps(data, sort_keys=True)
changes = []
def basenames(lst):
    s = set()
    for grp in lst:
        for h in grp.get("hooks", []):
            c = (h.get("command") or "").split()
            if c:
                s.add(os.path.basename(c[-1]))
    return s
# plugin mode: hooks/hooks.json already registered every hook from the plugin root. Writing
# them here too means each one fires TWICE — two anchors injected, two policy verdicts on one
# push. The statusLine is the only thing a plugin cannot set, so it is the only thing merged.
hooks_obj = data.setdefault("hooks", {}) if not PLUGIN else {}
for event, groups in (HOOKS.items() if not PLUGIN else []):
    ev = hooks_obj.setdefault(event, [])
    have = basenames(ev)
    for matcher, scripts in groups:
        target = None
        for grp in ev:
            if grp.get("matcher") == matcher or (matcher is None and "matcher" not in grp):
                target = grp
                break
        for script in scripts:
            if script in have:
                continue
            if target is None:
                target = {"matcher": matcher, "hooks": []} if matcher else {"hooks": []}
                ev.append(target)
            target.setdefault("hooks", []).append({"type": "command", "command": os.path.join(hdir, script)})
            changes.append("hook %s: +%s" % (event, script))
sl = data.get("statusLine")
cur = sl.get("command", "") if isinstance(sl, dict) else ""
if not sl:
    data["statusLine"] = {"type": "command", "command": sl_cmd}
    changes.append("statusLine: set nightshift-hud")
elif "nightshift-hud.mjs" in cur:
    pass
elif "omc-hud.mjs" in cur:
    data["statusLine"]["command"] = sl_cmd
    changes.append("statusLine: omc-hud -> nightshift-hud")
else:
    print("settings-merge: statusLine already custom (%r); left as-is — set it by hand for nightshift-hud" % cur, file=sys.stderr)
if json.dumps(data, sort_keys=True) == before:
    print("settings-merge: settings.json already up to date (0 changes)")
    sys.exit(0)
for c in changes:
    print("  " + c)
if DRY:
    print("settings-merge: dry-run, nothing written")
    sys.exit(0)
if os.path.isfile(sp):
    bak = "%s.nightshift-settings-bak-%d" % (sp, int(time.time()))
    shutil.copy2(sp, bak)
    print("settings-merge: backup " + os.path.basename(bak))
json.dump(data, open(sp, "w"), indent=2)
print("settings-merge: wrote %d change(s) to settings.json" % len(changes))
PY
  if [ "$PLUGIN" -eq 1 ]; then
    say "plugin mode: statusLine only — the hooks stay registered by the plugin, not by settings.json."
  else
    say "plugins/MCP stay manual — they are not settings.json."
  fi
elif [ "$ENTERPRISE" -eq 1 ]; then
  say "enterprise mode: hooks NOT installed, settings.json untouched. What you lose (full matrix: docs/ENTERPRISE.md §2):"
  say "  - session-anchor (HANDOFF §1 injection)      -> project CLAUDE.md instruction only (compliance)"
  say "  - firefight-catch (FM1/2/3 steering)         -> done/root-cause skill triggers; FM5 resend-catch LOST"
  say "  - strip-ai-attribution + push-guard (L4)     -> CLAUDE.md rules; mechanical recovery: tools/install-git-guards.sh per-repo (§4)"
  say "  - handoff-freshness (stale-handoff warn)     -> /handoff discipline"
  say "  - loop-state + loop-guard (loop reliability) -> C10; timer esterni: tools/install-schedules.sh"
  say "  - notify-ntfy (phone push)                   -> native OS notifications"
  say "  - statusline nightshift-hud                     -> dead under disableAllHooks; maybe alive under allowManagedHooksOnly (§5.3)"
  say "on-site policy checklist: docs/ENTERPRISE.md §5 · global CLAUDE.md stays manual (§C.2)"
elif [ "$PLUGIN" -eq 1 ]; then
  say "manual step: settings.json — run with --plugin --settings to set the statusLine"
  say "(the hooks are already registered by the plugin; this merge never touches them)."
else
  say "manual step: settings.json — run with --settings to merge hooks+statusLine"
  say "automatically (idempotent) · plugins/MCP (§C.7) · per-project files (§C.8)."
fi
if [ "$ENTERPRISE" -eq 1 ]; then
  say "next: ./verify-install.sh --enterprise"
elif [ "$PLUGIN" -eq 1 ]; then
  say "next: ./verify-install.sh --plugin"
else
  say "next: ./verify-install.sh"
fi
