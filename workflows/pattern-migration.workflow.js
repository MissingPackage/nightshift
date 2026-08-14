// pattern-migration — blueprint 5, the EXECUTOR side. pattern-coverage is the sensor
// (n/total, worklist, exceptions); this workflow is the fix: it brings non-compliant
// sites to the good form the repo ALREADY HAS, and closes with the same sensor. Born
// from ruling C11 (fix-don't-fence, 2026-08-14): the fence — a guard, a declared-debt
// comment, a test that watches a known defect — is the path of least resistance when
// the fix has no vehicle; this is the vehicle. No domain nouns in the body: pattern,
// form, verify, contention arrive via args in the project's own lexicon (validated on
// 7 dissimilar projects, 2026-08-14: site units were a hook / an md entry / a CSS
// block / a widget / a worker class / a backend class / a page — the body knows none).
//
// Install: cp into <project>/.claude/workflows/ · Invoke: Workflow({name: "pattern-migration",
//   args: {pattern: "<the convention, in the repo's own lexicon>",
//          form: "<where the good form lives: path/description>",
//          projectDir: "/absolute/path/of/the/target/repo",
//          verify: "<the project's verify command — or a structural check if the repo has no suite>",
//          globs?: ["src/**/*.ts"], hint?: "<what counts as a site>",
//          contention?: "<contention constraint declared by the project: when present, verify runs serialized>",
//          maxSites?: 8, budgetNote?: "<spend/time limits>"}})
export const meta = {
  name: 'pattern-migration',
  description: 'Bring non-compliant sites to the form the repo already has: coverage → assess (hoist|per-site, shared-state aware) → adoption in waves → recount with the same sensor',
  whenToUse: "When a good form already exists in the repo and other sites still use the old one (ruling C11: fix, don't fence). REQUIRED args: {pattern, form, projectDir, verify}; optional {globs, hint, contention, maxSites, budgetNote}",
  phases: [
    { title: 'Scout', detail: 'pattern-coverage baseline: n/total + frozen worklist' },
    { title: 'Assess', detail: 'dependencies and verdict: hoist preferred, per-site with a stated reason; shared derived state named; unmanageable conflicts → phone-format frontier for the PI' },
    { title: 'Execute', detail: 'preliminary hoist/derive step if any, then one agent per site, exclusive files' },
    { title: 'Verify', detail: "project's verify + coverage recount + anti-fence check" },
  ],
}

const ASSESS = {
  type: 'object',
  required: ['approach', 'reasoning', 'plan', 'estimatedCost', 'sharedDerivedState'],
  properties: {
    approach: { type: 'string', enum: ['hoist', 'per-site'], description: 'hoist = extract/use the shared form; per-site = each site adopts the form locally. Hoist is the PREFERENCE; per-site is legitimate only with the reason stated (e.g. deliberate self-containment)' },
    reasoning: { type: 'string', description: 'why this approach; if per-site, the reason hoist is wrong here' },
    hoistStep: { type: 'string', description: 'if hoist (or derive-first): what to extract/create and where, BEFORE any site is touched' },
    // The third question (real case, 2026-08-14: four sites fed a device ceiling
    // negotiated as a max; migrating a subset lowered the ceiling while unmigrated
    // sites still demanded the old value — every agent correct on ITS file, verify
    // green when tests don't cover it, system broken on every device).
    sharedDerivedState: {
      type: 'object',
      required: ['exists'],
      properties: {
        exists: { type: 'boolean', description: 'do the sites feed a SHARED derived value? (a computed constant, a max, a negotiated capability, a threshold the verify uses that the sites determine)' },
        description: { type: 'string', description: 'if exists: which value, where it lives, who consumes it' },
        strategy: { type: 'string', enum: ['derive-first', 'all-at-once'], description: 'derive-first (preferred): make the state COMPUTED from the sites before touching any of them — partial migration then becomes harmless. all-at-once: every site in this wave, no partiality allowed' },
      },
    },
    nonMigrable: {
      type: 'array',
      items: {
        type: 'object',
        required: ['site', 'reason'],
        properties: { site: { type: 'string' }, reason: { type: 'string' } },
      },
      description: 'worklist sites for which NO form to migrate to exists — named with the reason, never counted as missing. "3 of 4, and the fourth for this reason" is a decision; "75% coverage" is just a percentage',
    },
    estimatedCost: { type: 'string', description: 'honest estimate (sites × difficulty); the PI sees this' },
    conflicts: { type: 'array', items: { type: 'string' }, description: 'dependencies that make adoption risky at a site' },
    blockedQuestion: { type: 'string', description: 'ONLY if conflicts are not manageable autonomously: the question for the PI in ONE line + the cost of not deciding + the default applied on a bare "ok" (phone format, C7)' },
  },
}

