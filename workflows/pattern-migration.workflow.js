// pattern-migration — fix at the root instead of fencing (ruling C11). When something
// would create debt somewhere, don't manage it with exceptions/rules/constraints: fix it
// and align it at the root. Shape (ruling 2026-08-14, after the first run exploded into
// 57 sensor agents on a pattern a grep could count): ONE mapper that reads code+docs and
// writes the plan, N fixers with exclusive files, ONE verifier — plus, only when the
// mapper asks for it, one small adversarial second verifier. Nothing more. Audit-grade
// coverage (per-site skeptics) lives in pattern-coverage and the gates, NOT here.
// Models are explicit, never inherited — a real run once reached 57 agents because the
// multiplier was left to a downstream agent. Rule: a strong model for the reasoning step,
// cheap models for the mechanical ones, and the fan-out named in the script, not inferred.
//
// Install: cp into <project>/.claude/workflows/ · Invoke: Workflow({name: "pattern-migration",
//   args: {pattern: "<the convention, in the repo's own lexicon>",
//          form: "<where the good form lives: path/description>",
//          projectDir: "/absolute/path/of/the/target/repo",
//          verify: "<the project's verify command — or a structural check if the repo has no suite>",
//          hint?: "<what counts as a site>", contention?: "<if present, verify runs serialized>",
//          maxSites?: 8, model?: "sonnet", mapModel?: "opus", budgetNote?: "<limits>"}})
export const meta = {
  name: 'pattern-migration',
  description: 'Fix at the root instead of fencing: one mapper → N fixers (exclusive files) → one verifier (+ optional small adversarial check)',
  whenToUse: "When a good form already exists in the repo and other sites still use the old one (ruling C11: fix, don't fence). REQUIRED args: {pattern, form, projectDir, verify}; optional {hint, contention, maxSites, model, mapModel, budgetNote}",
  phases: [
    { title: 'Map', detail: 'one agent reads code+docs: sites (mechanical enumeration), dependencies, the three questions, the plan' },
    { title: 'Execute', detail: 'derive/hoist step if any, then one fixer per site, exclusive files' },
    { title: 'Verify', detail: "project's verify + recount + anti-fence in ONE agent; adversarial second check only if the map asked for it" },
  ],
}

const MAP = {
  type: 'object',
  required: ['sites', 'plan', 'approach', 'reasoning', 'sharedDerivedState', 'estimatedCost', 'needsAdversarialVerify'],
  properties: {
    sites: { type: 'array', items: { type: 'string' }, description: 'every non-compliant site (file:line or file:block), enumerated MECHANICALLY where possible (grep/scripts) — a count, not an audit' },
    countCommand: { type: 'string', description: 'the exact command that reproduces the enumeration (the verifier re-runs it)' },
    approach: { type: 'string', enum: ['hoist', 'per-site'], description: 'hoist preferred: extract/share the form and let sites adopt it; per-site only with the reason stated' },
    reasoning: { type: 'string' },
    hoistStep: { type: 'string', description: 'if hoist or derive-first: what to create/extract BEFORE any site is touched' },
    sharedDerivedState: {
      type: 'object', required: ['exists'],
      properties: {
        exists: { type: 'boolean', description: 'do the sites feed a SHARED derived value (computed constant, max, negotiated capability, verify threshold)? Partial migration then breaks what every fixer sees as sane' },
        description: { type: 'string' },
        strategy: { type: 'string', enum: ['derive-first', 'all-at-once'], description: 'derive-first preferred: make the value computed from the sites before touching any' },
      },
    },
    nonMigrable: { type: 'array', items: { type: 'object', required: ['site', 'reason'], properties: { site: { type: 'string' }, reason: { type: 'string' } } }, description: 'sites with no form to migrate to — named with reasons, never counted as missing' },
    plan: { type: 'array', items: { type: 'object', required: ['site', 'action', 'ownFiles'], properties: { site: { type: 'string' }, action: { type: 'string' }, ownFiles: { type: 'array', items: { type: 'string' }, description: 'EXCLUSIVE files, disjoint across fixers' } } } },
    estimatedCost: { type: 'string', description: 'honest estimate; the PI sees this' },
    needsAdversarialVerify: { type: 'boolean', description: 'true ONLY when a plain verify could pass while the migration is wrong (weak suite, semantic pattern, risky shared state) — spawns ONE extra small checker, nothing more' },
    adversarialReason: { type: 'string' },
    blockedQuestion: { type: 'string', description: 'ONLY if a conflict is not manageable autonomously: one line + cost of not deciding + default on a bare "ok" (phone format, C7)' },
  },
}

const FIX_RESULT = {
  type: 'object', required: ['site', 'done', 'summary'],
  properties: { site: { type: 'string' }, done: { type: 'boolean' }, summary: { type: 'string', description: 'raw, not polished' }, filesTouched: { type: 'array', items: { type: 'string' } } },
}

