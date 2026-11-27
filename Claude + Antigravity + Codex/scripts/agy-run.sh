#!/usr/bin/env bash
# agy-run.sh: run ONE task on ONE Antigravity (agy) model and print a short report.
# Normally called by scripts/relay.sh. Claude may also run it directly (run_in_background: true).
# No model chain: this script never switches model. relay.sh owns the fallback logic.
#
# Usage:
#   scripts/agy-run.sh --model <alias[-low|-medium|-high|-xhigh]|full-id> --task <slug> --owns "<comma list|none>" \
#       --brief <file> [--worktree <path>] [--partial] [--no-fallback]
#   scripts/agy-run.sh --status
# Models (only these four families):
#   hydrogen -> gemini-4-hydrogen-<effort>   default builder, alias means high; xhigh exists
#   neon     -> gemini-4-neon-<effort>       hard tasks, alias means high; xhigh only for the hardest
#   sonnet   -> claude-sonnet-5-5-<effort>   FIXES ONLY (never build, never review). Alias means medium
#   opus     -> claude-opus-5-5-<effort>     FIXES ONLY (never build, never review). Alias means medium
# No Flash, Carbon or Argon. Scouting is Codex Luna. A design task never runs here (the script refuses a
# brief whose first line is the bare word "design"). --no-fallback is accepted and does nothing (there is
# no chain). --partial adds "a previous model stopped partway" to the brief.
# The brief file is body-only. The script adds task:, owns:, "Read AGENTS.md first and follow it.", the
# read-only line (owns none) and the no-shell line.
#
# Exit codes:
#   0 success (report printed)
#   1 other error: login, crash, timeout, unknown flag (last 20 log lines printed)
#   2 agy missing, bad arguments, refused, or the model id is not in `agy models`
#   3 drained. First line "drained: <model-id>, no fallback", then "pool: <marker name>" (when the marker
#     is skipped, agy was not run), "until: <UTC ISO>", "error: <line>". Owned files may be partly edited
#   4 suspected concurrency limit: first line "concurrency: <quoted text>". No marker
#
# Markers: .claude/agy-quota/<name>, lines: until=<UTC ISO>, reason=<line>, known=1|0.
# <name> is `gemini-pool` (every gemini-* model shares one quota) or `claude-pool` (agy Sonnet and Opus).
# A "not available to ..." error marks only that model id (the model is not on the plan, the pool is fine).
# until = the reset time parsed from the output (known=1), else now + 6 hours (known=0, a guess).
# Active while now < until. With --status: prints active markers and "agy: N pools limited". Always exit 0.
#
# Limit rules. rc != 0: any QUOTA_RE match in the log = limit hit. rc == 0: a limit only when a short log
# (under 40 lines) has a matching line that also contains "error" AND the owned files did not gain changed
# lines during the run (read-only tasks: just the error match).
# Concurrency: CONC_RE matches in the log AND (rc != 0, or a short log with no gain in owned changed lines).
# The wording of agy's concurrency and quota errors is UNVERIFIED: verify on first real run.
# Timeout: RUN_TIMEOUT seconds (default 1800, 0 = off; env AGY_RUN_TIMEOUT overrides) when `timeout` or
# `gtimeout` exists.
#
# agy -p --mode accept-edits allows file edits but DENIES shell commands. The model cannot run tests or
# linters. The brief tells it so. relay.sh runs the checks.
# NEVER add --dangerously-skip-permissions (auto mode blocks it). If a run stalls on a permission check,
# stop and report. Do not look for a way around it.
set -euo pipefail

RUN_DIR=".agc"                      # run folder in the project (briefs, logs, status, summaries)

# ---- Flags (confirmed on the user's machine; `agy` has no -m flag) ----
AGY_BIN="agy"
FLAG_PROMPT="-p"
FLAG_MODEL="--model"
MODE_ARGS=(--mode accept-edits --print-timeout 0)

