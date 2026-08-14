// sdd-conductor — R6, design in SDD-CONDUCTOR-DESIGN.md, parameters ruled B4 (2026-07-17):
// 1.5M/run cap is INDICATIVE (V2 2026-07-18: soft limit — an estimate overrun gets logged, not
// rejected; the only hard limit left is the runtime's budget.total when set by the caller) · fullAuto default (ONLY this workflow:
// SDD development — research and planning stay gated, B4 clarification) · RED-phase only on
// testable doneWhen · patch-apply merge, conflicts=BLOCKED, never auto-resolution.
//
// Patch-based flow: implementers do NOT touch the shared tree — they work on a temporary
// copy of projectDir and return a unified diff; only the integrator applies it
// (sequential, in wave order). Declared deviation from design §3: "fix round dello
// stesso implementer a contesto caldo" (fix round by the same implementer with warm
// context) ≈ a new agent with brief+patch+finding in the prompt
// (the runtime cannot resume an agent inside a workflow).
//
// BLOCKED tasks do not stop the build (design §3): they end up in blockedTasks +
// docketEntries in the return value — it is the CALLER (the session) that appends them
// to the docket; the runtime does not write files.
//
// Invoke: Workflow({name: 'sdd-conductor', args: {spec: '<US + AC + read-first>',
//   projectDir: '<root of the target project>', suiteCmd: '<suite command>',
//   capTokens?: 1500000, steering?: false, sweepPattern?: '<pattern for pattern-coverage>'}})
export const meta = {
  name: 'sdd-conductor',
  description: 'SDD spec → §4-contract task graph validated in code → 2-round adversarial implement+review waves → patch-apply integrate',
  whenToUse: 'Spec-first multi-task development build; NOT for research/brainstorming (B4 clarification). REQUIRED args: {spec: string, projectDir: string, suiteCmd: string}',
  phases: [
    { title: 'Plan', detail: 'spec → schema-forced task graph; disjoint owns, acyclic, mechanical doneWhen — validated in code' },
    { title: 'Implement', detail: 'per task: isolated copy, RED-phase if testable, patch + evidence' },
    { title: 'Review', detail: 'adversarial 2-round; surviving critical ⇒ task BLOCKED' },
    { title: 'Integrate', detail: 'sequential patch-apply per wave; conflict ⇒ BLOCKED; project suite' },
  ],
}

const PLAN = {
  type: 'object',
  required: ['tasks'],
  properties: {
    tasks: {
      type: 'array',
      minItems: 1,
      items: {
        type: 'object',
        required: ['id', 'dependsOn', 'brief'],
        properties: {
          id: { type: 'string' },
          dependsOn: { type: 'array', items: { type: 'string' } },
          brief: {
            type: 'object',
            required: ['owns', 'tools', 'interfaceFreeze', 'doneWhen'],
            properties: {
              owns: { type: 'array', items: { type: 'string' }, minItems: 1, description: "the task's EXCLUSIVE path set" },
              tools: { type: 'array', items: { type: 'string' }, description: 'what is truly needed' },
              interfaceFreeze: { type: 'string', description: 'exposed/consumed signatures, frozen' },
              doneWhen: { type: 'string', description: 'MECHANICAL: a test or verifiable artifact' },
              testable: { type: 'boolean', description: 'true if doneWhen is an executable test (⇒ RED-phase, B4c)' },
            },
          },
        },
      },
    },
  },
}

const IMPL = {
  type: 'object',
  required: ['summary', 'patch', 'doneWhenResult'],
  properties: {
    summary: { type: 'string' },
    patch: { type: 'string', description: 'unified diff relative to the projectDir root (git diff)' },
    redEvidence: { type: 'string', description: 'RAW output of the doneWhen test FAILING before the implementation (mandatory if testable)' },
    doneWhenResult: { type: 'string', description: 'RAW output of the doneWhen after the implementation' },
    filesTouched: { type: 'array', items: { type: 'string' } },
  },
}