const SITE_RESULT = {
  type: 'object',
  required: ['site', 'done', 'summary'],
  properties: {
    site: { type: 'string' },
    done: { type: 'boolean' },
    summary: { type: 'string', description: 'what changed; if done=false, why — raw, not polished' },
    filesTouched: { type: 'array', items: { type: 'string' } },
  },
}

const FENCE_CHECK = {
  type: 'object',
  required: ['clean', 'findings'],
  properties: {
    clean: { type: 'boolean' },
    findings: { type: 'array', items: { type: 'string' }, description: 'every variant-keyed special-casing the diff ADDS (a conditional/guard/exception with a site name inside) — the sign that fencing is happening again' },
  },
}

// Tolerant args (research-campaign idiom, fix 2026-08-13): JSON if it is JSON; free
// text is NOT mappable here (four required fields) → an error that SHOWS the shape.
const USAGE = '{pattern: string, form: string, projectDir: string, verify: string, globs?: string[], hint?: string, contention?: string, maxSites?: number, budgetNote?: string}'
function parseArgs(raw) {
  if (raw == null) return {}
  if (typeof raw !== 'string') return raw || {}
  const s = raw.trim()
  if (s.startsWith('{') || s.startsWith('[') || s.startsWith('"')) {
    try { return JSON.parse(s) } catch (e) {
      throw new Error(`args: invalid JSON string (${e.message}). Expected shape: ${USAGE}`)
    }
  }
  throw new Error(`args: got free text, but distinct fields are needed — ${USAGE}`)
}
const A = parseArgs(args)
if (!A.pattern || !A.form || !A.projectDir || !A.verify) {
  // literal, not ${USAGE}: verify-install's anti-drift check reads the required
  // fields FROM this string (marker: "required args") and compares them against
  // the file header.
  throw new Error('required args: {pattern: string, form: string, projectDir: string, verify: string, globs?: string[], hint?: string, contention?: string, maxSites?: number, budgetNote?: string}')
}
const MAX_SITES = A.maxSites || 8

// ---- Scout: the existing sensor, not a new detector. Worklist FROZEN here: whatever
// surfaces later goes to the docket, not chased (a fix-loop that chases never converges).
phase('Scout')
const cov = await workflow('pattern-coverage', {
  pattern: A.pattern,
  globs: A.globs || [],
  hint: `${A.hint || ''} — target repo: ${A.projectDir}. The reference good form: ${A.form}`.trim(),
})
// pattern-coverage's actual return contract (read, not assumed): {total, compliant,
// worklist, exceptionsToRule} — worklist = non-compliant sites; exceptions are the PI's.
const sites = (cov || {}).worklist || []
const total = (cov || {}).total || sites.length
const compliantBefore = (cov || {}).compliant ?? (total - sites.length)
if (!sites.length) {
  return { before: `${compliantBefore}/${total}`, after: `${compliantBefore}/${total}`, result: 'already compliant: nothing to migrate', exceptionsToRule: (cov || {}).exceptionsToRule || [] }
}
const worklist = sites.slice(0, MAX_SITES)
if (sites.length > MAX_SITES) {
  log(`declared cap: ${worklist.length}/${sites.length} sites this run — the remaining ${sites.length - worklist.length} go to a later run (no silent cap)`)
}
log(`baseline: ${compliantBefore}/${total} compliant; ${worklist.length} sites in this run`)

