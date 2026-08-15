---
description: Finish a plugin install — add the workflows, the protocol reference and the status line a plugin cannot carry
allowed-tools: Bash(bash:*), Bash(ls:*), Bash(printf:*)
---

Complete this machine's Nightshift installation.

A Claude Code plugin carries skills, agents, commands and hooks. It does **not** carry the five
executable workflows, the `~/.claude/ORCHESTRATION.md` the skills cite by path, or the status
line — those need files in `~/.claude`, which is what this command puts there. It installs
nothing the plugin already provides: a second copy of a hook fires twice.

Run it in three steps and report what actually happened.

**1. Find the plugin root.** `$CLAUDE_PLUGIN_ROOT` if the environment carries it; otherwise the
newest match of `~/.claude/plugins/cache/nightshift/nightshift/*/`:

```sh
ROOT="${CLAUDE_PLUGIN_ROOT:-$(ls -d "$HOME"/.claude/plugins/cache/nightshift/nightshift/*/ 2>/dev/null | sort -V | tail -1)}"
printf 'plugin root: %s\n' "$ROOT"
```

If that resolves to nothing, stop and say so: the plugin is not installed, and the right move is
`/plugin install nightshift@nightshift` or the plain `./install.sh` from a clone — not this command.

**2. Install the complement.** Show the user what it would change first, then do it:

```sh
bash "$ROOT/install.sh" --plugin --dry-run
bash "$ROOT/install.sh" --plugin
```

The status line writes to `settings.json`, so it stays opt-in. Ask once — *"set the nightshift-hud
status line? it edits ~/.claude/settings.json, backs it up first, and touches nothing else"* — and
only on a yes:

```sh
bash "$ROOT/install.sh" --plugin --settings
```

**3. Verify, and report the real numbers.**

```sh
bash "$ROOT/verify-install.sh" --plugin
```

Report the pass/fail/warn line as printed. Two failures have a known remedy — give it instead of
the raw text: *plugin-owned surface duplicated* means a plain `./install.sh` ran here too, so the
same skills and hooks exist twice (remove them from `~/.claude`, or drop the plugin and keep the
installer alone); *hooks registered twice* means a plain `--settings` merge added a hooks block on
top of the plugin's registration, so every hook fires once per registration (remove that block).

One warn is expected and not a problem: hook fixtures are skipped, because in this channel the
hooks run from the plugin root rather than `~/.claude/hooks`.

Restart the session afterwards if the status line was set — it is read at startup.

$ARGUMENTS
