#!/usr/bin/env node
// nightshift-hud.mjs — custom Claude Code statusline (replaces the OMC HUD wrapper).
// Reads the statusline JSON on stdin (schema: code.claude.com/docs/en/statusline.md).
// ADAPTIVE height: 1 line on a wide terminal, 2 lines when medium, stacked aligned bars when
// narrow (needs COLUMNS in env, CC v2.1.153+). Word labels only (no obscure glyphs). Every
// field optional → degrades. Self-contained: Node builtins + git only, NO OMC/plugin dependency
// → fully portable on clone.
//
// Install: `./install.sh` copies this to ~/.claude/hud/.
// Register in ~/.claude/settings.json (manual step §C.1):
//   "statusLine": { "type": "command", "command": "node ~/.claude/hud/nightshift-hud.mjs" }

import { execSync } from "node:child_process";
import { readFileSync, writeFileSync, statSync, openSync, readSync, closeSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

// ---------- ANSI ----------
const E = (c) => `\x1b[${c}m`;
const R = E(0), DIM = E(2);
const CYAN = E(36), GREEN = E(32), YELLOW = E(33), RED = E(31), BLUE = E("38;5;39"),
      MAGENTA = E(35), GRAY = E("38;5;245");
const rgb = (r, g, b) => `\x1b[38;2;${r};${g};${b}m`;
const paint = (s, c) => `${c}${s}${R}`;
const strip = (s) => s.replace(/\x1b\[[0-9;]*m/g, "");
const SEP = `${DIM}  ·  ${R}`, SEPW = 5;
const vis = (s) => strip(s).length;
const COLS = parseInt(process.env.COLUMNS || "0", 10) || 0;

// ---------- input ----------
let d = {};
try { d = JSON.parse(readFileSync(0, "utf8")); } catch { /* no/blank stdin */ }
const cwd = d.workspace?.current_dir || d.cwd || process.cwd();
const sid = d.session_id || "nosess";

// ---------- git (cached 5s per session) ----------
function gitInfo() {
  const cacheFile = join(tmpdir(), `nightshift-hud-git-${sid}`);
  try {
    const c = JSON.parse(readFileSync(cacheFile, "utf8"));
    if (c.cwd === cwd && Date.now() - c.ts < 5000) return c;
  } catch { /* miss */ }
  const g = (a) => {
    try { return execSync(`git ${a}`, { cwd, stdio: ["ignore", "pipe", "ignore"], encoding: "utf8" }).trim(); }
    catch { return ""; }
  };
  let inRepo = false, branch = "", ahead = 0, dirty = 0;
  if (g("rev-parse --is-inside-work-tree") === "true") {
    inRepo = true;
    branch = g("branch --show-current") || g("rev-parse --short HEAD");
    let a = g("rev-list --count @{upstream}..HEAD");
    if (!a && branch) a = g(`rev-list --count origin/${branch}..HEAD`);
    ahead = parseInt(a, 10) || 0;
    const p = g("status --porcelain");
    dirty = p ? p.split("\n").filter(Boolean).length : 0;
  }
  const info = { cwd, ts: Date.now(), inRepo, branch, ahead, dirty };
  try { writeFileSync(cacheFile, JSON.stringify(info)); } catch { /* non-fatal */ }
  return info;
}

// ---------- transcript activity (incremental: reads only the appended delta) ----------
function activity(tpath) {
  if (!tpath) return null;
  const cacheFile = join(tmpdir(), `nightshift-hud-tx-${sid}`);
  let c = { path: tpath, offset: 0, partial: "", tools: 0, skills: 0, agents: 0 };
  try { const p = JSON.parse(readFileSync(cacheFile, "utf8")); if (p.path === tpath) c = p; } catch { /* miss */ }
  let size = 0;
  try { size = statSync(tpath).size; } catch { return null; }
  if (size < c.offset) c = { path: tpath, offset: 0, partial: "", tools: 0, skills: 0, agents: 0 };
  if (size > c.offset) {
    try {
      const fd = openSync(tpath, "r");
      const buf = Buffer.alloc(size - c.offset);
      readSync(fd, buf, 0, buf.length, c.offset);
      closeSync(fd);
      const lines = (c.partial + buf.toString("utf8")).split("\n");
      c.partial = lines.pop();
      for (const line of lines) {
        if (!line.trim()) continue;
        let o; try { o = JSON.parse(line); } catch { continue; }
        if (o.isSidechain) continue;
        const content = o.message?.content;
        if (!Array.isArray(content)) continue;
        for (const b of content) {
          if (b?.type !== "tool_use") continue;
          c.tools++;
          if (b.name === "Skill") c.skills++;
          else if (b.name === "Agent" || b.name === "Task") c.agents++;
        }
      }
      c.offset = size;
      writeFileSync(cacheFile, JSON.stringify(c));
    } catch { /* ignore */ }
  }
  return { tools: c.tools, skills: c.skills, agents: c.agents };
}

// ---------- helpers ----------
const clamp = (p) => Math.max(0, Math.min(100, Math.round(p || 0)));
const grade = (p) => (p >= 85 ? RED : p >= 60 ? YELLOW : GREEN);
function gbar(pct, lo, hi, w) {
  const p = clamp(pct), f = Math.round((p / 100) * w);
  let out = `${DIM}[${R}`;
  for (let i = 0; i < w; i++) {
    if (i < f) {
      const t = w > 1 ? i / (w - 1) : 0;
      out += rgb(Math.round(lo[0] + (hi[0] - lo[0]) * t), Math.round(lo[1] + (hi[1] - lo[1]) * t),
                 Math.round(lo[2] + (hi[2] - lo[2]) * t)) + "█";
    } else out += `${DIM}░`;
  }
  return out + `${DIM}]${R}`;
}
function remain(ts) {
  if (!ts) return "";
  const s = ts - Math.floor(Date.now() / 1000);
  if (s <= 0) return "now";
  const D = 86400, H = 3600, M = 60;
  if (s >= D) return `${Math.floor(s / D)}d${Math.floor((s % D) / H)}h`;
  if (s >= H) return `${Math.floor(s / H)}h${String(Math.floor((s % H) / M)).padStart(2, "0")}`;
  return `${Math.floor(s / M)}m`;
}
const DOW = ["sun", "mon", "tue", "wed", "thu", "fri", "sat"];
function resetDay(ts) {
  if (!ts) return "";
  const dt = new Date(ts * 1000);
  return `${DOW[dt.getDay()]} ${String(dt.getHours()).padStart(2, "0")}:${String(dt.getMinutes()).padStart(2, "0")}`;
}
function dur(ms) {
  if (!ms) return "0m";
  const s = Math.floor(ms / 1000), H = 3600, M = 60;
  if (s >= H) return `${Math.floor(s / H)}h${String(Math.floor((s % H) / M)).padStart(2, "0")}m`;
  return `${Math.floor(s / M)}m`;
}
const fmtTok = (n) => (n >= 1e6 ? `${(n / 1e6).toFixed(1).replace(/\.0$/, "")}M` : `${Math.max(1, Math.round(n / 1000))}k`);
function joinG(groups) { return groups.filter(Boolean).map((x) => x.s).join(SEP); }
// join, dropping lowest-priority (highest prio) groups until it fits COLUMNS
function fitG(groups) {
  let g = groups.filter(Boolean);
  const w = () => g.reduce((a, x) => a + vis(x.s), 0) + SEPW * Math.max(0, g.length - 1);
  while (COLS && g.length > 1 && w() > COLS) {
    let idx = 0, worst = -Infinity;
    g.forEach((x, i) => { if (x.prio > worst) { worst = x.prio; idx = i; } });
    g.splice(idx, 1);
  }
  return g.map((x) => x.s).join(SEP);
}

// ---------- data ----------
const g = gitInfo();
const act = activity(d.transcript_path);
const model = (d.model?.display_name || d.model?.id || "?").replace(/\s*\((?:1m|1 million)[^)]*\)/i, "").trim();
const is1m = /\[1m\]|1m/i.test(d.model?.id || "") || /1m/i.test(d.model?.display_name || "");
const effort = d.effort?.level || "", thinking = !!d.thinking?.enabled;
const cw = d.context_window || {}, ctx = cw.used_percentage;
const five = d.rate_limits?.five_hour, week = d.rate_limits?.seven_day;
const sessMs = d.cost?.total_duration_ms, usd = d.cost?.total_cost_usd;
const addl = d.cost?.total_lines_added, reml = d.cost?.total_lines_removed;
const RAMP = { ctx: [[90, 200, 255], [255, 70, 70]], h5: [[120, 230, 140], [255, 70, 70]], wk: [[170, 140, 255], [255, 150, 60]] };

// ---------- identity groups ----------
const identity = [];
if (g.inRepo && g.branch) {
  let s = paint(g.branch, CYAN);
  if (g.ahead) s += ` ${paint("↑" + g.ahead, GREEN)}`;
  if (g.dirty) s += ` ${paint("*" + g.dirty, YELLOW)}`;
  identity.push({ s, prio: 1 });
}
let m = paint(model, BLUE);
if (is1m) m += paint(" 1M", GRAY);
identity.push({ s: m, prio: 0 });
if (effort) identity.push({ s: paint(effort, MAGENTA), prio: 2 });
if (thinking) identity.push({ s: paint("thinking", GRAY), prio: 3 });

// ---------- session groups ----------
const session = [];
if (sessMs) session.push({ s: `${GRAY}sess ${dur(sessMs)}${R}`, prio: 1 });
if (typeof usd === "number") session.push({ s: paint(`$${usd.toFixed(2)}`, GREEN), prio: 2 });
if (typeof addl === "number" || typeof reml === "number")
  session.push({ s: `${paint("+" + (addl || 0), GREEN)}${paint("/-" + (reml || 0), RED)}`, prio: 3 });
if (act && act.tools) {
  let s = `${GRAY}🔧${act.tools}${R}`;
  if (act.skills) s += ` ${GRAY}· ${act.skills} skill${R}`;
  if (act.agents) s += ` ${GRAY}· ${act.agents} agent${R}`;
  session.push({ s, prio: 4 });
}

// ---------- bar specs ----------
const bars = [];
if (ctx !== undefined && ctx !== null) {
  let tail = cw.total_input_tokens ? `${GRAY}${fmtTok(cw.total_input_tokens)}${cw.context_window_size ? "/" + fmtTok(cw.context_window_size) : ""}${R}` : "";
  if (d.exceeds_200k_tokens) tail += `${tail ? " " : ""}${paint("200k+", RED)}`;
  bars.push({ label: "ctx", pct: ctx, ramp: RAMP.ctx, tail });
}
if (five) bars.push({ label: "5h", pct: five.used_percentage, ramp: RAMP.h5, tail: remain(five.resets_at) ? `${GRAY}reset ${remain(five.resets_at)}${R}` : "" });
if (week) bars.push({ label: "wk", pct: week.used_percentage, ramp: RAMP.wk, tail: resetDay(week.resets_at) ? `${GRAY}reset ${resetDay(week.resets_at)}${R}` : "" });

function barStr(b, w, aligned) {
  const p = clamp(b.pct);
  const lab = `${GRAY}${aligned ? b.label.padEnd(3) : b.label}${R}`;
  const pct = paint((aligned ? String(p).padStart(3) : String(p)) + "%", grade(p));
  return `${lab} ${gbar(p, b.ramp[0], b.ramp[1], w)} ${pct}${b.tail ? `  ${b.tail}` : ""}`;
}

// ---------- adaptive layout: 1 line → 2 lines → stacked ----------
const idFull = joinG(identity), sessFull = joinG(session);
const oneLine = [idFull, bars.map((b) => barStr(b, 8, false)).join(SEP), sessFull].filter(Boolean).join(SEP);
const twoTop = [idFull, sessFull].filter(Boolean).join(SEP);
const twoBars = bars.map((b) => barStr(b, 12, false)).join(SEP);

let lines;
if (COLS && vis(oneLine) <= COLS) {
  lines = [oneLine];
} else if (COLS && vis(twoTop) <= COLS && vis(twoBars) <= COLS) {
  lines = [twoTop, twoBars];
} else {
  const bw = COLS && COLS < 90 ? 12 : 16;
  lines = [fitG(identity), ...bars.map((b) => barStr(b, bw, true)), fitG(session)].filter(Boolean);
}
process.stdout.write(lines.join("\n"));
