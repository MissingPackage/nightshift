#!/usr/bin/env bash
# The mailman for scheduled reports (fix 2026-08-13). The morning report was being
# GENERATED at 07:30 and ended up in the systemd journal: nobody carried it to the user.
# Generating is not delivering.
#
# Reads the report from stdin, ARCHIVES it to a file and SENDS it over Telegram via Bot
# API (direct curl, not MCP: in a scheduled run, MCP servers with interactive
# authentication may not be there). Usage:
#   claude -p "/morning" | tools/deliver-report.sh morning
# Credentials: ~/.claude/channels/telegram/.env (TELEGRAM_BOT_TOKEN) + recipients from
# the allowlist in ~/.claude/channels/telegram/access.json. The token is NEVER printed
# nor passed on the command line.

set -u
KIND="${1:-report}"
ARCHIVE_DIR="$HOME/.claude/reports"
ENV_FILE="$HOME/.claude/channels/telegram/.env"
ACCESS="$HOME/.claude/channels/telegram/access.json"
LOG="$HOME/.claude/deliver-report.log"

body="$(cat)"
stamp="$(date +%Y-%m-%d)"
mkdir -p "$ARCHIVE_DIR"
archive="$ARCHIVE_DIR/$KIND-$stamp.md"
printf '%s\n' "$body" > "$archive"

log() { printf '%s deliver[%s] %s\n' "$(date +%Y-%m-%dT%H:%M:%S)" "$KIND" "$1" >> "$LOG"; }

if [ -z "${body//[[:space:]]/}" ]; then
  log "EMPTY report: nothing to deliver (the generator produced no output)"
  exit 1
fi
log "archived in $archive ($(printf '%s' "$body" | wc -c) characters)"

if [ ! -r "$ENV_FILE" ]; then
  log "ERROR: $ENV_FILE missing — report archived but NOT delivered"
  exit 2
fi

# shellcheck disable=SC1090
set -a          # the token must reach the python subprocess, not stop at this shell
. "$ENV_FILE"
set +a
: "${TELEGRAM_BOT_TOKEN:?token missing}"

BODY="$body" ARCHIVE="$archive" KIND="$KIND" ACCESS="$ACCESS" python3 - <<'PY' 2>>"$LOG"
import json, os, sys, urllib.parse, urllib.request

token = os.environ["TELEGRAM_BOT_TOKEN"]
body, kind, access = os.environ["BODY"], os.environ["KIND"], os.environ["ACCESS"]
try:
    allow = json.load(open(access)).get("allowFrom") or []
except Exception as e:
    print("ERROR reading allowlist: %s" % e); sys.exit(3)
if not allow:
    print("ERROR: empty allowlist, no recipients"); sys.exit(3)

LIMIT = 3900  # margin under Telegram's 4096
def chunks(t):
    out, cur = [], ""
    for para in t.split("\n"):
        if len(cur) + len(para) + 1 > LIMIT:
            if cur:
                out.append(cur)
            while len(para) > LIMIT:      # monstrous paragraph: hard cut, never silent
                out.append(para[:LIMIT] + "\n…[continued]")
                para = para[LIMIT:]
            cur = para
        else:
            cur = f"{cur}\n{para}" if cur else para
    if cur:
        out.append(cur)
    return out

parts = chunks(body)
sent = 0
for i, p in enumerate(parts, 1):
    head = "" if len(parts) == 1 else f"[{i}/{len(parts)}] "
    for chat in allow:
        data = urllib.parse.urlencode({
            "chat_id": chat,
            "text": head + p,
            "disable_web_page_preview": "true",
        }).encode()
        req = urllib.request.Request(
            "https://api.telegram.org/bot%s/sendMessage" % token, data=data)
        try:
            with urllib.request.urlopen(req, timeout=30) as r:
                if json.load(r).get("ok"):
                    sent += 1
                else:
                    print("Telegram rejected chunk %d" % i)
        except Exception as e:
            print("ERROR sending chunk %d to %s: %s" % (i, chat, e))
print("delivered %d/%d chunks (%s)" % (sent, len(parts) * len(allow), kind))
PY
rc=$?
[ $rc -eq 0 ] && log "delivery OK" || log "delivery FAILED (rc=$rc) — the report stays in $archive"
exit $rc