const FINDINGS = {
  type: 'object',
  required: ['verdict', 'findings'],
  properties: {
    verdict: { type: 'string', enum: ['approve', 'fix-needed'] },
    findings: {
      type: 'array',
      items: {
        type: 'object',
        required: ['severity', 'evidence'],
        properties: {
          severity: { type: 'string', enum: ['critical', 'major', 'minor'] },
          evidence: { type: 'string' },
          file: { type: 'string' },
        },
      },
    },
  },
}

const REVIEW2 = {
  type: 'object',
  required: ['verdict', 'survived'],
  properties: {
    verdict: { type: 'string', enum: ['approve', 'blocked'] },
    survived: { type: 'array', items: { type: 'object', required: ['severity', 'evidence'], properties: { severity: { type: 'string' }, evidence: { type: 'string' } } } },
  },
}

const VERIFYW = {
  type: 'object',
  required: ['applied', 'perTask'],
  properties: {
    applied: { type: 'boolean', description: 'true ONLY if the full suite is green in projectDir' },
    perTask: { type: 'array', items: { type: 'object', required: ['id', 'ok'], properties: { id: { type: 'string' }, ok: { type: 'boolean' }, output: { type: 'string' } } } },
    suiteOutput: { type: 'string' },
  },
}

const INTEGRATE = {
  type: 'object',
  required: ['applied'],
  properties: {
    applied: { type: 'boolean' },
    conflictDetail: { type: 'string', description: 'output of git apply --check if it failed' },
    suiteOutput: { type: 'string' },
  },
}

// ---- validations IN CODE (design §2: rejection, not judgment) ----

// --- channel: never truncate silently (fix 2026-08-13, engine-kernel-decode finding) ---
// A patch cut mid-hunk reaches `git apply` as a "corrupt patch": the channel MAKES a
// nonexistent owns-plan defect LOOK real (5 tasks BLOCKED, one iteration lost).
// Rule: payloads that must stay intact (the patches) are NEVER truncated; excerpts for
// human eyes get truncated with a visible MARK.
const PATCH_SANITY_MAX = 400_000 // anti-runaway guard only: beyond it, BLOCK with an explicit reason, never cut
function excerpt(s, n) {
  const v = s == null ? '' : String(s)
  return v.length <= n ? v : `${v.slice(0, n)}\n… [EXCERPT TRUNCATED: showing ${n} of ${v.length} characters]`
}

function pathsOverlap(a, b) {
  const norm = (p) => String(p).replace(/\/+$/, '') + '/'
  return norm(a).startsWith(norm(b)) || norm(b).startsWith(norm(a))
}

function validatePlan(plan) {
  const errs = []
  if (!plan.tasks || !plan.tasks.length) {
    errs.push('empty plan: no tasks') // defense-in-depth beyond the schema minItems (verifier it1)
    return errs
  }
  const ids = new Set()
  for (const t of plan.tasks) {
    if (ids.has(t.id)) errs.push(`duplicate id: ${t.id}`)
    ids.add(t.id)
    if (!String((t.brief || {}).doneWhen || '').trim()) errs.push(`empty doneWhen: task ${t.id}`)
    if (!((t.brief || {}).owns || []).length) errs.push(`empty owns: task ${t.id}`)
  }
  const ts = plan.tasks
  for (let i = 0; i < ts.length; i++) {
    for (let j = i + 1; j < ts.length; j++) {
      for (const a of (ts[i].brief || {}).owns || []) {
        for (const b of (ts[j].brief || {}).owns || []) {
          if (pathsOverlap(a, b)) errs.push(`overlapping owns: ${ts[i].id}(${a}) ∩ ${ts[j].id}(${b})`)
        }
      }
    }
  }
  for (const t of ts) {
    for (const d of t.dependsOn || []) {
      if (!ids.has(d)) errs.push(`nonexistent dependency: ${t.id} -> ${d}`)
    }
  }
  return errs
}

function computeWaves(tasks) {
  // Kahn by waves: null = cycle
  const pending = new Map(tasks.map((t) => [t.id, new Set(t.dependsOn || [])]))
  const done = new Set()
  const waves = []
  while (pending.size) {
    const wave = [...pending.keys()].filter((id) => [...pending.get(id)].every((d) => done.has(d)))
    if (!wave.length) return null
    waves.push(wave)
    for (const id of wave) {
      pending.delete(id)
      done.add(id)
    }
  }
  return waves
}

