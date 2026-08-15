// make-diagrams.mjs — regenerates the hand-drawn SVGs in assets/.
//
// They are drawn with roughjs, the same renderer Excalidraw uses, and every label is converted
// to outlines with opentype.js so each file is self-contained: no font is needed to view it,
// which is why they render in the GitHub mobile app where Mermaid does not.
//
// Prerequisites (neither is vendored: this script runs by hand, not in CI):
//   npm i roughjs opentype.js@1.3.4
//   mkdir -p .diagram-font && curl -sL -o .diagram-font/PatrickHand-Regular.ttf \
//     https://github.com/google/fonts/raw/main/ofl/patrickhand/PatrickHand-Regular.ttf
//   node tools/make-diagrams.mjs        # writes assets/*.svg, run from the repo root
//
// Font: Patrick Hand by Patrick Wagesreiter, SIL OFL 1.1. Only glyph outlines end up in the SVG.
// opentype.js is pinned to 1.3.4 on purpose: 2.0.0 emits NaN coordinates inside multi-glyph
// paths, and a NaN makes every renderer abandon the rest of the path — the first version of
// these diagrams shipped with half the labels missing because nothing checked for it.
//
// Two gates below, both learned the same way: refuse to write a NaN, and refuse a character
// the font does not carry (it would vanish silently — that is where the arrows went).
import rough from 'roughjs'
import opentype from 'opentype.js'
import { writeFileSync, readFileSync } from 'node:fs'

const FONT = process.env.FONT || '.diagram-font/PatrickHand-Regular.ttf'

const r1 = (d) => d.replace(/-?\d+\.\d+/g, (n) => String(Math.round(parseFloat(n) * 10) / 10))
const font = opentype.parse(readFileSync(FONT).buffer)
const INK = '#1e1e1e'
const YELLOW = '#ffec99', GREEN = '#b2f2bb', BLUE = '#a5d8ff', RED = '#ffc9c9', VIOLET = '#d0bfff', GREY = '#f1f3f5'

// --- text as outlines -------------------------------------------------------
const textWidth = (s, size) => font.getAdvanceWidth(s, size)
const missing = new Set()
// Glyph outlines are 95% of these files when every letter carries its own path, so each
// character is defined ONCE at 1000 units and re-used at the size it is needed.
const UNIT = 1000
const glyphDefs = new Map()
function glyphId(ch) {
  if (!glyphDefs.has(ch)) {
    glyphDefs.set(ch, r1(font.getPath(ch, 0, 0, UNIT).toPathData(1)))
  }
  return 'g' + ch.codePointAt(0).toString(16)
}
function textPaths(s, cx, cy, size, anchor = 'middle') {
  for (const ch of s) if (ch !== ' ' && font.charToGlyph(ch).index === 0) missing.add(ch)
  const w = textWidth(s, size)
  let x = anchor === 'middle' ? cx - w / 2 : anchor === 'end' ? cx - w : cx
  const k = size / UNIT
  const out = []
  const chars = [...s]
  for (let i = 0; i < chars.length; i++) {
    const ch = chars[i]
    if (ch !== ' ') {
      out.push(`<use href="#${glyphId(ch)}" transform="translate(${r1(String(x))} ${r1(String(cy))}) scale(${k})"/>`)
    }
    x += font.getAdvanceWidth(ch, size)
    const next = chars[i + 1]
    if (next) x += font.getKerningValue(font.charToGlyph(ch), font.charToGlyph(next)) * k
  }
  return out.join('')
}
function label(lines, cx, cy, size) {
  const lh = size * 1.22
  const top = cy - ((lines.length - 1) * lh) / 2
  return lines.map((l, i) => textPaths(l, cx, top + i * lh + size * 0.34, size)).join('\n')
}

