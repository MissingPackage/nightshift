#!/usr/bin/env bash
# Loop watchdog — ruling C10 (2026-08-12). The scheduled wake-up lives inside the
# session's process: if the process dies, the wake-up dies with it in silence
# (measured case: ffbce7a6, 300s schedule on 2026-08-04, never arrived, machine
# powered on). This script runs from an EXTERNAL timer (systemd user timer / cron — see
# tools/install-schedules.sh) and revives loops whose wake-up has been overdue too long.
#
# Mechanics: scans $HARNESS_WATCH_ROOTS (default ~/Projects) for
# <project>/.harness/loop-state.json (written by hooks/loop-state.sh). If status=active
# and next_wake is overdue beyond the grace, it resumes the session with
# `claude -p --resume <session_id> "<prompt>"` from the project dir, at most one
# attempt every RETRY_S. Log: ~/.claude/loop-watchdog.log.

exec python3 - "$@" <<'PY'
import json, os, shutil, subprocess, sys, time

ROOTS = [os.path.expanduser(p) for p in
         (os.environ.get("HARNESS_WATCH_ROOTS") or "~/Projects").split(":")]
GRACE_S = int(os.environ.get("HARNESS_WATCH_GRACE") or 120)    # tolerated delay on the wake-up
RETRY_S = int(os.environ.get("HARNESS_WATCH_RETRY") or 1800)   # minimum distance between attempts
# An iteration that WORKS keeps next_wake in the past for its whole duration: the state
# only updates at the next schedule. Without a sign of life the watchdog mistakes
# "it's working" for "it's dead" — happened 5 times out of 5 the night of 2026-08-13,
# with 15-70 minute iterations against a scheduled cadence of 5-30. The signal that
# tells the two cases apart is the session transcript, rewritten every turn.
IDLE_S = int(os.environ.get("HARNESS_WATCH_IDLE") or 900)      # TOTAL silence = session truly stopped
# ...but the transcript alone LIES. A session waiting on a background workflow is silent
# by construction: the workflow writes into its own sidecar, not into the transcript of
# whoever launched it. Measured 2026-08-14 in another project: at 02:03 the watchdog
# revived ae3ad6a9 for "transcript idle for 62 min" while wf_991df002-d1d was writing
# non-stop (01:16, 02:17, 02:29, 02:35, 02:39, 02:43) — four ghost sessions in three
# hours, on the same working tree and the same GPU. Stretching the wake-up doesn't help:
# it moves the instant, it doesn't remove the condition. The sign of life is max(mtime)
# over the WHOLE session sidecar, transcript included.
HEADLESS_IDLE_S = int(os.environ.get("HARNESS_WATCH_HEADLESS_IDLE") or 180)
HEADLESS_RETRY_S = int(os.environ.get("HARNESS_WATCH_HEADLESS_RETRY") or 300)
# A state can be OLD without being late: `git checkout` of a branch carrying a
# loop-state.json with status "active" materializes it with a fresh mtime and an ancient
# next_wake, and the watchdog revives a loop stopped on purpose (observed in another project,
# 2026-08-14 00:01:34: wake-up "overdue by 48 min" taken from a branch, while main said
# stopped). Two sentinels independent of whether the file is tracked in that repo.
STALE_S = int(os.environ.get("HARNESS_WATCH_STALE") or 6 * 3600)   # delay beyond which it is staleness, not lateness
COPY_TOL_S = int(os.environ.get("HARNESS_WATCH_COPY_TOL") or 300)  # mtime-vs-updated_epoch gap that betrays a copy

# Attempt bookkeeping lives HERE, not inside loop-state.json: the hook rewrites that
# file in full at every schedule, zeroing our fields (seen 2026-08-13: 5 attempts
# logged, counter stuck at 1).
ATTEMPTS = os.path.expanduser(
    os.environ.get("HARNESS_WATCH_ATTEMPTS") or "~/.claude/loop-watchdog-attempts.json")
# Overridable for tests: without this a watchdog sensor would write into the real state
# and revive real sessions.
PROJECTS_ROOT = os.path.expanduser(
    os.environ.get("HARNESS_CLAUDE_PROJECTS") or "~/.claude/projects")

def _attempts():
    try:
        return json.load(open(ATTEMPTS))
    except Exception:
        return {}

def _rec(pdir):
    r = _attempts().get(pdir, 0)
    return {"epoch": int(r)} if isinstance(r, (int, float)) else dict(r or {})

def last_attempt(pdir):
    return int(_rec(pdir).get("epoch") or 0)

def last_unit(pdir):
    return _rec(pdir).get("unit") or ""

def last_sid(pdir):
    return _rec(pdir).get("sid") or ""