const VERIFY_RESULT = {
  type: 'object', required: ['pass', 'verifyOutput', 'recount', 'fenceFindings'],
  properties: {
    pass: { type: 'boolean' },
    verifyOutput: { type: 'string', description: "raw tail + exit code of the project's verify" },
    recount: { type: 'string', description: 'result of re-running the map countCommand: remaining non-compliant sites' },
    fenceFindings: { type: 'array', items: { type: 'string' }, description: 'variant-keyed special-casing the diff ADDS (guard/exception/debt comment naming a site) — the right migration removes distinctions' },
  },
}

const ADVERSARIAL = {
  type: 'object', required: ['refuted', 'reasoning'],
  properties: { refuted: { type: 'boolean', description: 'true only with something concrete: a way the migration is wrong despite the green verify' }, reasoning: { type: 'string' } },
}

const USAGE = '{pattern: string, form: string, projectDir: string, verify: string, hint?: string, contention?: string, maxSites?: number, model?: string, mapModel?: string, budgetNote?: string}'
function parseArgs(raw) {
  if (raw == null) return {}
  if (typeof raw !== 'string') return raw || {}
  const s = raw.trim()
  if (s.startsWith('{') || s.startsWith('[') || s.startsWith('"')) {
    try { return JSON.parse(s) } catch (e) { throw new Error(`args: invalid JSON string (${e.message}). Expected shape: ${USAGE}`) }
  }
  throw new Error(`args: got free text, but distinct fields are needed — ${USAGE}`)
}
const A = parseArgs(args)
if (!A.pattern || !A.form || !A.projectDir || !A.verify) {
  // literal, not ${USAGE}: verify-install's anti-drift check reads the required
  // fields FROM this string (marker: "required args") and compares with the header.
  throw new Error('required args: {pattern: string, form: string, projectDir: string, verify: string, hint?: string, contention?: string, maxSites?: number, model?: string, mapModel?: string, budgetNote?: string}')
}
const MAX_SITES = A.maxSites || 8
// Explicit models, never inherited. Cheap for mechanical work, strong only for the map.
const FIX_M = { model: A.model || 'sonnet' }
const MAP_M = { model: A.mapModel || 'opus' }

// ---- Map: ONE agent. Reads the good form, the docs, every candidate site; enumerates
// mechanically (a grep beats reading everything); maps dependencies in Chesterton's
// direction too — before changing/removing anything, verify it is not there because
// something else depends on it. The worklist is FROZEN here: later finds go to the docket.
phase('Map')
const map = await agent(
  `Target repo (ABSOLUTE path, confirm with pwd): ${A.projectDir}\n` +
    `Convention to complete: ${A.pattern}\nThe good form lives here: ${A.form}\n` +
    `${A.hint ? 'What counts as a site: ' + A.hint + '\n' : ''}` +
    `Read the good form, the project docs, and the code. Enumerate the non-compliant ` +
    `sites MECHANICALLY where the pattern allows it (grep/script — record the exact ` +
    `command in countCommand); read individual sites only where judgment is needed. ` +
    `Map the dependencies adoption touches, in both directions: before planning to ` +
    `change or remove anything, verify it is not there because something ELSE depends ` +
    `on it. Then answer, in order: (1) hoist or per-site, with the reason; (2) do the ` +
    `sites feed a SHARED DERIVED value? if yes, derive-first (preferred, goes in ` +
    `hoistStep) or all-at-once — partial migration of shared state breaks what every ` +
    `fixer sees as sane; (3) does the form TRULY apply to each site? no form to migrate ` +
    `to → nonMigrable with the reason. Write the plan: one entry per site, EXCLUSIVE ` +
    `files per fixer. Set needsAdversarialVerify=true only if a plain verify could pass ` +
    `while the migration is wrong. Unmanageable conflict → blockedQuestion, and do not ` +
    `plan that site.` + (A.budgetNote ? `\nConstraints: ${A.budgetNote}` : ''),
  { label: 'map', phase: 'Map', schema: MAP, ...MAP_M },
)
if (!map) throw new Error('map missing: no execution without a plan')
if (map.blockedQuestion) {
  log('unmanageable conflict: stopping BEFORE touching any file')
  return { blocked: map.blockedQuestion, map }
}
const sites = map.sites || []
const nonMigrable = map.nonMigrable || []
const plan = (map.plan || []).slice(0, MAX_SITES)
if ((map.plan || []).length > MAX_SITES) {
  log(`declared cap: ${plan.length}/${map.plan.length} sites this run — the rest go to a later run (no silent cap)`)
}
// Shared derived state: the BODY refuses dangerous partiality, not the agent's judgment.
const sds = map.sharedDerivedState || { exists: false }
if (sds.exists && sds.strategy !== 'derive-first' && plan.length + nonMigrable.length < sites.length) {
  log('shared derived state + partial coverage: stopping BEFORE touching any file')
  return {
    blocked: `Sites feed a shared derived value (${sds.description || 'see map'}) and this run does not cover them all (${plan.length + nonMigrable.length} of ${sites.length}). Migrating a subset breaks the rest. Options: raise maxSites for a complete wave, or derive-first. Default on a bare "ok": derive-first.`,
    map,
  }
}
if (sds.exists && sds.strategy === 'derive-first' && !map.hoistStep) {
  throw new Error('derive-first declared without a hoistStep')
}
log(`map: ${sites.length} sites, ${plan.length} planned, ${nonMigrable.length} non-migrable — ${map.approach}${sds.exists ? ` + shared state (${sds.strategy})` : ''}; agents this run: ${1 + (map.hoistStep ? 1 : 0) + plan.length + 1 + (map.needsAdversarialVerify ? 1 : 0)}`)

