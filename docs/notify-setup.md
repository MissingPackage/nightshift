# Phone notifications — setup (R3, ruling D7 + note R3)

Two complementary routes: the **official Telegram plugin** (bidirectional channel — your
choice, note on ROADMAP R3) and the **ntfy fallback hook** (one-way, 10 lines, zero
plugins). B7 boundary: this file is INSTRUCTIONS — every step touching live config
(`/plugin install`, settings.json, token) is executed by you.

## A. Official Telegram plugin (verified against docs 2026-07-10)

Source: code.claude.com/docs/en/channels.md (Telegram tab) · plugins.md · hooks.md.
Plugin: `telegram@claude-plugins-official` (repo: github.com/anthropics/claude-plugins-official,
external_plugins/telegram). Requires **Bun**.

1. Create the bot with **@BotFather** on Telegram → get the token.
2. In Claude Code: `/plugin install telegram@claude-plugins-official`.
3. `/telegram:configure <token>` — the token lives in `~/.claude/channels/telegram/.env`
   (or env `TELEGRAM_BOT_TOKEN`). NEVER in the repo.
4. Restart with the channel: `claude --channels plugin:telegram@claude-plugins-official`.
5. Pairing: message the bot → it replies with a code → `/telegram:access pair <code>`.
6. Close the perimeter: `/telegram:access policy allowlist`.

For "task finished / needs attention": **Notification hook** with matcher `agent_completed` /
`agent_needs_input`, or a Stop hook calling the plugin's `reply` tool.
**Not verified from the docs** (declared): the outbound-only flow via webhook — the docs
cover incoming and reply well; for purely outbound push, fallback B remains the simple
plan.

## B. ntfy fallback (one-way, no plugins) — hooks/notify-ntfy.sh

The verdict still holds: "a 10-line ntfy hook beats reinstalling
OMC". The hook is in the repo, installed by `./install.sh`, and stays MUTE until you
create the configuration file (opt-in):

```
mkdir -p ~/.config/harness
echo 'https://ntfy.sh/your-secret-topic' > ~/.config/harness/notify.conf
```

Registration (settings.json — your step; snippet also in the hook's header):
```json
"hooks": { "Notification": [ { "hooks": [
  { "type": "command", "command": "~/.claude/hooks/notify-ntfy.sh" } ] } ] }
```

Behavior: POSTs the notification message to the topic; 5s timeout; any error is
silent (never block the session). `HARNESS_NOTIFY_DRY=1` prints instead of POSTing
(that is how the suite tests it). ntfy topic = de-facto secret: use an unguessable
name or a self-hosted instance.

## Quick choice

| | Telegram plugin | ntfy hook |
|---|---|---|
| direction | bidirectional (you chat with the bot) | push only |
| dependencies | Bun + plugin + pairing | curl |
| setup | ~10 min | ~1 min |
| when | you want to ANSWER the loop from your phone | knowing it happened is enough |