// ---- Plan phase ----

phase('Plan')
// Tolerant, self-describing args (fix 2026-08-13). The runtime may deliver args as a
// JSON string (pilot B3, run wf_aa8e9d69); but a FREE-TEXT string blew up JSON.parse
// with "Unexpected identifier" — an error naming neither the missing field nor the
// expected shape, and in an autonomous loop that is the worst failure: zero agents
// started, no readable cause. Now: JSON if it is JSON, free text mapped onto the
// primary field where it is unambiguous, otherwise an error that SHOWS the shape.
// ORIGIN of the confusion (established 2026-08-13): the Skill tool's result composes
// the "Invoke: Workflow({name, args: ...})" line by INTERPOLATING the user's
// natural-language arguments, without passing them through the schema — so the invoker
// sees an example that is syntactically valid and semantically wrong. Not fixable from
// here: it gets neutralized by accepting free text (below) and moving the contract
// into meta.whenToUse, which is what the skill listing actually shows.
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
const A = parseArgs(args, null, '{spec: string, projectDir: string, suiteCmd: string, capTokens?: number}')
if (!A.spec) throw new Error("required args: {spec, projectDir, suiteCmd}")
const MO = A.model ? { model: A.model } : {} // dry-run f3: Sonnet via args, never hardcoded
// per-stage effort via args (ruling A1/C2, Opus 5 guideline: low/medium freely where
// quality holds). args.effort = {plan|implement|review|integrate|verify: 'low'|...};
// default: empty object ⇒ inherits the session, zero changes without explicit args.
const EO = (stage) => (A.effort && A.effort[stage] ? { effort: A.effort[stage] } : {})

const plan = await agent(
  `You are the SDD conductor. Spec (spec-first format — user story, acceptance criteria, read-first):\n${A.spec}\n` +
    `Decompose into tasks for parallel wave execution. For EVERY task the brief is the full ` +
    `PROPOSAL §4 contract: owns = EXCLUSIVE path set (no overlap between tasks, not even ` +
    `by prefix), tools = only what is truly needed, interfaceFreeze = the signatures the task ` +
    `exposes/consumes (frozen: whoever changes them breaks the plan), doneWhen = MECHANICAL (a test or an ` +
    `artifact a verifier can check without judgment; testable=true if it is an executable ` +
    `test). dependsOn = ids of other tasks only. Acyclic graph. Do NOT implement anything.`,
  { label: 'conductor-plan', phase: 'Plan', schema: PLAN, ...MO, ...EO('plan') },
)
if (!plan) throw new Error('Plan phase failed: no plan produced')

const errs = validatePlan(plan)
let waves = null
if (!errs.length) {
  waves = computeWaves(plan.tasks)
  if (!waves) errs.push('cyclic graph in the dependencies')
}
if (errs.length) throw new Error(`plan REJECTED by in-code validation: ${errs.join(' · ')}`)

// ---- pre-flight budget (design §5 + ruling B4a: the rejection prints the estimate) ----
const EST_PER_TASK = 200_000
const cap = A.capTokens || 1_500_000
const stima = plan.tasks.length * EST_PER_TASK
if (stima > cap) {
  // V2 (2026-07-18): capTokens is a SOFT, indicative limit — logged, not rejected.
  // Never exposed in agent prompts. The only hard limit left is budget.total (set by the caller).
  log(`pre-flight: estimate ${stima} tokens (${plan.tasks.length} tasks × ${EST_PER_TASK}) above the indicative cap ${cap} — proceeding (V2: soft limit)`)
}
if (budget.total && stima > budget.remaining()) {
  throw new Error(`pre-flight: estimate ${stima} tokens > remaining budget ${budget.remaining()} — refusing to start`)
}
log(`plan validated: ${plan.tasks.length} tasks in ${waves.length} waves · estimate ${stima} tokens (cap ${cap})`)