// --- scene ------------------------------------------------------------------
function scene(width, height, build) {
  glyphDefs.clear()
  // roughjs needs a DOM node only to append to; we take the generator's output instead.
  const rc = rough.generator({ options: { seed: 42 } })
  const out = []
  const draw = (drawable) => {
    for (const op of rc.toPaths(drawable)) {
      out.push(`<path d="${r1(op.d)}" stroke="${op.stroke}" stroke-width="${op.strokeWidth}" fill="${op.fill || 'none'}"/>`)
    }
  }
  const api = {
    box(x, y, w, h, lines, fill = YELLOW, size = 17) {
      draw(rc.rectangle(x, y, w, h, { fill, fillStyle: 'solid', stroke: INK, strokeWidth: 1.6, roughness: 1.5, bowing: 1.4 }))
      out.push(label(lines, x + w / 2, y + h / 2, size))
    },
    diamond(x, y, w, h, lines, fill = VIOLET, size = 15) {
      const pts = [[x + w / 2, y], [x + w, y + h / 2], [x + w / 2, y + h], [x, y + h / 2]]
      draw(rc.polygon(pts, { fill, fillStyle: 'solid', stroke: INK, strokeWidth: 1.6, roughness: 1.4 }))
      out.push(label(lines, x + w / 2, y + h / 2, size))
    },
    arrow(x1, y1, x2, y2, text) {
      draw(rc.line(x1, y1, x2, y2, { stroke: INK, strokeWidth: 1.5, roughness: 1.3 }))
      const a = Math.atan2(y2 - y1, x2 - x1), L = 11, S = 0.42
      draw(rc.line(x2, y2, x2 - L * Math.cos(a - S), y2 - L * Math.sin(a - S), { stroke: INK, strokeWidth: 1.5, roughness: 1.1 }))
      draw(rc.line(x2, y2, x2 - L * Math.cos(a + S), y2 - L * Math.sin(a + S), { stroke: INK, strokeWidth: 1.5, roughness: 1.1 }))
      if (text) {
        const mx = (x1 + x2) / 2, my = (y1 + y2) / 2
        const w = textWidth(text, 14)
        out.push(`<rect x="${mx - w / 2 - 4}" y="${my - 15}" width="${w + 8}" height="19" fill="#ffffff" opacity="0.92"/>`)
        out.push(textPaths(text, mx, my, 14))
      }
    },
    region(x, y, w, h, title) {
      draw(rc.rectangle(x, y, w, h, { fill: '#f8f9fa', fillStyle: 'solid', stroke: '#adb5bd', strokeWidth: 1.4, roughness: 1.8 }))
      if (title) out.push(textPaths(title, x + 200, y + 30, 17, 'start'))
    },
    tag(x, y, w, lines, fill = '#ffd8a8') {
      const h = 24 + (lines.length - 1) * 19
      draw(rc.rectangle(x, y, w, h, { fill, fillStyle: 'solid', stroke: INK, strokeWidth: 1.2, roughness: 1.2 }))
      out.push(label(lines, x + w / 2, y + h / 2, 13))
    },
    dashed(x1, y1, x2, y2) {
      draw(rc.line(x1, y1, x2, y2, { stroke: '#868e96', strokeWidth: 1.4, roughness: 1, strokeLineDash: [8, 6] }))
    },
    line(x1, y1, x2, y2) { draw(rc.line(x1, y1, x2, y2, { stroke: INK, strokeWidth: 1.5, roughness: 1.3 })) },
    title(t, x, y) { out.push(textPaths(t, x, y, 21, 'start')) },
    note(t, x, y, anchor = 'start') { out.push(textPaths(t, x, y, 14, anchor)) },
  }
  build(api)
  const body = out.join('\n')
  // A NaN coordinate makes every renderer abandon the rest of the path silently — the first
  // version of these diagrams shipped with labels cut in half because nothing checked.
  if (body.includes('NaN')) throw new Error('NaN in path data: the SVG would render truncated')
  const defs = [...glyphDefs.entries()]
    .map(([ch, d]) => `<path id="${glyphId(ch)}" d="${d}"/>`)
    .join('\n')
  return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${width} ${height}" width="${width}" height="${height}">
<defs fill="${INK}">
${defs}
</defs>
<rect width="${width}" height="${height}" fill="#fdfdfd" rx="6"/>
${body}
</svg>\n`
}

// --- 1. the loop iteration --------------------------------------------------
writeFileSync('assets/loop-iteration.svg', scene(1060, 430, (d) => {
  d.title('one iteration', 24, 34)
  // return path along the top
  d.box(430, 50, 230, 62, ['schedule', 'the next iteration'], GREEN, 15)
  d.line(880, 176, 880, 81)
  d.arrow(880, 81, 666, 81, 'phases left')
  d.line(426, 81, 118, 81)
  d.arrow(118, 81, 118, 176)
  // the row
  d.box(30, 180, 178, 80, ['re-anchor', 'from disk'], BLUE, 16)
  d.box(258, 180, 196, 80, ['work the first', 'READY phase'], YELLOW, 16)
  d.box(504, 170, 222, 100, ['loop-verifier grades', 'the mechanical', 'done-when'], VIOLET, 15)
  d.box(776, 170, 222, 100, ['PHASES.md · digest', 'HANDOFF §1'], GREEN, 15)
  d.arrow(210, 220, 254, 220)
  d.arrow(458, 220, 500, 220)
  d.arrow(730, 220, 772, 220, 'PASS')
  // the two ways out, side by side
  d.box(470, 330, 290, 70, ['fix it now,', 'or docket and stop'], RED, 15)
  d.arrow(615, 272, 615, 326, 'FAIL')
  d.box(800, 330, 236, 70, ['final check against', 'the goal contract'], GREY, 14)
  d.arrow(918, 272, 918, 326, 'no phases left')
}))

// --- 2. pattern-migration ---------------------------------------------------
writeFileSync('assets/workflow-pattern-migration.svg', scene(980, 400, (d) => {
  d.title('pattern-migration — the width is discovered, not written down', 24, 38)
  d.box(24, 150, 180, 88, ['mapper', 'strong model', 'returns a plan'], VIOLET, 16)
  d.note('N sites found at runtime', 250, 92)
  d.box(268, 108, 168, 60, ['fixer 1'], YELLOW, 16)
  d.box(268, 190, 168, 60, ['fixer 2'], YELLOW, 16)
  d.box(268, 272, 168, 60, ['fixer N'], YELLOW, 16)
  d.note('each with an exclusive set of files', 268, 356)
  d.arrow(208, 186, 264, 142)
  d.arrow(208, 194, 264, 218)
  d.arrow(208, 202, 264, 296)
  d.box(486, 150, 190, 88, ['verifier', "re-runs the mapper's", 'count command'], BLUE, 15)
  d.arrow(440, 140, 482, 178)
  d.arrow(440, 220, 482, 194)
  d.arrow(440, 300, 482, 210)
  d.diamond(714, 132, 128, 124, ['adversarial', 'check?'], VIOLET, 14)
  d.arrow(680, 194, 710, 194)
  d.box(866, 68, 100, 62, ['one small', 'skeptic'], RED, 14)
  d.box(866, 258, 100, 62, ['report'], GREEN, 15)
  d.arrow(800, 150, 866, 112, 'yes')
  d.arrow(800, 238, 866, 282, 'no')
  d.arrow(916, 132, 916, 254)
}))

// --- 3. sdd-conductor -------------------------------------------------------
writeFileSync('assets/workflow-sdd-conductor.svg', scene(1030, 500, (d) => {
  d.title('sdd-conductor — spec to integrated code, one wave at a time', 24, 36)
  d.box(30, 92, 150, 70, ['your spec'], GREY, 17)
  d.box(215, 80, 244, 96, ['task graph', 'disjoint owns · acyclic', 'mechanical done-when'], VIOLET, 14)
  d.note('validated in code, not by a model', 282, 214)
  d.arrow(184, 127, 211, 127)

  d.note('per task, inside one wave', 500, 62)
  d.box(500, 76, 208, 90, ['isolated copy', 'RED phase first', 'if testable'], YELLOW, 14)
  d.arrow(463, 127, 496, 127)
  d.box(500, 204, 208, 62, ['patch + evidence'], YELLOW, 15)
  d.arrow(604, 170, 604, 200)

  d.box(752, 76, 248, 96, ['adversarial review', '2 rounds', 'own context'], BLUE, 15)
  d.arrow(712, 226, 800, 176)
  d.diamond(766, 214, 216, 116, ['critical', 'survives?'], VIOLET, 14)
  d.arrow(874, 176, 874, 210)

  d.box(752, 396, 250, 70, ['task BLOCKED, docketed', 'the build goes on'], RED, 14)
  d.arrow(874, 334, 874, 392, 'yes')

  d.box(398, 386, 306, 90, ['integrate: patch-apply,', 'sequential, in wave order', 'a conflict blocks the task'], GREEN, 14)
  d.arrow(762, 284, 708, 396, 'no')
  d.box(112, 386, 254, 90, ['project suite', 'runs after', 'every wave'], BLUE, 15)
  d.arrow(394, 431, 370, 431)

  d.line(239, 386, 239, 306)
  d.arrow(239, 306, 239, 180)
  d.note('next wave', 150, 300)
}))

// --- 4. research-campaign ---------------------------------------------------
writeFileSync('assets/workflow-research-campaign.svg', scene(1040, 430, (d) => {
  d.title('research-campaign — the prediction is registered before the work starts', 24, 36)
  d.box(24, 140, 158, 80, ['one work', 'package'], GREY, 16)
  d.box(220, 130, 232, 100, ['pre-register:', 'prediction · metric', 'what would refute it'], VIOLET, 14)
  d.note('no prediction, no run', 236, 258)
  d.box(492, 130, 232, 100, ['execute', 'raw evidence and', 'the metric reading'], YELLOW, 14)
  d.note('the evidence rules,', 512, 258)
  d.note('not the prediction', 512, 280)
  d.box(764, 130, 250, 100, ['independent grader', 'did not do the work', 'judges the comparison'], BLUE, 14)
  d.arrow(186, 180, 216, 180)
  d.arrow(456, 180, 488, 180)
  d.arrow(728, 180, 760, 180)
  d.box(330, 330, 350, 76, ['hand-back memo,', 'assembled in code'], GREEN, 15)
  d.line(889, 234, 889, 368)
  d.arrow(889, 368, 686, 368)
  d.note('confirmed · refuted · inconclusive', 700, 326)
}))

// --- 5. pattern-coverage ----------------------------------------------------
writeFileSync('assets/workflow-pattern-coverage.svg', scene(1040, 450, (d) => {
  d.title('pattern-coverage — the sensor: a number, a worklist, and no silent cap', 24, 36)
  d.box(24, 180, 168, 84, ['a convention', '+ globs'], GREY, 15)
  d.box(232, 96, 178, 60, ['classifier'], YELLOW, 15)
  d.box(232, 190, 178, 60, ['classifier'], YELLOW, 15)
  d.box(232, 284, 178, 60, ['classifier'], YELLOW, 15)
  d.note('one per glob group', 240, 376)
  d.arrow(196, 208, 228, 130)
  d.arrow(196, 218, 228, 220)
  d.arrow(196, 232, 228, 310)
  d.box(456, 180, 190, 84, ['sites that look', 'non-compliant'], RED, 15)
  d.arrow(414, 128, 452, 200)
  d.arrow(414, 220, 452, 220)
  d.arrow(414, 312, 452, 242)
  d.box(692, 96, 150, 60, ['skeptic'], BLUE, 15)
  d.box(692, 190, 150, 60, ['skeptic'], BLUE, 15)
  d.box(692, 284, 150, 60, ['skeptic'], BLUE, 15)
  d.arrow(650, 200, 688, 130)
  d.arrow(650, 220, 688, 220)
  d.arrow(650, 242, 688, 310)
  d.note('one per site, up to the declared cap', 600, 386)
  d.note('past the cap: kept in the worklist, marked unverified, never dropped', 600, 410)
  d.box(880, 180, 140, 84, ['n / total', '+ worklist'], GREEN, 15)
  d.arrow(846, 130, 876, 200)
  d.arrow(846, 220, 876, 220)
  d.arrow(846, 310, 876, 242)
}))

// --- 6. second-opinion ------------------------------------------------------
writeFileSync('assets/workflow-second-opinion.svg', scene(1040, 440, (d) => {
  d.title('second-opinion — three lenses, then a refuter for every finding', 24, 36)
  d.box(24, 190, 150, 80, ['one branch'], GREY, 16)
  d.box(214, 88, 210, 66, ['adversarial'], YELLOW, 15)
  d.box(214, 186, 210, 66, ['contracts and CI'], YELLOW, 15)
  d.box(214, 284, 210, 66, ['codex lens'], VIOLET, 15)
  d.note('a second model family — no CLI, two lenses, and the report says so', 200, 384)
  d.arrow(178, 218, 210, 124)
  d.arrow(178, 226, 210, 220)
  d.arrow(178, 240, 210, 310)
  d.box(470, 186, 190, 80, ['merge and', 'deduplicate'], BLUE, 15)
  d.arrow(428, 124, 466, 206)
  d.arrow(428, 220, 466, 222)
  d.arrow(428, 310, 466, 248)
  d.box(706, 96, 150, 60, ['refuter'], RED, 15)
  d.box(706, 190, 150, 60, ['refuter'], RED, 15)
  d.box(706, 284, 150, 60, ['refuter'], RED, 15)
  d.note('one per surviving finding', 690, 384)
  d.arrow(664, 206, 702, 130)
  d.arrow(664, 226, 702, 220)
  d.arrow(664, 246, 702, 310)
  d.box(880, 186, 140, 80, ['confirmed', 'refuted', 'contested'], GREEN, 14)
  d.arrow(860, 130, 876, 206)
  d.arrow(860, 220, 876, 222)
  d.arrow(860, 310, 876, 248)
}))

// --- 7. the whole flow ------------------------------------------------------
writeFileSync('assets/full-flow.svg', scene(1180, 1560, (d) => {
  d.title('one goal, end to end — and every hook that fires without being asked', 24, 40)

  // rails
  d.note('HOOKS', 40, 92)
  d.note('nothing invokes them', 40, 112)
  d.note('YOUR RULINGS', 946, 92)
  d.note('the loop waits, it does not guess', 946, 112)

  // --- setting it up
  d.box(300, 130, 250, 60, ['brainstorming'], GREY, 16)
  d.note('when the design is open', 300, 210)
  d.box(590, 130, 270, 60, ['spec-first'], GREY, 16)
  d.arrow(554, 160, 586, 160)

  d.box(300, 250, 560, 66, ['/goal-brief writes GOAL.md', 'every guess marked [ASSUMED]'], YELLOW, 15)
  d.arrow(580, 194, 580, 246)
  d.tag(946, 258, 214, ['you resolve every', '[ASSUMED] marker'], '#b2f2bb')

  d.box(300, 356, 560, 60, ['/goal: goal-setup writes PHASES.md'], YELLOW, 15)
  d.arrow(580, 320, 580, 352)
  d.tag(946, 366, 214, ['plan-check: 60 seconds'], '#b2f2bb')

  d.box(300, 456, 560, 60, ['/loop /product-loop  ·  /research-loop'], VIOLET, 15)
  d.arrow(580, 420, 580, 452)

  // --- the night
  d.region(268, 556, 624, 700, 'then it runs without you')
  d.arrow(580, 520, 580, 556)

  d.box(300, 600, 520, 64, ['research phase: research-campaign'], BLUE, 15)
  d.note('the prediction is registered before the spend', 300, 682)
  d.box(300, 700, 520, 64, ['build phase: sdd-conductor'], BLUE, 15)
  d.note('task graph, waves, patch-apply', 300, 782)
  d.box(300, 800, 520, 82, ['convention phase: pattern-coverage,', 'pattern-migration, coverage again'], BLUE, 14)
  d.note('measure, fix, measure again', 300, 900)
  d.box(300, 920, 520, 60, ['loop-verifier grades the done-when'], VIOLET, 15)
  d.box(300, 1010, 520, 64, ['digest · HANDOFF §1 · schedule the next'], GREEN, 15)
  d.arrow(560, 668, 560, 696)
  d.arrow(560, 768, 560, 796)
  d.arrow(560, 886, 560, 916)
  d.arrow(560, 984, 560, 1006)
  d.line(844, 1042, 866, 1042)
  d.line(866, 1042, 866, 632)
  d.arrow(866, 632, 824, 632)
  d.note('next iteration', 300, 1108)
  d.box(300, 1120, 520, 60, ['stop by design when a ruling is missing'], RED, 15)
  d.arrow(560, 1078, 560, 1116)

  d.tag(946, 800, 214, ['an authority edge:', 'a docket entry, and it waits'], '#b2f2bb')
  d.tag(946, 1128, 214, ['the rulings it is waiting for'], '#b2f2bb')

  // --- hooks rail
  d.tag(40, 560, 210, ['session-anchor', 'SessionStart'])
  d.dashed(254, 574, 296, 590)
  d.tag(40, 700, 210, ['strip-ai-attribution · push-guard', 'PreToolUse: Bash'])
  d.dashed(254, 718, 296, 726)
  d.tag(40, 920, 210, ['loop-guard · handoff-freshness', 'Stop'])
  d.dashed(254, 940, 296, 946)
  d.tag(40, 1010, 210, ['loop-state', 'PostToolUse: ScheduleWakeup'])
  d.dashed(254, 1030, 296, 1038)
  d.tag(40, 1120, 210, ['loop-watchdog', 'systemd, outside the session'], '#e9ecef')
  d.dashed(254, 1140, 296, 1146)
  d.note('restarts a loop whose session died,', 40, 1186)
  d.note('never one that is quietly working', 40, 1206)

  // --- after the night
  d.box(300, 1300, 560, 64, ['second-opinion on the branch, then /pr-message'], BLUE, 15)
  d.arrow(580, 1256, 580, 1296)
  d.tag(946, 1310, 214, ['you merge. always.'], '#b2f2bb')

  d.box(300, 1400, 560, 60, ['/morning: the report on your phone'], GREEN, 15)
  d.arrow(580, 1368, 580, 1396)
  d.tag(40, 1400, 210, ['notify-ntfy', 'Notification'])
  d.dashed(254, 1418, 296, 1424)

  // --- the side door
  d.box(300, 1490, 560, 60, ['any hour: you paste an error, root-cause takes over'], RED, 15)
  d.tag(40, 1490, 210, ['firefight-catch', 'UserPromptSubmit'])
  d.dashed(254, 1508, 296, 1514)
  d.note('the 11pm path is a side door, not a phase — it can interrupt any row above', 300, 1478)
}))

// the gate the header promises: a character the font lacks vanishes without a trace
if (missing.size) {
  console.error('characters this font does not carry, they would vanish silently: ' + [...missing].join(' '))
  process.exit(1)
}
console.log('7 svg written')