// ---- Assess: dependencies and a verdict WITH evidence. The assessor does not execute:
// if conflicts are unmanageable it does not "try" — it reports the frontier and the run
// stops clean, BEFORE any file is touched.
phase('Assess')
const assess = await agent(
  `Target repo (ABSOLUTE path, confirm with pwd): ${A.projectDir}\n` +
    `Convention to complete: ${A.pattern}\nThe good form lives here: ${A.form}\n` +
    `Non-compliant sites (FROZEN worklist — do not add to it):\n${worklist.map((s) => `- ${typeof s === 'string' ? s : `${s.file}:${s.line} (${s.appliesBecause || ''})`}`).join('\n')}\n` +
    `Read the good form AND every site. Map the dependencies adoption touches — and map ` +
    `them in Chesterton's direction too: before planning to change or remove anything at ` +
    `a site, verify it is not there because something ELSE depends on it. Three questions, in order:\n` +
    `1. Hoist or per-site? (hoist preferred: the form gets extracted/shared and sites ` +
    `adopt it; per-site is legitimate when sharing costs more than it returns, e.g. ` +
    `deliberate self-containment — state the reason.)\n` +
    `2. Do the sites feed a SHARED DERIVED STATE? A computed constant, a max, a ` +
    `negotiated capability, a threshold the verify uses that the sites determine. If ` +
    `yes, PARTIAL migration is a breakage mode (every agent correct on its own file, ` +
    `verify green, system broken): strategy derive-first (make the state computed from ` +
    `the sites BEFORE touching any of them — goes in hoistStep; preferred) or all-at-once.\n` +
    `3. For each site: does the good form TRULY apply? A site with no form to migrate ` +
    `to goes in nonMigrable with its reason, not forced into the plan.\n` +
    `Give every planned site its EXCLUSIVE files. Estimate the cost honestly. If a ` +
    `conflict is not manageable autonomously, fill blockedQuestion (one line + the cost ` +
    `of not deciding + the default) and do NOT plan that site.` +
    (sites.length > worklist.length ? `\nWARNING: the worklist is CAPPED (${worklist.length} of ${sites.length} non-compliant sites). If shared derived state exists, the sites OUTSIDE the cap feed it too: derive-first or blockedQuestion, never silent partiality.` : '') +
    (A.budgetNote ? `\nConstraints: ${A.budgetNote}` : ''),
  { label: 'assess', phase: 'Assess', schema: ASSESS },
)
if (!assess) throw new Error('assess missing: no execution without an evidence-backed verdict')
if (assess.blockedQuestion) {
  log('conflicts not manageable autonomously: stopping BEFORE touching any file')
  return { blocked: assess.blockedQuestion, assess, before: `${compliantBefore}/${total}` }
}
// Mechanical enforcement of shared derived state: the prompt asks, but the BODY refuses
// dangerous partiality — trusting a single agent's judgment is exactly what this field
// exists to not require.
const sds = assess.sharedDerivedState || { exists: false }
const nonMigrable = assess.nonMigrable || []
if (sds.exists) {
  if (sds.strategy === 'derive-first' && !assess.hoistStep) {
    throw new Error('derive-first declared without a hoistStep: the shared state must become computed from the sites BEFORE any of them is touched')
  }
  const covered = assess.plan.length + nonMigrable.length
  if (sds.strategy !== 'derive-first' && (sites.length > worklist.length || covered < worklist.length)) {
    log('shared derived state + partial coverage: stopping BEFORE touching any file')
    return {
      blocked: `The sites feed a shared derived value (${sds.description || 'see assess'}) and this run does not cover them all (${covered} planned/accounted of ${sites.length} non-compliant). Migrating a subset breaks the rest. Options: raise maxSites for a complete wave, or strategy derive-first. Cost of not deciding: the migration stays parked. Default on a bare "ok": derive-first.`,
      assess, before: `${compliantBefore}/${total}`,
    }
  }
}
log(`verdict: ${assess.approach}${sds.exists ? ` + shared state (${sds.strategy})` : ''} — ${assess.reasoning.slice(0, 120)}`)