if (!A.projectDir || !A.suiteCmd) throw new Error('required args to execute: {projectDir, suiteCmd} (Plan-only is no longer a supported mode: pass a spec and let the pre-flight decide)')

// ---- Implement / Review / Integrate phases, per wave ----

const byId = new Map(plan.tasks.map((t) => [t.id, t]))
const REVIEWER_BRIEF = 'agents/adversarial-reviewer.md (read it and apply it; if absent: hunt for defects with concrete evidence, not style — severity critical only for correctness/data loss/security)'

function implPrompt(t) {
  const red = t.brief.testable
    ? `RED-PHASE MANDATORY (B4c): FIRST write the doneWhen test, run it and report in redEvidence the raw output showing it RED; only then implement.`
    : `doneWhen not testable: no RED-phase; produce the artifact and report the mechanical verification in doneWhenResult.`
  return (
    `Task ${t.id} of a wave-based SDD build. Do NOT touch ${A.projectDir} directly: copy its contents into a temporary directory of your own, work there (git init if needed), and return the patch as a unified diff applicable from the project root (git diff).\n` +
    `BRIEF (contract, binding):\n- owns (ONLY these paths): ${t.brief.owns.join(', ')}\n- tools: ${(t.brief.tools || []).join(', ') || 'standard'}\n- interfaceFreeze (do NOT change these signatures): ${t.brief.interfaceFreeze}\n- doneWhen: ${t.brief.doneWhen}\n${red}\n` +
    `Outside the owns you touch nothing: if you need to, the plan is wrong — stop and say so in the summary. Report in doneWhenResult the raw output of the doneWhen at the end of the work.`
  )
}

function reviewPrompt(t, impl) {
  return (
    `Adversarial review, round 1, of task ${t.id}. Brief: ${REVIEWER_BRIEF}.\n` +
    `Task contract — owns: ${t.brief.owns.join(', ')} · interfaceFreeze: ${t.brief.interfaceFreeze} · doneWhen: ${t.brief.doneWhen} · testable: ${!!t.brief.testable}\n` +
    `ALSO VERIFY: (1) if testable, that redEvidence shows the test RED before the implementation (absent or faked RED = critical finding); (2) that the patch touches ONLY the owns; (3) that doneWhenResult is real output, not a summary.\n` +
    `Implementer summary: ${impl.summary}\nredEvidence:\n${excerpt(impl.redEvidence || '(absent)', 1500)}\ndoneWhenResult:\n${excerpt(impl.doneWhenResult, 1500)}\nPATCH (in full — if it looks cut off, that is a channel bug: say so instead of inferring):\n${impl.patch}`
  )
}

