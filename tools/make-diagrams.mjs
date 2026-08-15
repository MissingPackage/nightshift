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
function textPaths(s, cx, cy, size, anchor = 'middle') {
  for (const ch of s) if (ch !== ' ' && font.charToGlyph(ch).index === 0) missing.add(ch)
  const w = textWidth(s, size)
  const x = anchor === 'middle' ? cx - w / 2 : anchor === 'end' ? cx - w : cx
  return `<path d="${r1(font.getPath(s, x, cy, size).toPathData(1))}" fill="${INK}"/>`
}
function label(lines, cx, cy, size) {
  const lh = size * 1.22
  const top = cy - ((lines.length - 1) * lh) / 2
  return lines.map((l, i) => textPaths(l, cx, top + i * lh + size * 0.34, size)).join('\n')
}

// --- scene ------------------------------------------------------------------
function scene(width, height, build) {
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
    line(x1, y1, x2, y2) { draw(rc.line(x1, y1, x2, y2, { stroke: INK, strokeWidth: 1.5, roughness: 1.3 })) },
    title(t, x, y) { out.push(textPaths(t, x, y, 21, 'start')) },
    note(t, x, y, anchor = 'start') { out.push(textPaths(t, x, y, 14, anchor)) },
  }
  build(api)
  const body = out.join('\n')
  // A NaN coordinate makes every renderer abandon the rest of the path silently — the first
  // version of these diagrams shipped with labels cut in half because nothing checked.
  if (body.includes('NaN')) throw new Error('NaN in path data: the SVG would render truncated')
  return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${width} ${height}" width="${width}" height="${height}">
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

console.log('3 svg written')
