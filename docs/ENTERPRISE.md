# ENTERPRISE — the harness without hooks (capabilities lost, mitigations, install)

Answers the PI's question (goal opus5-enterprise, 2026-07-25): «sul Claude Enterprise
di lavoro gli hook sono bloccati: che capacità mi perdo?» (on the work Claude Enterprise
hooks are blocked: what capabilities do I lose?). Primary source:
code.claude.com/docs/en/settings (fetch 2026-07-25). [ASSUMED] the org's exact policy
is unknown — §5 is the checklist to establish it on-site.

## 1. How hooks get blocked (and what falls with them)

Managed settings (IT deploy: server-managed, MDM, or `managed-settings.json` in
`/etc/claude-code/` on Linux) take absolute precedence: "Managed (highest): cannot be
overridden by anything". Two distinct keys:

- **`disableAllHooks`** — "Disable all hooks and custom status line". The five hooks
  fall AND the nightshift-hud statusline with them.
- **`allowManagedHooksOnly`** — "Only managed hooks, SDK hooks, and hooks from
  force-enabled plugins are loaded; user, project, and other plugin hooks are
  blocked". OUR hooks fall either way (they are user-scope); the statusline is not
  mentioned by this key ⇒ it might survive. Which of the two is active only changes
  the statusline: establish it on-site (§5.3).

Adjacent keys that can affect us: `disableSkillShellExecution` (skills cannot run
inline shell — the normal Bash tool remains), `allowedMcpServers` /
`strictKnownMarketplaces` (MCP/plugins), `disableSideloadFlags` (no `--plugin-dir`
& co.), corporate `permissions.deny` (e.g. `Bash(curl *)`).

## 2. Matrix: hook → function → what is lost → mitigation

Residue classes: **mechanical** (equivalent guarantee), **compliance** (instruction the
model follows but nothing enforces), **lost**.

| hook (event) | function | mitigation without hooks | residue |
|---|---|---|---|
| session-anchor (SessionStart) | injects HANDOFF §1 + active goals + open dockets at session start (kills the "facciamo il punto" ritual, FM6) | the instruction is already in the project CLAUDE.md ("Read HANDOFF.md §1 before exploring"); in enterprise it becomes the ONLY anchoring line — keep it at the top | compliance (high: current models re-anchor well from the filesystem; it is the pattern Anthropic's own docs recommend for long-horizon work) |
| firefight-catch (UserPromptSubmit) | intercepts the "11pm voice": FM1 polling, FM2 paste without framing, FM3 firefighting verbs without a cause, FM5 double send <3min | done and root-cause carry the triggers in their descriptions ("fatto?", "non funziona", traceback pastes) ⇒ native skill auto-selection covers FM1/FM2/FM3 | compliance for FM1/2/3; **FM5 lost** (requires cross-prompt state that only a hook has) |
| push-guard (PreToolUse:Bash) | denies pushes outside `.harness/push-policy` | CLAUDE.md rule + MECHANICAL recovery via a git `pre-push` hook reading the SAME policy (§4) — and it would also cover human pushes | compliance today; mechanical (better than the original) with §4 |
| handoff-freshness (Stop) | at session end warns if HANDOFF.md is older than the repo (file delta) | no Stop event available; /handoff discipline (already in the contract: "End every session that changed state by refreshing HANDOFF.md") + the check is a command the model can run itself at session start | compliance (the most fragile of them: the it5+it9 incident that produced R12 happened WITH the written rule and WITHOUT the hook) |
| notify-ntfy (Notification) | phone push via ntfy | native OS terminal notifications (they don't go through hooks); the outbound curl to ntfy would be a candidate for the corporate deny anyway | lost (partial substitute: native desktop notifications) |
| — nightshift-hud statusline | cosmetic HUD (zero context cost) | none with `disableAllHooks`; maybe survives with `allowManagedHooksOnly` (§1) | lost or intact depending on the key — cosmetic, not harness |

**Honest summary**: layer L4 (mechanical enforcement) is lost and almost everything else
is kept. The two hard guarantees (attribution, push) are recoverable in mechanical form
via git hooks (§4) because git is NOT governed by Claude Code's managed settings. The
three context injections (anchor, firefight, freshness) degrade to compliance — exactly
the gap in the ladder "gates > rules > yelling": you fall back to "rules".
FM5 and the phone push are the only dry losses.

## 3. What survives intact (and it is most of the value)

File-based, never touched by the hook block: global and project CLAUDE.md · all the
skills (done, root-cause, loop-iteration, handoff, peripheral-vision, spec-first,
goal-setup + the 4 vendored + humanizer) · the agents (loop-verifier, scout,
consistency-sweep, adversarial-reviewer) · the commands · the executable workflows ·
HANDOFF/AGENDA/docket (the spine is filesystem) · auto-memory. The same
ledger attributes the bulk of the closable delta to THIS layer (discipline + continuity),
not to the hooks: the enterprise harness stays a harness — it loses the guardrail, not
the method.

## 4. Mechanical recovery via git hooks (BUILT — ruling E1, 2026-07-25)

Git hooks live in the repo (`.git/hooks/` or `core.hooksPath`), not in Claude Code:
managed settings don't see them, and they also apply to pushes made by hand.
- `git-hooks/pre-push`: judges every ref from stdin against `.harness/push-policy`
  (same semantics as push-guard); non-fast-forward and delete count as force
  (they require `force-ok`).
Install: `tools/install-git-guards.sh [repo]` — ALWAYS manual per-repo, never called
by install.sh (the work repo's corporate git policy remains your decision);
idempotent, backs up pre-existing hooks. Tests: section "git-hooks (E1)" in
tests/run.sh.

## 5. On-site checklist (first session on the work Claude Enterprise)

1. `/status` → "Setting sources" line: confirm a managed source exists.
2. Register a harmless user hook (`echo`) and restart: if it NEVER loads ⇒ block
   confirmed; the message/behavior usually distinguishes which key is active.
3. statusLine: point nightshift-hud.mjs in settings.json; if it doesn't render ⇒
   `disableAllHooks` (statusline included), if it renders ⇒ `allowManagedHooksOnly`.
4. Skills: `/skills` (or a request that should auto-trigger done) — verify personal
   skills load; try a skill that runs scripts to probe
   `disableSkillShellExecution`.
5. MCP/plugins: try adding a known MCP ⇒ discover `allowedMcpServers`; same for the
   plugin marketplace.
6. `/goal`: verify whether the CLI's session Stop-hook works with the hook block
   active [VERIFY on-site — the docs don't say; it is an internal CLI hook, not a
   user command hook, so it plausibly survives, but it must be observed].
7. Corporate `permissions.deny`: try `curl` and `git push` (with an empty local
   policy) to map the denies.

## 6. Install

`./install.sh --enterprise`: installs only the file-based surface (skills, agents,
commands, workflows, hud), does NOT copy hooks/ and does NOT touch settings.json; at
the end of the run it prints the summary of lost capabilities (this matrix, in short).
Combining `--enterprise --settings` is an error (the settings merge exists only for
hooks + statusline). The global CLAUDE.md stays manual, as in
the standard path. Verify: `./verify-install.sh --enterprise` (explicit flag: skips
hook presence, functional fixtures and registration checks — so a broken standard
install never silently passes as "enterprise").