async function runTask(id) {
  const t = byId.get(id)
  const impl = await agent(implPrompt(t), { isolation: 'worktree', label: `impl:${id}`, phase: 'Implement', schema: IMPL, ...MO, ...EO('implement') })
  if (!impl) return { id, status: 'BLOCKED', reason: 'implementer lost', verdicts: [] }
  const r1 = await agent(reviewPrompt(t, impl), { label: `review1:${id}`, phase: 'Review', schema: FINDINGS, ...MO, ...EO('review') })
  if (!r1) return { id, status: 'BLOCKED', reason: 'round-1 reviewer lost', verdicts: [] }
  if (r1.verdict === 'approve') return { id, status: 'ok', patch: impl.patch, impl, verdicts: [r1] }

  // fix with rebuilt context (deviation declared in the header) — ONE iteration only, then round 2
  const fix = await agent(
    `You are the implementer of task ${id}: apply the fixes the review requires WITHOUT widening the scope.\n` +
      `Brief unchanged — owns: ${t.brief.owns.join(', ')} · interfaceFreeze: ${t.brief.interfaceFreeze} · doneWhen: ${t.brief.doneWhen}\n` +
      `Your previous patch (in full):\n${impl.patch}\nFINDINGS to resolve (round 1):\n${excerpt(JSON.stringify(r1.findings), 4000)}\n` +
      `Same method: temporary copy of ${A.projectDir}, COMPLETE unified diff patch (replaces the previous one), raw doneWhenResult.`,
    { isolation: 'worktree', label: `fix:${id}`, phase: 'Review', schema: IMPL, ...MO, ...EO('implement') },
  )
  if (!fix) return { id, status: 'BLOCKED', reason: 'fix round lost', verdicts: [r1] }
  const r2 = await agent(
    `Re-review, round 2 (the LAST), of task ${id}: judge ONLY whether the round-1 findings are resolved in the new patch. Brief: ${REVIEWER_BRIEF}.\n` +
      `Round-1 findings:\n${excerpt(JSON.stringify(r1.findings), 4000)}\nNew PATCH (in full):\n${fix.patch}\ndoneWhenResult:\n${excerpt(fix.doneWhenResult, 1500)}\n` +
      `verdict=blocked ONLY if at least one critical survives (design §3: 2 rounds then the task is blocked, never a third pass).`,
    { label: `review2:${id}`, phase: 'Review', schema: REVIEW2, ...MO, ...EO('review') },
  )
  if (!r2) return { id, status: 'BLOCKED', reason: 'round-2 reviewer lost', verdicts: [r1] }
  const criticalSurvived = (r2.survived || []).some((f) => f.severity === 'critical')
  if (r2.verdict === 'blocked' || criticalSurvived) {
    return { id, status: 'BLOCKED', reason: 'critical survived round 2', verdicts: [r1, r2] }
  }
  return { id, status: 'ok', patch: fix.patch, impl: fix, verdicts: [r1, r2] }
}

const done = []
const blockedTasks = []
const docketEntries = []
let wavesRun = 0

