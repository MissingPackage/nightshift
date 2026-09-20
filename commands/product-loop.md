---
description: One iteration of an autonomous product-development loop (use as `/loop /product-loop`)
---

Continue the autonomous product loop for this project. Follow the loop-iteration skill.

Standing rules for every iteration:
- **The objective is a user path that works end to end** (the map head line). Take the biggest
  gap on that path; the next lever comes from the map, never invented. If the map names nothing,
  stop and ask in one line.
- **Protected paths:** deploy/infra manifests, auth/consent flows, migrations and anything owned
  by someone else are read-only unless the map explicitly grants them.
- **Branch and merge:** a feature branch per slice, PR-ready is the target; merging to a shared
  branch is one of the four kinds and waits for the user.
- **Fix what you meet on the path.** No fences, no debt comments, no residue lists.
- **The boundary is the PR:** full suite, conventions and docs per project CLAUDE.md, completion
  report (skill done) in the PR description. Inside the iteration: unit tests of the slice, a
  smoke of the path, nothing longer.

Each iteration: re-anchor from the map → biggest gap → implement → smoke the path → redraw the
map, append to `.harness/tried.md` → three-line digest → schedule or stop.

Morning: the final digest of a night lists the slices completed with their branches or PRs and
the decisions (four kinds only) waiting for the user.

$ARGUMENTS