def _save(d):
    try:
        tmp = ATTEMPTS + ".tmp"
        json.dump(d, open(tmp, "w"))
        os.replace(tmp, ATTEMPTS)
    except Exception:
        pass

def mark_attempt(pdir, when, unit="", sid=""):
    d = _attempts()
    r = _rec(pdir)            # preserve the warning bookkeeping
    r.update({"epoch": int(when), "unit": unit, "sid": sid})
    d[pdir] = r
    _save(d)

def note_once(pdir, key, msg, every=21600):
    """Log a persistent SKIP without flooding the file: the watchdog runs every 2-3
    minutes, and a sick state stays sick — repeating it 480 times a day buries the
    lines that matter."""
    r = _rec(pdir)
    if r.get("warn_key") == key and now - int(r.get("warn_epoch") or 0) < every:
        return
    r["warn_key"], r["warn_epoch"] = key, int(now)
    d = _attempts()
    d[pdir] = r
    _save(d)
    log(msg)

def unit_active(unit):
    if not unit or not shutil.which("systemctl"):
        return False
    try:
        r = subprocess.run(["systemctl", "--user", "is-active", unit],
                           capture_output=True, text=True, timeout=10)
        return r.stdout.strip() == "active"
    except Exception:
        return False

def spawn_resume(pdir, sid, message):
    """Revive the session in a process that SURVIVES this script.

    The defect this function exists to fix (2026-08-13): the watchdog runs as a systemd
    oneshot, and when the unit ends systemd tears down the cgroup killing every child —
    `start_new_session=True` protects from the signal to the process group, NOT from the
    cgroup. Result: 5 revivals logged, zero executed, no output. The idiomatic solution
    is a transient unit of its own (systemd-run); under cron, Popen is enough.
    """
    argv = ["claude", "-p", "--resume", sid, message]
    if shutil.which("systemd-run"):
        unit = "harness-resume-%s-%d" % (os.path.basename(pdir)[:24], int(time.time()))
        cmd = ["systemd-run", "--user", "--collect", "--quiet",
               "--unit", unit, "--working-directory", pdir, "--"] + argv
        try:
            r = subprocess.run(cmd, capture_output=True, text=True, timeout=30)
            if r.returncode == 0:
                log("  → started transient unit %s (survives the watchdog)" % unit)
                return unit
            log("  → systemd-run failed (%s): %s" % (r.returncode, (r.stderr or "").strip()[:160]))
        except Exception as e:
            log("  → systemd-run unusable: %s" % e)
    try:
        with open(LOG, "a") as lf:
            subprocess.Popen(argv, cwd=pdir, stdout=lf, stderr=lf, start_new_session=True)
        log("  → started with Popen (outside systemd: valid under cron)")
        return "popen"
    except FileNotFoundError:
        log("  → ERROR: claude CLI not found in PATH")
    except Exception as e:
        log("  → ERROR on startup: %s" % e)
    return ""

def _session_home(project_dir, session_id):
    enc = project_dir.replace("/", "-")
    return os.path.join(PROJECTS_ROOT, enc, session_id)

def transcript_mtime(project_dir, session_id):
    """mtime of the session transcript, or None if we can't find it."""
    try:
        return os.path.getmtime(_session_home(project_dir, session_id) + ".jsonl")
    except Exception:
        return None

def sidecar_mtime(project_dir, session_id, cap=20000):
    """Most recent mtime under <sid>/ — subagents/, subagents/workflows/<runId>/,
    tool-results/. The work the session delegated shows up here: it is alive exactly
    while these files grow, and the caller's transcript stays quiet meanwhile."""
    best = 0.0
    seen = 0
    stack = [_session_home(project_dir, session_id)]
    while stack:
        try:
            with os.scandir(stack.pop()) as it:
                for e in it:
                    seen += 1
                    if seen > cap:
                        return best  # defense against pathological sidecars: better partial than slow
                    try:
                        if e.is_dir(follow_symlinks=False):
                            stack.append(e.path)
                        else:
                            m = e.stat(follow_symlinks=False).st_mtime
                            if m > best:
                                best = m
                    except OSError:
                        continue
        except OSError:
            continue
    return best
LOG = os.path.expanduser(os.environ.get("HARNESS_WATCH_LOG") or "~/.claude/loop-watchdog.log")
DRY = "--dry-run" in sys.argv

def log(msg):
    line = "%s %s" % (time.strftime("%Y-%m-%dT%H:%M:%S"), msg)
    print(line)
    try:
        os.makedirs(os.path.dirname(LOG), exist_ok=True)
        with open(LOG, "a") as f:
            f.write(line + "\n")
    except Exception:
        pass