for (let w = 0; w < waves.length; w++) {
  const wave = waves[w]
  const deferred = wave.filter((id) => (byId.get(id).dependsOn || []).some((d) => blockedTasks.some((b) => b.id === d)))
  const runnable = wave.filter((id) => !deferred.includes(id))
  for (const id of deferred) {
    blockedTasks.push({ id, status: 'BLOCKED', reason: 'upstream dependency BLOCKED', verdicts: [] })
  }
  const results = await parallel(runnable.map((id) => () => runTask(id)))
  const ok = results.filter((r) => r && r.status === 'ok')
  for (const r of results) {
    if (r && r.status === 'BLOCKED') {
      blockedTasks.push(r)
      docketEntries.push(`## SDD-${r.id} · task BLOCKED (${r.reason})\nAttached verdicts: ${excerpt(JSON.stringify(r.verdicts), 1200)}\n**RULING:** _`)
    }
  }

  phase('Integrate')
  for (const r of ok) {
    // Explicit guard in place of silent cutting: a patch beyond all measure gets
    // BLOCKED saying why, not delivered corrupted to the integrator (who would read
    // it as a conflict and blame the owns plan).
    if (typeof r.patch !== 'string' || !r.patch.length) {
      blockedTasks.push({ id: r.id, status: 'BLOCKED', reason: 'patch absent or empty from the implementer' })
      docketEntries.push(`## SDD-${r.id} · patch absent from the implementer (channel, not plan)\n**RULING:** _`)
      continue
    }
    if (r.patch.length > PATCH_SANITY_MAX) {
      blockedTasks.push({ id: r.id, status: 'BLOCKED', reason: `patch oversized for the channel (${r.patch.length} characters, ceiling ${PATCH_SANITY_MAX}) — task must be split, NOT a conflict` })
      docketEntries.push(`## SDD-${r.id} · patch oversized (${r.patch.length} characters): the task must be split\nNOT an owns-plan conflict: the patch was never applied.\n**RULING:** _`)
      continue
    }
    const integ = await agent(
      `Integrator of the SDD build (wave ${w + 1}). EXACT target directory (ABSOLUTE path, cd there and verify with pwd): ${A.projectDir} — if it does not exist or is not a git repo, applied=false with the reason; do NOT work in a similarly named directory (e.g. a fixture template in the repo: it is NOT the target). Save the patch to a temporary file OUTSIDE the target, then git apply --check; if the check is CLEAN, apply with git apply and report applied=true. If the check fails: applied=false with the detail in conflictDetail — do NOT resolve the conflict, do NOT use --3way (design §4: conflict = owns-plan bug). In conflictDetail ALWAYS also report the raw output of: pwd && git -C ${A.projectDir} status --short.\nThe patch below is IN FULL (${r.patch.length} characters, no truncation): if it looks cut off or incomplete, that is a channel defect — say so in conflictDetail instead of attributing it to the owns plan.\nPATCH task ${r.id}:\n${r.patch}`,
      { label: `merge:${r.id}`, phase: 'Integrate', schema: INTEGRATE, ...MO, ...EO('integrate') },
    )
    if (!integ || !integ.applied) {
      blockedTasks.push({ id: r.id, status: 'BLOCKED', reason: 'patch-apply conflict', detail: (integ || {}).conflictDetail || 'integrator lost' })
      docketEntries.push(`## SDD-${r.id} · patch-apply conflict (owns-plan bug)\n${excerpt((integ || {}).conflictDetail || '', 800)}\n**RULING:** _`)
    } else {
      done.push(r.id)
    }
  }

  const waveDone = ok.filter((r) => done.includes(r.id))
  let suiteGreen = true
  let suite = null
  if (waveDone.length) {
    suite = await agent(
      `INDEPENDENT wave verifier (${w + 1}/${waves.length}): you did not do the work yourself, do not trust the summaries. cd into the EXACT directory (absolute path): ${A.projectDir} (confirm with pwd in the suiteOutput). Run: (1) the full suite: ${A.suiteCmd}; (2) for EVERY integrated task, its doneWhen exactly as written. Tasks: ${waveDone.map((r) => `${r.id} → ${byId.get(r.id).brief.doneWhen}`).join(' · ')}\nReport RAW outputs; applied=true ONLY if the full suite is green; perTask[i].ok=true ONLY if that task's doneWhen is green when RUN NOW in that directory. Do not modify anything.`,
      { label: `verify:w${w + 1}`, phase: 'Integrate', schema: VERIFYW, ...MO, ...EO('verify') },
    )
    const perTask = (suite && suite.perTask) || []
    for (const r of waveDone) {
      const v = perTask.find((x) => x.id === r.id)
      if (!v || !v.ok) {
        blockedTasks.push({ id: r.id, status: 'BLOCKED', reason: 'independent post-merge verification failed', detail: (v || {}).output || 'no outcome for the task' })
        docketEntries.push(`## SDD-${r.id} · post-merge verification failed (integration claimed but not observed)\n${excerpt((v || {}).output || '', 800)}\n**RULING:** _`)
        suiteGreen = false
      }
    }
    if (!(suite && suite.applied)) suiteGreen = false
  }
  if (A.sweepPattern) {
    await workflow('pattern-coverage', { pattern: A.sweepPattern, dir: A.projectDir }).catch((e) => log(`sweep skipped: ${e.message}`))
  }
  wavesRun++
  log(`wave ${w + 1}/${waves.length}: ${done.length} integrated, ${blockedTasks.length} BLOCKED, suite ${suiteGreen ? 'green' : 'RED'}`)

  if (!suiteGreen) {
    return { status: 'blocked', wavesRun, done, blockedTasks, docketEntries, suiteOutput: (suite || {}).suiteOutput || '', note: 'post-merge red suite: build stopped (gate by exception)' }
  }
  if (A.steering && w + 1 < waves.length) {
    // opt-in B4b: one wave per invocation, the PI steers between invocations
    return { status: 'wave-complete', wavesRun, done, blockedTasks, docketEntries, nextWave: waves[w + 1], note: 'steering: to continue, re-invoke with steering:false and the resumeFromRunId of THIS run (the waves already done come back from cache; a new invocation with just the spec would always restart from wave 0)' }
  }
}

return {
  status: blockedTasks.length ? 'done-with-blocked' : 'done',
  wavesRun,
  done,
  blockedTasks,
  docketEntries,
  note: 'the docketEntries must be appended by the caller to the goal docket (the runtime does not write files)',
}
