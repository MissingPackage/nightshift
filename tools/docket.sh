#!/usr/bin/env bash
# docket.sh — helper for goal dockets (ROADMAP R4, ruling D7).
# Canonical format (D5a): entry = `## <ID> · <title>`; closed by a `**RULING:** <text>` line;
# open while the ruling is the `_` placeholder. The same format session-anchor counts.
#
# Usage:
#   tools/docket.sh list                  # every entry of every goal, age and status
#   tools/docket.sh list --open           # only the open ones
#   tools/docket.sh rule <ID> "<text>"    # fills <ID>'s ruling (refuses if already ruled)
#
# Rulings remain the user's: `rule` is the pen, not the judge — it stamps text and date
# in the canonical format so monitor and session-anchor never disambiguate.

set -u
ROOT="${CLAUDE_PROJECT_DIR:-$(pwd)}"
GOALS="$ROOT/.harness/goals"

usage() { grep '^#   ' "$0" | sed 's/^#   //'; exit 2; }
[ $# -ge 1 ] || usage

py() { python3 - "$@"; }

case "$1" in
list)
  ONLY_OPEN="${2:-}"
  py "$GOALS" "$ONLY_OPEN" <<'PY'
import pathlib, re, sys
from datetime import date

goals = pathlib.Path(sys.argv[1])
only_open = sys.argv[2] == "--open"
today = date.today()
found = 0
for docket in sorted(goals.glob("*/docket.md")):
    goal = docket.parent.name
    text = docket.read_text(encoding="utf-8", errors="replace")
    blocks = re.split(r"(?m)^## ", text)[1:]
    for b in blocks:
        header = b.splitlines()[0].strip()
        entry_id = header.split("·")[0].strip() if "·" in header else header.split()[0]
        m = re.search(r"(?m)^\*\*RULING[^:]*:\*\*\s*(.*)$", b)
        val = (m.group(1).strip() if m else "")
        is_open = (not val) or val.startswith("_")
        if only_open and not is_open:
            continue
        d = re.search(r"20\d\d-\d\d-\d\d", b)
        age = f"{(today - date.fromisoformat(d.group(0))).days}d" if d else "—"
        status = "OPEN " if is_open else "ruled"
        print(f"{status} {goal:<22} {entry_id:<6} age {age:<5} {header[:70]}")
        found += 1
print(f"-- {found} entry")
PY
  ;;
rule)
  [ $# -eq 3 ] || usage
  ID="$2" TEXT="$3"
  py "$GOALS" "$ID" "$TEXT" <<'PY'
import pathlib, re, sys
from datetime import date

goals, entry_id, text_arg = pathlib.Path(sys.argv[1]), sys.argv[2], sys.argv[3]
hits = []
for docket in sorted(goals.glob("*/docket.md")):
    file_text = docket.read_text(encoding="utf-8")
    pat = re.compile(r"(?ms)^(## " + re.escape(entry_id) + r"\b.*?)(?=^## |\Z)")
    m = pat.search(file_text)
    if m:
        hits.append((docket, m, file_text))  # text captured PER HIT: m's offsets are
        # only valid inside the matched file (corruption bug found by verifier it4)
if not hits:
    sys.exit(f"docket.sh: entry '{entry_id}' not found in {goals}")
if len(hits) > 1:
    sys.exit(f"docket.sh: '{entry_id}' ambiguous ({', '.join(str(d) for d, _, _ in hits)})")
docket, m, text = hits[0]
block = m.group(1)
rm = re.search(r"(?m)^(\*\*RULING[^:]*:\*\*)\s*(.*)$", block)
if not rm:
    sys.exit(f"docket.sh: '{entry_id}' has no **RULING:** line — non-canonical format")
current = rm.group(2).strip()
if current and not current.startswith("_"):
    sys.exit(f"docket.sh: '{entry_id}' already ruled: {current[:80]}")
stamp = f"{rm.group(1)} {text_arg} ({date.today().isoformat()}, via docket-cli)"
new_block = block[:rm.start()] + stamp + block[rm.end():]
docket.write_text(text[:m.start()] + new_block + text[m.end():], encoding="utf-8")
print(f"ruled {entry_id} in {docket}")
PY
  ;;
*) usage ;;
esac