now = time.time()
found = 0
for root in ROOTS:
    if not os.path.isdir(root):
        continue
    for proj in sorted(os.listdir(root)):
        pdir = os.path.join(root, proj)
        sp = os.path.join(pdir, ".harness", "loop-state.json")
        if not os.path.isfile(sp):
            continue
        try:
            state = json.load(open(sp))
        except Exception:
            continue
        if state.get("status") != "active":
            continue
        wake = int(state.get("next_wake_epoch") or 0)
        if not wake or wake + GRACE_S > now:
            continue  # not yet overdue (or malformed state)

        # status=="active" does not prove the loop is alive: it only proves SOMEONE
        # wrote that file. `git checkout` of a branch carrying it is "someone".
        upd = int(state.get("updated_epoch") or 0)
        try:
            fmtime = os.path.getmtime(sp)
        except OSError:
            fmtime = 0
        if upd and fmtime and fmtime - upd > COPY_TOL_S:
            note_once(pdir, "copy", "SKIP %s: loop-state.json appeared on disk %d min after "
                      "being written (checkout/copy of someone else's state, not a live "
                      "schedule) — not reviving" % (proj, int((fmtime - upd) / 60)))
            continue
        if now - wake > STALE_S:
            note_once(pdir, "stale", "SKIP %s: wake-up overdue by %d h — that's staleness, "
                      "not lateness: no healthy loop misses ~%d polls in a row"
                      % (proj, int((now - wake) / 3600), int((now - wake) / 180)))
            continue

        sid = state.get("session_id") or ""
        if not sid:
            log("SKIP %s: loop overdue but session_id missing" % proj)
            continue
        tm = transcript_mtime(pdir, sid)
        if tm is None:
            note_once(pdir, "notranscript",
                      "SKIP %s: transcript of session %s... not found, not reviving blind"
                      % (proj, sid[:8]))
            continue
        sc = sidecar_mtime(pdir, sid)
        act = max(tm, sc)
        act_src = "transcript" if tm >= sc else "workflow/subagent"

        # A revival of OURS still IN PROGRESS: the session is working in that unit.
        prev_unit = last_unit(pdir)
        if unit_active(prev_unit):
            if "--verbose" in sys.argv:
                log("ALIVE %s: revival %s still in progress" % (proj, prev_unit))
            continue

        # If the last push was OURS and its unit has ended, the session is dead by
        # construction: `claude -p` executes one turn and EXITS, so the ScheduleWakeup
        # it called at the end is registered in a process that no longer exists and will
        # never fire (proven 2026-08-13: 14m42s unit, real work, exit, then stall). In
        # that case don't wait for transcript silence: relaunch as soon as the wake-up
        # is due — the watchdog IS the scheduler of a headless loop.
        # ...and it holds ONLY if that unit was reviving THIS session. Tied to prev_unit
        # alone, headless_dead stayed true forever on a directory already pushed once,
        # and with it the liveness check was skipped: three "RESUME ... transcript idle
        # for 0 min" lines in the 2026-08-13 log are pushes into sessions that were
        # writing at that very moment.
        headless_dead = bool(prev_unit) and prev_unit != "popen" and last_sid(pdir) == sid

        # The liveness check is NEVER skipped: the cost of waiting one round is a bit of
        # latency, the cost of being wrong is a duplicated session on the same working
        # tree. For a dead headless session a few minutes of silence suffice (`claude -p`
        # exits and from that instant nobody writes anymore); for a session that isn't
        # ours, the long silence is required.
        idle_needed = HEADLESS_IDLE_S if headless_dead else IDLE_S
        if now - act < idle_needed:
            if "--verbose" in sys.argv:
                log("ALIVE %s: wake-up overdue but %s written %d min ago — it is working"
                    % (proj, act_src, int((now - act) / 60)))
            continue
        last_try = last_attempt(pdir)
        floor = HEADLESS_RETRY_S if headless_dead else RETRY_S
        if last_try and now - last_try < floor:
            continue  # don't hammer: even the headless loop has a minimum distance
        found += 1
        overdue_min = int((now - wake) / 60)
        prompt = state.get("prompt") or "continue the loop"
        log("RESUME %s: wake-up overdue by %d min AND no activity for %d min "
            "(transcript+sidecar, session %s...)"
            % (proj, overdue_min, int((now - act) / 60), sid[:8]))
        if not DRY:
            msg = ("[loop-watchdog] Scheduled wake-up missed (%d min ago). %s"
                   % (overdue_min, prompt))
            unit = spawn_resume(pdir, sid, msg)
            mark_attempt(pdir, now, unit, sid)

if not found:
    log("ok: no overdue loops") if "--verbose" in sys.argv else None
PY
