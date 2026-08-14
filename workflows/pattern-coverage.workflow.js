// pattern-coverage — blueprint 5 (pattern migration / anti-slop), executable form.
// Measures coverage of a convention: baseline count → classify fan-out → adversarial
// verification of the non-compliant sites → report n/total + exact worklist + motivated
// exceptions. The FIX stays outside (briefs/PI): this workflow is the sensor, not the
// executor — "mostly applied" (the pattern that exists at 30% of its sites) stops being expressible
// because the number is mechanical.
//
// Install: cp into <project>/.claude/workflows/ · Invoke: Workflow({name: "pattern-coverage",
//   args: {pattern: "<the convention, e.g. 'domain events emitted via outbox'>",
//          globs: ["src/**/*.py"], hint: "<where to look / what counts as a site>",
//          model?: "<sonnet|haiku — cost control; omit to inherit the session model>",
//          maxVerify?: 12   // bound on the per-site skeptic fan-out (no silent cap)}})
export const meta = {
  name: 'pattern-coverage',
  description: 'Mechanical coverage baseline of a convention: n/total, worklist, exceptions',
  whenToUse: 'Before and after a pattern migration; as the pre-merge gate of blueprint 5',
  phases: [
    { title: 'Classify', detail: 'one classifier per glob-group enumerates the sites' },
    { title: 'Verify', detail: 'every non-compliant site is re-verified by a skeptic' },
  ],
}

const SITES = {
  type: 'object',
  required: ['sites'],
  properties: {
    sites: {
      type: 'array',
      items: {
        type: 'object',
        required: ['file', 'line', 'appliesBecause', 'compliant'],
        properties: {
          file: { type: 'string' },
          line: { type: 'integer' },
          appliesBecause: { type: 'string' },
          compliant: { type: 'boolean' },
          exceptionClaim: { type: 'string', description: 'present only if the site claims a justified exception' },
        },
      },
    },
  },
}

const VERDICT = {
  type: 'object',
  required: ['confirmedNonCompliant', 'reason'],
  properties: {
    confirmedNonCompliant: { type: 'boolean' },
    reason: { type: 'string' },
  },
}

// Tolerant, self-describing args (fix 2026-08-13). The runtime may deliver args as a
// JSON string (pilot B3, run wf_aa8e9d69); but a FREE-TEXT string blew up JSON.parse
// with "Unexpected identifier" — an error that names neither the missing field nor the
// expected shape, and in an autonomous loop that is the worst possible failure: zero
// agents started, no readable cause. Now: JSON if it is JSON, free text mapped onto the
// primary field where it is unambiguous, otherwise an error that SHOWS the shape.
// ORIGIN of the confusion (established 2026-08-13): the Skill tool's result composes the
// line "Invoke: Workflow({name, args: ...})" by INTERPOLATING the user's natural-language
// arguments, without passing them through the schema — so the invoker sees an example
// that is syntactically valid and semantically wrong. Not fixable from here: it is
// neutralized by accepting free text (below) and by carrying the contract in
// meta.whenToUse, which is what the skill listing actually shows.
function parseArgs(raw, primary, usage) {
  if (raw == null) return {}
  if (typeof raw !== 'string') return raw || {}
  const s = raw.trim()
  if (s.startsWith('{') || s.startsWith('[') || s.startsWith('"')) {
    try {
      return JSON.parse(s)
    } catch (e) {
      throw new Error(`args: invalid JSON string (${e.message}). Expected shape: ${usage}`)
    }
  }
  if (primary) return { [primary]: raw }
  throw new Error(`args: got free text, but this workflow requires ${usage}`)
}
const A = parseArgs(args, null, '{pattern: string, globs: string[], hint?: string, model?: string, maxVerify?: number}')
if (!A.pattern || !Array.isArray(A.globs) || A.globs.length === 0) {
  throw new Error('required args: {pattern: string, globs: string[], hint?: string, model?: string, maxVerify?: number}')
}
// Cost knobs (2026-08-14: a first real run inherited the session model — fable — and the
// skeptic fan-out spawned one agent PER non-compliant site: 57 agents before the PI hit
// stop. The sensor, not the migration, dominates the agent count).
const MO = A.model ? { model: A.model } : {}
const MAX_VERIFY = A.maxVerify ?? 12   // skeptics are a per-site fan-out: bound it

log(`pattern: ${A.pattern} — ${A.globs.length} glob group(s)`)

const results = await pipeline(
  A.globs,
  (glob) =>
    agent(
      `Convention under measurement: "${A.pattern}". ${A.hint ? 'Context: ' + A.hint : ''}\n` +
        `Enumerate EVERY site in the files matching ${glob} where the convention APPLIES ` +
        `(not only where it is violated). For each site: file, line, why it applies, whether ` +
        `it is compliant, and any justified-exception claim found in comments/ADRs. ` +
        `Be exhaustive: one missed site falsifies the baseline. Modify nothing.`,
      { label: `classify:${glob}`, phase: 'Classify', schema: SITES, ...MO },
    ),
  (res, glob) => {
    if (!res) return null
    const nc = res.sites.filter((s) => !s.compliant)
    const toVerify = nc.slice(0, MAX_VERIFY)
    if (nc.length > toVerify.length) {
      log(`declared cap: ${toVerify.length}/${nc.length} non-compliant sites of ${glob} get a skeptic; the rest enter the worklist UNVERIFIED (no silent cap)`)
    }
    return parallel(
          toVerify
            .map((s) => () =>
              agent(
                `You are a skeptic. Site: ${s.file}:${s.line} — declared NON-compliant with the ` +
                  `convention "${A.pattern}" because: ${s.appliesBecause}. Read the actual ` +
                  `code and try to REFUTE the non-compliance (false positive? legitimate ` +
                  `exception? the pattern does not apply here?). When in doubt: confirmedNonCompliant=false.`,
                { label: `verify:${s.file}:${s.line}`, phase: 'Verify', schema: VERDICT, ...MO },
              ).then((v) => ({ ...s, verdict: v })),
            ),
        ).then((verified) => ({ glob, sites: res.sites,
          verified: verified.filter(Boolean).concat(
            nc.slice(MAX_VERIFY).map((s) => ({ ...s, verdict: { confirmedNonCompliant: true, reason: 'beyond maxVerify cap: unverified, kept in worklist' } }))) }))
  },
)

const groups = results.filter(Boolean)
const allSites = groups.flatMap((g) => g.sites)
const worklist = groups
  .flatMap((g) => g.verified)
  .filter((s) => s.verdict && s.verdict.confirmedNonCompliant)
  .map(({ file, line, appliesBecause, verdict }) => ({ file, line, appliesBecause, reason: verdict.reason }))
const exceptions = allSites.filter((s) => s.exceptionClaim).map(({ file, line, exceptionClaim }) => ({ file, line, exceptionClaim }))
const total = allSites.length
const compliant = total - worklist.length

log(`coverage: ${compliant}/${total} — worklist ${worklist.length}, declared exceptions ${exceptions.length}`)

return {
  pattern: A.pattern,
  total,
  compliant,
  coveragePercent: total ? Math.round((1000 * compliant) / total) / 10 : 100,
  worklist,
  exceptionsToRule: exceptions, // exceptions are judged by the PI (blueprint 5), never by the workflow
}