# ---- Tunables ----
LIMIT_DEFAULT=21600                 # seconds a drained pool stays skipped when no reset time is found (6h, a guess)
DAY=86400
RUN_TIMEOUT="${AGY_RUN_TIMEOUT:-1800}"   # seconds per run; 0 = off. Needs `timeout` (or `gtimeout` on macOS)
QUOTA_RE='rate.?limit|429|quota|usage limit|limit reached|exhausted|too many requests|try again later|FreeUsageLimit|resource_exhausted|not available to'
CONC_RE='concurrent|too many sessions|another session|already running|locked'

# ================= ALIASES (edit together with CLAUDE.md) =================
alias_family() {   # $1 alias word (no suffix); prints the family or returns 1
  case "$1" in hydrogen|neon|sonnet|opus) echo "$1" ;; *) return 1 ;; esac
}
family_id() {      # $1 family  $2 effort
  case "$1" in
    hydrogen) echo "gemini-4-hydrogen-$2" ;;
    neon)     echo "gemini-4-neon-$2" ;;
    sonnet)   echo "claude-sonnet-5-5-$2" ;;
    opus)     echo "claude-opus-5-5-$2" ;;
  esac
}
# ======================= end of the marked block =======================

die() { echo "$*" >&2; exit "${2:-2}"; }

ROOT="$PWD"                         # markers always live here, even in worktree mode
QDIR="$ROOT/.claude/agy-quota"
LOGDIR="$ROOT/$RUN_DIR/logs"

# ---- Time helpers (GNU date, with a macOS/BSD fallback) ----
to_epoch() { date -u -d "$1" +%s 2>/dev/null || date -j -u -f "%Y-%m-%dT%H:%M:%SZ" "$1" +%s 2>/dev/null || true; }
to_iso()   { date -u -d "@$1" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -r "$1" +%Y-%m-%dT%H:%M:%SZ; }
fmt_remaining() {
  local s=$1 d h m out=""
  [ "$s" -lt 0 ] && s=0
  d=$((s / 86400)); h=$(((s % 86400) / 3600)); m=$(((s % 3600) / 60))
  [ "$d" -gt 0 ] && out="${d}d "
  { [ "$d" -gt 0 ] || [ "$h" -gt 0 ]; } && out="$out${h}h "
  echo "$out${m}m"
}
marker_until() {    # prints the until time (UTC ISO) if the marker is active, else nothing
  local f="$QDIR/$1" u e
  [ -f "$f" ] || return 0
  u=$(sed -n 's/^until=//p' "$f" | head -n 1 | tr -d '\r')
  e=$(to_epoch "$u")
  [[ "$e" =~ ^[0-9]+$ ]] || return 0   # unparseable marker: ignored
  [ "$(date +%s)" -lt "$e" ] && echo "$u"
  return 0
}

# Pools: ALL Gemini models share ONE quota (marker `gemini-pool`). agy Sonnet and Opus share the
# Claude pool (marker `claude-pool`). Anything else gets its own per-id marker.
pool_of() { case "$1" in gemini-*) echo gemini-pool ;; claude-*) echo claude-pool ;; esac; }
drain_until() {     # $1 model id: prints "<until> <marker name>" if the model OR its pool has an active marker
  local u p
  u=$(marker_until "$1")
  if [ -n "$u" ]; then echo "$u $1"; return 0; fi
  p=$(pool_of "$1")
  if [ -n "$p" ]; then u=$(marker_until "$p"); [ -n "$u" ] && echo "$u $p"; fi
  return 0
}

if [ "${1:-}" = "--status" ]; then
  mkdir -p "$QDIR"
  n=0; now=$(date +%s)
  for f in "$QDIR"/*; do
    [ -f "$f" ] || continue
    id=${f##*/}
    case "$id" in .tmp.*) continue ;; esac
    u=$(marker_until "$id")
    [ -n "$u" ] || continue
    n=$((n + 1))
    why=$(sed -n 's/^reason=//p' "$f" | head -n 1 | tr -d '\r')
    echo "  $id limited until $u (remaining $(fmt_remaining $(( $(to_epoch "$u") - now )))). reason: ${why:-none}"
  done
  echo "agy: $n pools limited"
  exit 0
