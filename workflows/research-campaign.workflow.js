// research-campaign — blueprint 2 (staleness pattern, generalized), executable form.
// One work package per invocation: pre-registered PREDICTION (schema-forced, BEFORE any
// execution at all) → evidence-first execution → GRADE by an INDEPENDENT agent against
// the registered prediction → hand-back memo for the PI (the five-hand-back precedent:
// the memo is the interface, the ruling stays human). An honest grade stops depending
// on the loop's memory: it lives in the returned value, not in the conversation.
//
// Install: cp into <project>/.claude/workflows/ · Invoke: Workflow({name: "research-campaign",
//   args: {wp: "<work package: question + context>", anchors: ["research/AGENDA.md", ...],
//          budgetNote?: "<spend/time constraints for the execution>"}})
// Pilot on a real WP: gated on docket B3 (roadmap-build).
export const meta = {
  name: 'research-campaign',
  description: 'Prediction-gated research WP: pre-register → execute → independent grade → memo',
  whenToUse: 'Publication-shaped work with a thesis and work packages (blueprint 2); one WP per run. args: {wp: string, anchors?: string[], budgetNote?: string} — or the WP as a free-text string',
  phases: [
    { title: 'Predict', detail: 'falsifiable pre-registration, schema-forced' },
    { title: 'Execute', detail: 'evidence-first execution of the WP' },
    { title: 'Grade', detail: 'independent agent judges against the registered prediction' },
  ],
}

const PREDICTION = {
  type: 'object',
  required: ['hypothesis', 'prediction', 'metric', 'failCondition'],
  properties: {
    hypothesis: { type: 'string', description: 'what we believe to be true and why (1-3 sentences)' },
    prediction: { type: 'string', description: 'a FALSIFIABLE statement of what we will observe' },
    metric: { type: 'string', description: 'how the outcome is measured, mechanically' },
    failCondition: { type: 'string', description: 'what, if observed, = prediction REFUTED' },
    risks: { type: 'array', items: { type: 'string' } },
  },
}

const EXECUTION = {
  type: 'object',
  required: ['summary', 'evidence', 'metricReading'],
  properties: {
    summary: { type: 'string', description: 'what was done, 3-8 sentences' },
    evidence: { type: 'string', description: 'RAW output of the decisive commands/experiments' },
    metricReading: { type: 'string', description: 'the reading of the pre-registered metric' },
    artifacts: { type: 'array', items: { type: 'string' }, description: 'paths produced' },
    surprises: { type: 'array', items: { type: 'string' } },
  },
}

const GRADE = {
  type: 'object',
  required: ['verdict', 'reasoning'],
  properties: {
    verdict: { type: 'string', enum: ['confirmed', 'refuted', 'inconclusive'] },
    reasoning: { type: 'string', description: 'mechanical reading-vs-prediction comparison' },
    driftNoted: { type: 'string', description: 'execution outside the declared WP, if seen' },
  },
}

// Tolerant, self-describing args (fix 2026-08-13). The runtime may deliver args as a
// JSON string (pilot B3, run wf_aa8e9d69); but a FREE-TEXT string made JSON.parse blow
// up with "Unexpected identifier" — an error that names neither the missing field nor
// the expected shape, and in an autonomous loop that is the worst failure mode: zero
// agents started, no readable cause. Now: JSON if it is JSON, free text mapped onto the
// primary field where that is unambiguous, otherwise an error that SHOWS the shape.
// ORIGIN of the confusion (established 2026-08-13): the Skill tool's result composes the
// "Invoke: Workflow({name, args: ...})" line by INTERPOLATING the user's natural-language
// arguments, without passing them through the schema — so the invoker sees an example
// that is syntactically valid and semantically wrong. Not fixable from here: it gets
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
const A = parseArgs(args, 'wp', '{wp: string, anchors?: string[], budgetNote?: string}')
if (!A.wp) {
  throw new Error('required args: {wp: string, anchors?: string[], budgetNote?: string}')
}
const anchors = (A.anchors || []).join(', ') || 'no anchors given'

const pred = await agent(
  `Research work package: ${A.wp}\nAnchors to read first: ${anchors}.\n` +
    `PRE-REGISTER the prediction BEFORE any execution (blueprint 2 rule: pre-registration ` +
    `is the vaccine against after-the-fact grading). Falsifiable: if you cannot say what ` +
    `would refute it, it is not a prediction. Do NOT execute any part of the WP.`,
  { label: 'predict', phase: 'Predict', schema: PREDICTION },
)
if (!pred) throw new Error('pre-registration missing: the WP does not start without a prediction')
log(`prediction registered: ${pred.prediction.slice(0, 100)}`)

const exec = await agent(
  `Execute the work package: ${A.wp}\nAnchors: ${anchors}. ${A.budgetNote || ''}\n` +
    `Pre-registered prediction (do NOT bend the results to please it — the evidence ` +
    `rules): "${pred.prediction}". Metric to read: ${pred.metric}. Report raw output ` +
    `of the decisive steps and the metric reading, whatever it turns out to be.`,
  { label: 'execute', phase: 'Execute', schema: EXECUTION },
)
if (!exec) throw new Error('execution failed or skipped')

const grade = await agent(
  `You are the INDEPENDENT grader of a pre-registered experiment. You did not do the work: ` +
    `judge ONLY from the mechanical comparison.\nPrediction: "${pred.prediction}"\nMetric: ` +
    `${pred.metric}\nRefutation condition: ${pred.failCondition}\nReported reading: ` +
    `${exec.metricReading}\nRaw evidence:\n${(() => { const e = String(exec.evidence == null ? '' : exec.evidence); return e.length <= 4000 ? e : `${e.slice(0, 4000)}\n… [EXCERPT TRUNCATED: showing 4000 of ${e.length} characters — if the evidence shown does not discriminate, the verdict is inconclusive DUE TO TRUNCATION: say so, do not infer]` })()}\n` +
    `Honest verdict: confirmed only if the reading satisfies the prediction; refuted if ` +
    `the failCondition fires; inconclusive if the evidence does not discriminate (and say ` +
    `what would be missing). If execution went outside the declared WP, note the drift.`,
  { label: 'grade', phase: 'Grade', schema: GRADE },
)
if (!grade) throw new Error('grading failed')
log(`grade: ${grade.verdict}`)

// hand-back memo: assembled in code, not by an agent — the format is the contract
const memo = [
  `# Hand-back — WP: ${A.wp.slice(0, 80)}`,
  `**Prediction (pre-registered):** ${pred.prediction}`,
  `**Metric:** ${pred.metric} · **Refuted if:** ${pred.failCondition}`,
  `**Reading:** ${exec.metricReading}`,
  `**Verdict (independent grader):** ${grade.verdict} — ${grade.reasoning}`,
  grade.driftNoted ? `**Drift noted:** ${grade.driftNoted}` : null,
  exec.surprises && exec.surprises.length ? `**Surprises:** ${exec.surprises.join(' · ')}` : null,
  `**Artifacts:** ${(exec.artifacts || []).join(', ') || 'none declared'}`,
  `**To the PI:** the ruling on the next step is yours (proceed / repeat with a variant / close the WP).`,
].filter(Boolean).join('\n')

return { prediction: pred, execution: { summary: exec.summary, metricReading: exec.metricReading }, grade, handBackMemo: memo }
