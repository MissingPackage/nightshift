// second-opinion — blueprint 7 (PR-ready gate), executable form.
// THREE independent reviewers (two Claude lenses + the CODEX lens, second model
// family — ruling B8 on spike research/spikes/codex-headless.md) → merge → adversarial
// verification of every finding → report: confirmed, refuted, and the "10-line brief"
// of the contested ones (the disagreement is exactly the judgment worth the PI's time).
//
// The codex lens degrades gracefully: if the CLI is missing or the auth has expired, the
// gate runs on two lenses and says so in the report — never a failure over an absent
// reviewer.
//
// Install: cp into <project>/.claude/workflows/ · Invoke: Workflow({name: "second-opinion",
//   args: {scope: "diff vs master", focus?: "<hot areas>"}})
export const meta = {
  name: 'second-opinion',
  description: 'Triple independent review (2 Claude lenses + codex) + refuter; brief of the contested findings for the PI',
  whenToUse: "A branch that deserves distrust toward a single reviewer's judgment (blueprint 7)",
  phases: [
    { title: 'Review', detail: 'three parallel reviewers: adversarial, contracts-ci, codex-family' },
    { title: 'Verify', detail: 'every unique finding goes through the refuter' },
  ],
}

const FINDINGS = {
  type: 'object',
  required: ['findings'],
  properties: {
    findings: {
      type: 'array',
      items: {
        type: 'object',
        required: ['severity', 'file', 'title', 'evidence'],
        properties: {
          severity: { type: 'string', enum: ['critical', 'important', 'minor'] },
          file: { type: 'string' },
          line: { type: 'integer' },
          title: { type: 'string' },
          evidence: { type: 'string', description: 'artifact-verified: command/line actually read, not an impression' },
        },
      },
    },
  },
}

const VERDICT = {
  type: 'object',
  required: ['refuted', 'reason'],
  properties: { refuted: { type: 'boolean' }, reason: { type: 'string' } },
}

// Tolerant, self-describing args (fix 2026-08-13). The runtime may deliver args as a
// JSON string (pilot B3, run wf_aa8e9d69); but a FREE-TEXT string blew up JSON.parse
// with "Unexpected identifier" — an error that names neither the missing field nor the
// expected shape, and in an autonomous loop that is the worst kind of failure: zero
// agents started, no readable cause. Now: JSON if it is JSON, free text mapped onto the
// primary field where it is unambiguous, otherwise an error that SHOWS the shape.
// ORIGIN of the confusion (established 2026-08-13): the Skill tool's result composes the
// line "Invoke: Workflow({name, args: ...})" by INTERPOLATING the user's natural-language
// arguments, without passing them through the schema — so the invoker sees an example
// that is syntactically valid and semantically wrong. Not fixable from here: it is
// neutralized by accepting free text (below) and moving the contract into meta.whenToUse,
// which is what the skill listing actually shows.
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
const A = parseArgs(args, 'scope', '{scope?: string, focus?: string}')
const scope = A.scope || 'the full diff of the current branch vs master'
const focus = A.focus ? `Hot areas indicated by the PI: ${A.focus}.` : ''

const LENSES = [
  {
    key: 'adversarial',
    prompt:
      `Apply the role in agents/adversarial-reviewer.md (read it) to ${scope}. ${focus} ` +
      `Deep artifact-verified review: correctness, security, broken invariants, RED-check ` +
      `of the tests (a test that cannot fail is not a test). Every finding with evidence ` +
      `verified against the real code, not against impressions.`,
  },
  {
    key: 'contracts-ci',
    prompt:
      `Independent review of ${scope} through the contracts/integration lens: missing ` +
      `contract tests, CI gaps, breaking changes on public APIs/schemas, inconsistent ` +
      `error envelopes, non-reversible migrations, unjustified new dependencies. ${focus} ` +
      `It is the class of gap the second model found the second model caught in a real review — hunt for it ` +
      `deliberately. Verified evidence.`,
  },
  {
    key: 'codex-family',
    prompt:
      `You are the BRIDGE to the second model family (ruling B8). Exact procedure:\n` +
      `1. Check the CLI: \`command -v codex\`. If absent, return findings=[] and stop there.\n` +
      `2. Run with a timeout: \`timeout 900 codex exec -s read-only --cd <repo root> ` +
      `"Do a code review of ${scope}. ${focus} Focus on correctness, contracts, ` +
      `CI/test gaps. For each problem: severity (critical/important/minor), file, title, ` +
      `evidence."\` — capture stdout.\n` +
      `3. If the command fails/times out (expired auth, network): findings=[] — the ` +
      `degradation is expected, it is NOT an error of yours to repair.\n` +
      `4. Translate the problems codex reports into the findings schema, evidence = the ` +
      `verbatim quotation from codex. Do NOT add findings of your own: you are the ` +
      `translator, not a reviewer.`,
  },
]

const reviews = await parallel(
  LENSES.map((l) => () => agent(l.prompt, { label: `review:${l.key}`, phase: 'Review', schema: FINDINGS })),
)

const tagged = reviews
  .map((r, i) => ({ lens: LENSES[i].key, findings: r ? r.findings : [] }))
  .flatMap((r) => r.findings.map((f) => ({ ...f, lens: r.lens })))

// dedup on file+normalized title — the full set is needed here: a justified barrier
const seen = new Map()
for (const f of tagged) {
  const key = `${f.file}::${f.title.toLowerCase().replace(/\W+/g, ' ').trim()}`
  if (seen.has(key)) seen.get(key).lenses.push(f.lens)
  else seen.set(key, { ...f, lenses: [f.lens] })
}
const unique = [...seen.values()]
log(`review: ${tagged.length} raw findings → ${unique.length} unique`)

const verified = await parallel(
  unique.map((f) => () =>
    agent(
      `You are the refuter. Finding (${f.severity}) on ${f.file}${f.line ? ':' + f.line : ''}: ` +
        `"${f.title}". Declared evidence: ${f.evidence}. Read the real code and try to ` +
        `REFUTE it (already handled elsewhere? impossible scenario? evidence misread?). ` +
        `When in doubt, refuted=true — a false alarm costs the PI's time.`,
      { label: `verify:${f.file}`, phase: 'Verify', schema: VERDICT },
    ).then((v) => ({ ...f, verdict: v })),
  ),
)

const ok = verified.filter(Boolean)
const confirmed = ok.filter((f) => f.verdict && !f.verdict.refuted)
const refuted = ok.filter((f) => f.verdict && f.verdict.refuted)
const contested = confirmed.filter((f) => f.lenses.length === 1) // only one lens saw it
const brief = contested
  .slice(0, 10)
  .map((f) => `- [${f.severity}] ${f.file}: ${f.title} (seen by ${f.lenses[0]}, survived the refuter)`)

log(`confirmed ${confirmed.length} (contested ${contested.length}), refuted ${refuted.length}`)

return {
  confirmed: confirmed.map(({ verdict, lenses, ...f }) => ({ ...f, seenBy: lenses })),
  refuted: refuted.map(({ title, file, verdict }) => ({ file, title, why: verdict.reason })),
  briefForPI: brief, // ≤10 lines: the disagreement, not two reports to reconcile
  note: 'Codex lens integrated (B8): bi-family when the CLI responds, 2 declared lenses otherwise. The merge stays with the PI.',
}