fi

# ---- Arguments ----
MODEL="" TASK="" OWNS="" BRIEF="" WORKTREE="" OWNS_SET=0 PARTIAL=0
while [ $# -gt 0 ]; do
  case "$1" in
    --model)       MODEL="${2:-}"; shift 2 ;;
    --task)        TASK="${2:-}"; shift 2 ;;
    --owns)        OWNS="${2:-}"; OWNS_SET=1; shift 2 ;;
    --brief)       BRIEF="${2:-}"; shift 2 ;;
    --worktree)    WORKTREE="${2:-}"; shift 2 ;;
    --partial)     PARTIAL=1; shift ;;
    --no-fallback) shift ;;
    *) die "unknown argument: $1" ;;
  esac
done
[ -n "$BRIEF" ] \
  || die "usage: agy-run.sh --model <alias> --task <slug> --owns \"<list|none>\" --brief <file> [--worktree <path>] [--partial] | --status"
[ -f "$BRIEF" ] || die "brief not found: $BRIEF"
NOTES=""   # extra report lines (defaults applied)
note() { NOTES="${NOTES}$*"$'\n'; }
[ -n "$MODEL" ] || MODEL="hydrogen"
if [ -z "$TASK" ]; then TASK="t-$(date +%s)-$$"; note "task slug missing: generated $TASK"; fi
[[ "$TASK" =~ ^[a-z0-9][a-z0-9-]*$ ]] || die "bad --task slug (use lowercase letters, digits, dashes): $TASK"
[ -z "$OWNS" ] && OWNS_SET=0

# A design task never runs on agy.
first_line=$(grep -m1 -v '^[[:space:]]*$' "$BRIEF" | tr -d '\r[:space:]' || true)
[ "$first_line" != "design" ] || die "refused: design never runs on agy (design builds go to Claude subagents)"

# ---- Model: alias with optional effort suffix, or a full id ----
FAMILY="" EFFORT="" ID=""
_a="$MODEL"; _e=""
case "$_a" in
  *-xhigh)  _e=xhigh;  _a="${_a%-xhigh}" ;;
  *-low)    _e=low;    _a="${_a%-low}" ;;
  *-medium) _e=medium; _a="${_a%-medium}" ;;
  *-high)   _e=high;   _a="${_a%-high}" ;;
esac
if FAMILY=$(alias_family "$_a"); then
  _d=medium; { [ "$FAMILY" = "hydrogen" ] || [ "$FAMILY" = "neon" ]; } && _d=high
  EFFORT="${_e:-$_d}"
  ID=$(family_id "$FAMILY" "$EFFORT")
else
  FAMILY=""; ID="$MODEL"
  case "$ID" in
    gemini-4-hydrogen-*) FAMILY=hydrogen; EFFORT="${ID##*-}" ;;
    gemini-4-neon-*)     FAMILY=neon;     EFFORT="${ID##*-}" ;;
    claude-sonnet-5-5-*) FAMILY=sonnet;   EFFORT="${ID##*-}" ;;
    claude-opus-5-5-*)   FAMILY=opus;     EFFORT="${ID##*-}" ;;
  esac
fi
[ -n "$FAMILY" ] || die "refused: only hydrogen, neon, sonnet and opus run on agy (no Flash, Carbon or Argon): $MODEL"
case "$FAMILY:$EFFORT" in
  hydrogen:low|hydrogen:medium|hydrogen:high|hydrogen:xhigh) ;;
  neon:low|neon:medium|neon:high|neon:xhigh) ;;
  sonnet:low|sonnet:medium|sonnet:high|opus:low|opus:medium|opus:high) ;;
  *) die "refused: bad effort for $FAMILY: $EFFORT" ;;
