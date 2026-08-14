#!/usr/bin/env bash
# Installs the three harness schedules as systemd user timers (ruling C10, 2026-08-12):
#   harness-loop-watchdog  every 10 min  — revives loops whose wake-up died
#   harness-morning        07:30         — coffee report, cross-goal aggregate (/morning)
#   harness-weekly         Sun 09:00     — weekly maintenance (/weekly-maintenance)
# The /morning and /weekly-maintenance command rituals are NO LONGER PI duties: 0
# invocations in 23 days (audit 2026-08-12) — the rituals that survive are the ones that
# don't require his hand. Usage: tools/install-schedules.sh [--uninstall] [--dry-run]
# Portable: any host with systemd user (Fedora, most servers). Without systemd:
# equivalent cron at the tail of this file.

set -eu
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
UNITS="$HOME/.config/systemd/user"
DRY=0; UNINSTALL=0
for a in "$@"; do case "$a" in --dry-run) DRY=1;; --uninstall) UNINSTALL=1;; esac; done

if ! command -v systemctl >/dev/null 2>&1; then
  echo "systemd not found: use the cron fallback (comments at the tail of $0)" >&2; exit 1
fi

if [ "$UNINSTALL" -eq 1 ]; then
  for t in harness-loop-watchdog harness-morning harness-weekly; do
    systemctl --user disable --now "$t.timer" 2>/dev/null || true
    rm -f "$UNITS/$t.timer" "$UNITS/$t.service"
  done
  systemctl --user daemon-reload
  echo "schedules removed"; exit 0
fi

mkdir -p "$UNITS"

write_unit() { # name description execstart oncalendar_or_empty onactive_or_empty
  local name="$1" desc="$2" exec="$3" cal="$4" act="$5"
  if [ "$DRY" -eq 1 ]; then echo "[dry] $name: $exec"; return; fi
  cat > "$UNITS/$name.service" <<EOF
[Unit]
Description=$desc
[Service]
Type=oneshot
# KillMode=process: without it, at the end of a oneshot systemd tears down the cgroup
# and kills every child — that is how the watchdog launched 'claude --resume' and
# watched it get killed an instant later (5 ghost revivals on 2026-08-13). The primary
# path remains systemd-run (its own transient unit); this covers the fallback.
KillMode=process
ExecStart=$exec
EOF
  {
    printf '[Unit]\nDescription=%s (timer)\n[Timer]\n' "$desc"
    [ -n "$cal" ] && printf 'OnCalendar=%s\nPersistent=true\n' "$cal"
    [ -n "$act" ] && printf 'OnBootSec=5min\nOnUnitActiveSec=%s\n' "$act"
    printf '[Install]\nWantedBy=timers.target\n'
  } > "$UNITS/$name.timer"
}

# claude in -p also executes slash commands; the report shows up as a session in the app.
CLAUDE_BIN="$(command -v claude || echo "$HOME/.local/bin/claude")"
write_unit harness-loop-watchdog "Harness: watchdog for autonomous loops" \
  "/usr/bin/env bash $ROOT/tools/loop-watchdog.sh" "" "2min"
# Generating is not delivering: the stdout of claude -p would end up in the systemd
# journal (happened 2026-08-13: perfect report at 07:33, never reached anyone).
# deliver-report.sh archives and sends over Telegram.
write_unit harness-morning "Harness: coffee report (cross-goal aggregate)" \
  "/usr/bin/env bash -lc 'cd $ROOT && $CLAUDE_BIN -p \"/morning\" | $ROOT/tools/deliver-report.sh morning'" "*-*-* 07:30:00" ""
write_unit harness-weekly "Harness: weekly maintenance" \
  "/usr/bin/env bash -lc 'cd $ROOT && $CLAUDE_BIN -p \"/weekly-maintenance\" | $ROOT/tools/deliver-report.sh weekly'" "Sun *-*-* 09:00:00" ""

[ "$DRY" -eq 1 ] && exit 0
systemctl --user daemon-reload
for t in harness-loop-watchdog harness-morning harness-weekly; do
  systemctl --user enable --now "$t.timer"
done
systemctl --user list-timers 'harness-*' --no-pager || true
echo "done. Watchdog log: ~/.claude/loop-watchdog.log"

# Cron fallback (hosts without systemd user):
#   */10 * * * *  /usr/bin/env bash <repo>/tools/loop-watchdog.sh
#   30 7 * * *    cd <repo> && claude -p "/morning"
#   0 9 * * 0     cd <repo> && claude -p "/weekly-maintenance"