// ---- Execute: derive/hoist first (one agent owns the shared module), then fixers in
// parallel — file disjointness comes from the plan, not from hope.
phase('Execute')
if (map.hoistStep && (map.approach === 'hoist' || (sds.exists && sds.strategy === 'derive-first'))) {
  const h = await agent(
    `Repo: ${A.projectDir}. Execute ONLY this preliminary step: ${map.hoistStep}\n` +
      `Do not touch the planned sites — they come next, each with its own fixer. Report files created/modified.`,
    { label: 'hoist', phase: 'Execute', ...FIX_M },
  )
  if (!h) throw new Error('preliminary step failed: fixers do not start without it')
}
const results = (await parallel(plan.map((p) => () =>
  agent(
    `Repo: ${A.projectDir}. Site: ${p.site}\nAction: ${p.action}\n` +
      `Files you own EXCLUSIVELY (touch nothing outside; if you need to, the plan is wrong — stop and say so): ${p.ownFiles.join(', ')}\n` +
      `Adopt the form (${A.form}) — adoption REMOVES the old variant, it does not fence it: no guards, debt comments or exceptions around the old behavior.`,
    { label: `fix:${p.site.slice(0, 30)}`, phase: 'Execute', schema: FIX_RESULT, ...FIX_M },
  ),
))).filter(Boolean)
const failed = results.filter((r) => !r.done)

// ---- Verify: ONE agent runs the project's verify, re-runs the map's count command,
// and reads the diff for new fences. Adversarial second check only on the map's request.
phase('Verify')
const ver = await agent(
  `Repo: ${A.projectDir}. Three checks, report raw outputs:\n` +
    `1. Run EXACTLY the project's verify and report tail + exit code:\n${A.verify}\n` +
    (A.contention ? `   CONTENTION CONSTRAINT: ${A.contention} — run SERIALLY, never concurrent.\n` : '') +
    `2. Re-run the map's enumeration to recount remaining non-compliant sites: ${map.countCommand || '(no countCommand recorded — re-derive it from the pattern)'}\n` +
    `3. Read the uncommitted diff (git diff + status): list any variant-keyed special-casing it ADDS ` +
    `(guards/exceptions/debt comments naming a site). The right migration removes distinctions.`,
  { label: 'verify', phase: 'Verify', schema: VERIFY_RESULT, ...FIX_M },
)
let adversarial = null
if (map.needsAdversarialVerify) {
  adversarial = await agent(
    `Small adversarial check (the map asked for you because: ${map.adversarialReason || 'n/a'}).\n` +
      `Repo: ${A.projectDir}. The verifier reports pass=${(ver || {}).pass}. Try to REFUTE it: ` +
      `read the diff, spot-check the riskiest sites, re-run one decisive command. ` +
      `refuted=true only with something concrete.`,
    { label: 'adversarial', phase: 'Verify', schema: ADVERSARIAL, ...FIX_M },
  )
}
const doneSites = results.filter((r) => r.done)
return {
  reading: `${doneSites.length} of ${plan.length} migrated` +
    (nonMigrable.length ? `; ${nonMigrable.length} non-migrable: ${nonMigrable.map((n) => `${n.site} (${n.reason})`).join('; ')}` : '') +
    (failed.length ? `; ${failed.length} failed` : ''),
  approach: map.approach,
  sharedDerivedState: sds.exists ? sds : undefined,
  sitesDone: doneSites.map((r) => r.site),
  sitesFailed: failed.map((r) => `${r.site}: ${r.summary}`),
  nonMigrable,
  deferredSites: (map.plan || []).length > MAX_SITES ? (map.plan || []).length - MAX_SITES : 0,
  verify: ver,
  adversarial,
  estimatedCost: map.estimatedCost,
}