esac

# ---- Owned pathspecs ----
OWNED=(); READONLY=0
if [ $OWNS_SET -eq 0 ]; then
  OWNED=("."); note "owns missing, results unscoped"
elif [ "$OWNS" = "none" ]; then
  READONLY=1
else
  IFS=',' read -ra _parts <<< "$OWNS"
  for p in "${_parts[@]}"; do
    p="${p#"${p%%[![:space:]]*}"}"; p="${p%"${p##*[![:space:]]}"}"
    [ -n "$p" ] && OWNED+=("$p")
  done
  [ ${#OWNED[@]} -gt 0 ] || die "--owns is empty (use \"none\" for read-only)"
fi

# ---- Preflight ----
command -v "$AGY_BIN" >/dev/null 2>&1 || die "agy not installed"
RUNDIR="$ROOT"; [ -n "$WORKTREE" ] && RUNDIR="$WORKTREE"
[ -d "$RUNDIR" ] || die "run dir not found: $RUNDIR"
# The model id must be listed by `agy models`. If that command fails or prints nothing, skip the check.
MODELS_OUT=$("$AGY_BIN" models < /dev/null 2>/dev/null || true)
mkdir -p "$QDIR" "$LOGDIR"
TMO=""
if [[ "$RUN_TIMEOUT" =~ ^[0-9]+$ ]] && [ "$RUN_TIMEOUT" -gt 0 ]; then
  if command -v timeout >/dev/null 2>&1; then TMO=timeout
  elif command -v gtimeout >/dev/null 2>&1; then TMO=gtimeout; fi
fi

BEFORE="$LOGDIR/agy-before-$TASK.txt"; AFTER="$LOGDIR/agy-after-$TASK.txt"
BRIEF_OUT="$LOGDIR/agy-brief-$TASK.md"; LOG="$LOGDIR/agy-log-$TASK.txt"
: > "$LOG"                          # no stale log from an earlier run of the same task slug
IS_GIT=0
git -C "$RUNDIR" rev-parse --git-dir >/dev/null 2>&1 && IS_GIT=1
if [ $IS_GIT -eq 1 ]; then git -C "$RUNDIR" status --short | sort > "$BEFORE"; else : > "$BEFORE"; fi

build_brief() {
  {
    echo "Read AGENTS.md first and follow it."
    echo "task: $TASK"
    [ $OWNS_SET -eq 1 ] && echo "owns: $OWNS"
    [ $READONLY -eq 1 ] && echo "Read-only: do not edit any file."
    echo "You cannot run shell commands in this mode. Do not try. List any check you could not run in your report."
    echo
    cat "$BRIEF"
    if [ $PARTIAL -eq 1 ]; then
      echo
      echo "A previous model stopped partway on a quota error; some of your owned files may be partly edited. Inspect them and finish the task."
    fi
  } > "$BRIEF_OUT"
}

write_marker() {   # $1 marker name  $2 until epoch  $3 reason  $4 known (1|0). Atomic: temp file in the same dir, then mv
  local t
  t=$(mktemp "$QDIR/.tmp.XXXXXX")
  { echo "until=$(to_iso "$2")"; echo "reason=$3"; echo "known=$4"; } > "$t"
  mv -f "$t" "$QDIR/$1"
}
write_marker_for() {   # $1 model id  $2 until epoch  $3 reason  $4 known: pool models write the shared pool marker
  local p
  p=$(pool_of "$1")
  # "not available to ..." means this ONE model is not on the plan: that is not a drained pool
  if [ -n "$p" ] && ! printf '%s' "$3" | grep -Eiq 'not available'; then
    write_marker "$p" "$2" "$1: $3" "$4"
  else
    write_marker "$1" "$2" "$3" "$4"
  fi
}

# parse_reset <logfile>: prints a reset time as epoch seconds, or nothing. Best effort.
# agy error wording is UNVERIFIED; handles "try again at <date>", "try again in 2 hours 3 minutes", "in 1h 30m".
parse_reset() {
  local seg n=0 e="" now
  now=$(date +%s)
  seg=$(grep -Eio '(resets? (at|after)|try again at|retry at) +[^.;]{3,40}' "$1" | head -n 1 \
    | sed -E 's/^(resets? (at|after)|try again at|retry at) +//I' | tr -d ',' || true)
  if [ -n "$seg" ]; then
    e=$(date -d "$seg" +%s 2>/dev/null || date -j -f "%d %b %Y %H:%M" "$seg" +%s 2>/dev/null || true)
    [[ "$e" =~ ^[0-9]+$ ]] && n=$((e - now))
  fi
  if [ "$n" -le 0 ]; then
    n=0
    seg=$(grep -Eio '(try again|retry|resets?)[^0-9]{0,12}[0-9][0-9a-z :,]{0,30}' "$1" | head -n 1 || true)
    if [[ "$seg" =~ ([0-9]+)\ *(d|days?)([^a-z]|$) ]]; then n=$((n + BASH_REMATCH[1] * 86400)); fi
    if [[ "$seg" =~ ([0-9]+)\ *(h|hrs?|hours?)([^a-z]|$) ]]; then n=$((n + BASH_REMATCH[1] * 3600)); fi
    if [[ "$seg" =~ ([0-9]+)\ *(m|mins?|minutes?)([^a-z]|$) ]]; then n=$((n + BASH_REMATCH[1] * 60)); fi
  fi
  if [ "$n" -ge 60 ] && [ "$n" -le $((30 * DAY)) ]; then echo $((now + n)); fi
  return 0
}

changed_lines() {
  local n=0 a r f
  [ $IS_GIT -eq 1 ] && [ ${#OWNED[@]} -gt 0 ] || { echo 0; return; }
  while read -r a r _; do
    [[ "$a" =~ ^[0-9]+$ ]] && n=$((n + a))
    [[ "$r" =~ ^[0-9]+$ ]] && n=$((n + r))
  done < <(git -C "$RUNDIR" diff --numstat -- "${OWNED[@]}" 2>/dev/null || true)
  while IFS= read -r f; do
    [ -f "$RUNDIR/$f" ] && n=$((n + $(wc -l < "$RUNDIR/$f")))
  done < <(git -C "$RUNDIR" ls-files --others --exclude-standard -- "${OWNED[@]}" 2>/dev/null || true)
  echo "$n"
}

report() {   # $1 = model that ran (id) or "none (drained)"
  echo "task: $TASK"
  echo "model requested: $MODEL ($ID)"
  echo "model that ran: $1"
  if [ -n "$NOTES" ]; then printf '%s' "$NOTES" | sed 's/^/note: /'; fi
  if [ $IS_GIT -eq 0 ]; then
    echo "not a git repo: no diff or change count"
  else
    echo "changed lines (owned): $(changed_lines)"
    if [ ${#OWNED[@]} -gt 0 ]; then
      echo "diff stat (owned):"
      git -C "$RUNDIR" diff --stat -- "${OWNED[@]}" | sed 's/^/  /'
      git -C "$RUNDIR" status --short -- "${OWNED[@]}" | sed 's/^/  /'
    fi
    local ex=(":(exclude).claude/agy-quota" ":(exclude).claude/codex-quota" ":(exclude)$RUN_DIR") p
    if [ ${#OWNED[@]} -gt 0 ]; then
      for p in "${OWNED[@]}"; do ex+=(":(exclude)$p"); done
    fi
    git -C "$RUNDIR" status --short -- . "${ex[@]}" | sort > "$AFTER"
    local out
    out=$(comm -13 "$BEFORE" "$AFTER" || true)
    if [ -n "$out" ]; then
      if [ $READONLY -eq 1 ]; then echo "read-only task changed files:"
      elif [ -n "$WORKTREE" ]; then echo "outside owned files (the model left its scope):"
      else echo "outside owned files (possibly from other parallel tasks):"; fi
      echo "$out" | sed 's/^/  /'
    else
      echo "outside owned files: none"
    fi
  fi
  echo "--- model output (last 40 lines) ---"
  if [ -s "$LOG" ]; then tail -n 40 "$LOG"; else echo "(none)"; fi
}

# ---- Run ----
if [ -n "$MODELS_OUT" ] && ! printf '%s\n' "$MODELS_OUT" | grep -Fq -- "$ID"; then
  die "unavailable: $MODEL ($ID not in agy models)"
fi

du=$(drain_until "$ID")
if [ -n "$du" ]; then
  echo "drained: $ID, no fallback"
  echo "pool: ${du#* }"
  echo "until: ${du%% *} (skipped: marker, agy was not run)"
  exit 3
fi

build_brief
cl_before=$(changed_lines)
cmd=("$AGY_BIN" "$FLAG_PROMPT" "$(cat "$BRIEF_OUT")" "$FLAG_MODEL" "$ID" "${MODE_ARGS[@]}")
[ -n "$TMO" ] && cmd=("$TMO" "$RUN_TIMEOUT" "${cmd[@]}")
rc=0
(cd "$RUNDIR" && "${cmd[@]}") > "$LOG" 2>&1 < /dev/null || rc=$?

# ---- Classify ----
if [ $rc -eq 124 ] && [ -n "$TMO" ]; then
  echo "agy timed out on $ID after ${RUN_TIMEOUT}s (possibly waiting on a permission prompt). Last 20 log lines:"
  tail -n 20 "$LOG"
  exit 1
fi

loglines=$(wc -l < "$LOG" | tr -d ' ')
gained=1; [ "$(changed_lines)" -le "$cl_before" ] && gained=0

# Concurrency. For exit 0 the log must be short too, so a long normal answer that mentions "locked" is not flagged.
cline=$(grep -Ei "$CONC_RE" "$LOG" | head -n 1 | tr -d '\r' | cut -c1-160 || true)
if [ -n "$cline" ]; then
  if [ $rc -ne 0 ] || { [ "$loglines" -lt 40 ] && [ $gained -eq 0 ]; }; then
    echo "concurrency: $cline"
    echo "possible concurrency limit. No marker written."
    exit 4
  fi
fi

limited=0
qline=$(grep -Ei "$QUOTA_RE" "$LOG" | head -n 1 | tr -d '\r' | cut -c1-160 || true)
if [ $rc -ne 0 ]; then
  [ -n "$qline" ] && limited=1
elif [ "$loglines" -lt 40 ]; then
  qline=$(grep -Ei "$QUOTA_RE" "$LOG" | grep -Ei 'error' | head -n 1 | tr -d '\r' | cut -c1-160 || true)
  if [ -n "$qline" ]; then
    if [ $READONLY -eq 1 ] || [ $gained -eq 0 ]; then limited=1; fi
  fi
fi

if [ $limited -eq 1 ]; then
  now=$(date +%s)
  reset=$(parse_reset "$LOG")
  known=1; until_e=$reset
  if [ -z "$reset" ]; then known=0; until_e=$((now + LIMIT_DEFAULT)); fi   # 6h default is a guess
  write_marker_for "$ID" "$until_e" "$qline" "$known"
  echo "drained: $ID, no fallback"
  echo "pool: $(pool_of "$ID")"
  echo "until: $(to_iso "$until_e")"
  echo "error: $qline"
  report "none (drained)"
  exit 3
elif [ $rc -ne 0 ]; then
  echo "agy failed on $ID (exit $rc). Last 20 log lines:"
  tail -n 20 "$LOG"
  exit 1
fi
report "$ID"
exit 0