// ---- Execute: the preliminary step first (ONE agent owns the shared module), then one
// agent per site in parallel — file disjointness comes from the plan, not from hope.
phase('Execute')
// hoistStep runs whenever present, regardless of approach: derive-first uses it in
// per-site mode too (the shared state becomes computed before sites are touched).
if (assess.hoistStep && (assess.approach === 'hoist' || (sds.exists && sds.strategy === 'derive-first'))) {
  const h = await agent(
    `Repo: ${A.projectDir}. Execute ONLY this preliminary step: ${assess.hoistStep}\n` +
      `Do not touch the worklist sites: they come next, each with its own agent. ` +
      `Report the files you created/modified.`,
    { label: 'hoist', phase: 'Execute' },
  )
  if (!h) throw new Error('preliminary step failed: sites do not start without it')
}
const results = (await parallel(assess.plan.map((p) => () =>
  agent(
    `Repo: ${A.projectDir}. Site: ${p.site}\nAction: ${p.action}\n` +
      `Files you own EXCLUSIVELY (touch nothing outside them; if you need to, the plan is wrong — stop and say so): ${p.ownFiles.join(', ')}\n` +
      `Adopt the form (${A.form}) — adoption REMOVES the old variant, it does not fence ` +
      `it: no guards, debt comments or exceptions around the old behavior.`,
    { label: `site:${p.site.slice(0, 30)}`, phase: 'Execute', schema: SITE_RESULT },
  ),
))).filter(Boolean)
const failed = results.filter((r) => !r.done)

// ---- Verify: the PROJECT's verify (may be a structural check: not every repo has a
// suite), serialized when the project declares contention; then the recount with THE
// SAME sensor as the scout; then the anti-fence check on the diff.
phase('Verify')
const verifyOut = await agent(
  `Repo: ${A.projectDir}. Run EXACTLY the verify the project declares and report the ` +
    `raw output (meaningful tail) and the exit code:\n${A.verify}\n` +
    (A.contention ? `CONTENTION CONSTRAINT declared by the project: ${A.contention} — run SERIALLY, never concurrent runs.` : ''),
  { label: 'verify', phase: 'Verify' },
)
const recount = await workflow('pattern-coverage', {
  pattern: A.pattern,
  globs: A.globs || [],
  hint: `${A.hint || ''} — target repo: ${A.projectDir}. Post-migration recount.`.trim(),
})
const fence = await agent(
  `Repo: ${A.projectDir}. Look at the uncommitted diff (git diff + status). Search for ` +
    `what the diff ADDS as variant-keyed special-casing: conditionals, guards, exceptions ` +
    `or debt comments naming a specific site/variant. The right migration REMOVES ` +
    `distinctions, it does not add them. Report every occurrence with file:line.`,
  { label: 'anti-fence', phase: 'Verify', schema: FENCE_CHECK },
)
// "3 of 4, and the fourth for this reason" is a decision; "75% coverage" is just a
// percentage: non-migrable sites come out NAMED with their reason, never counted as missing.
const doneSites = results.filter((r) => r.done)
return {
  before: `${compliantBefore}/${total}`,
  after: recount ? `${recount.compliant ?? 0}/${recount.total || 0}` : 'recount unavailable',
  reading: `${doneSites.length} of ${worklist.length} migrated` +
    (nonMigrable.length ? `; ${nonMigrable.length} non-migrable: ${nonMigrable.map((n) => `${n.site} (${n.reason})`).join('; ')}` : '') +
    (failed.length ? `; ${failed.length} failed` : ''),
  approach: assess.approach,
  sharedDerivedState: sds.exists ? { ...sds } : undefined,
  sitesDone: doneSites.map((r) => r.site),
  sitesFailed: failed.map((r) => `${r.site}: ${r.summary}`),
  nonMigrable,
  deferredSites: sites.length > MAX_SITES ? sites.length - MAX_SITES : 0,
  verify: verifyOut,
  fenceCheck: fence,
  estimatedCost: assess.estimatedCost,
}
