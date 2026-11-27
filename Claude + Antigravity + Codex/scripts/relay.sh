#!/usr/bin/env bash
# relay.sh: run the whole agy <-> Codex loop for ONE task with no Claude in between.
# Claude makes ONE Bash call per task (run_in_background: true when long) and reads only the summary and diff.
#
# Usage:
#   scripts/relay.sh --task <slug> --route hydrogen|neon --owns "<comma list>" --brief <file> \
#       [--check "<shell cmd>"]... [--worktree <path>] [--hard] [--step-timeout <min>] [--no-wait]
#   scripts/relay.sh --resume <task> [--claude-verdict pass|fail --notes <file>] [--no-wait] [--step-timeout <min>]
#   scripts/relay.sh --status [<task>]     (a task: print its status JSON; none: print the quota markers)
#
# It calls scripts/agy-run.sh and scripts/codex-run.sh. agy headless has NO shell, so the script runs the
# --check commands itself after every build and fix. A failed check counts as a FAIL verdict (no review),
# and its output goes into the next fix prompt.
#
# Routes (every fix is followed by a review). Codex reviews run `codex exec --sandbox read-only`.
#   hydrogen: Hydrogen high builds -> Sol medium reviews -> Hydrogen fixes -> Sol reviews -> Sol fixes
#             -> Claude review -> Neon high fixes -> Claude review -> agy Sonnet/Opus fixes -> Claude review
#             -> (Astra medium, only after an agy Opus or Claude Opus fix failed) -> ladder exhausted.
#   neon:     Neon builds -> Sol HIGH reviews -> Neon fixes -> Sol reviews -> Claude review
#             -> agy Sonnet/Opus fixes -> Claude review -> (Astra) -> ladder exhausted. Sol never fixes Neon work.
#   --hard: Sol reviews at high instead of medium, Sol builds at high when Gemini is drained, the
#   Claude reviewer is Opus. The neon route is always hard.
# A PASS from a Codex review ends the task (exit 0). Claude review rungs STOP the script (exit 10);
# Claude reviews, then calls --resume with --claude-verdict.
#
# Fallback (reset time is read from the quota error by agy-run.sh / codex-run.sh):
#   reset < 5h away = 5-hour limit: this step WAITS (sleeps and polls), or with --no-wait exits 3.
#   later reset = weekly limit: that family is dropped for the task. No reset time: wait once, then weekly.
#   Gemini weekly:  Sol builds (high if hard), no Codex review, Claude review; fixes Sol -> agy Sonnet/Opus -> Astra.
#   Codex weekly:   Hydrogen/Neon build, no Codex review, Claude review; fixes Neon -> agy Sonnet/Opus.
#   agy Claude pool weekly: the agy Sonnet/Opus fix becomes a Claude Sonnet/Opus subagent fix: exit 10 with
#                   "needs-claude-fix"; Claude fixes, reviews, then resumes with --claude-verdict.
#   Gemini AND Codex weekly: exit 4 (ask the user; Claude only is never a default).
#
# Files (project root): .agc/briefs/<task>-sN.md, .agc/logs/, .agc/status/<task>.json (+ .state, .history,
# .notes, .checks), .agc/summaries/<task>.md.
#
# Exit codes:
#   0 done (passed, no more review)      10 needs Claude review ("needs-claude-review: <stage>" or
#   1 other error                           "needs-claude-fix: <stage>"), summary path printed
#   2 bad args / tools missing           11 ladder exhausted: ask the user
#   3 pool wait ("waiting: <family> until <time>", only with --no-wait)
#   4 Gemini and Codex both drained: ask the user
#   12 step timeout (default 30 min per step; state=timeout; --resume retries the step)
# Env: AGC_STEP_SECS (step timeout in seconds, overrides --step-timeout), AGC_FIVE_H (seconds, default 18000),
# AGC_POLL (wait poll seconds, default 30).
# Unverified, verify on first real run: quota error wording, reset-time format, Hydrogen/Neon ids,
# whether Sol and Astra share one pool on Plus.
set -uo pipefail

SCRIPTS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$PWD"
AGC=".agc"
BRIEFS="$ROOT/$AGC/briefs"; LOGS="$ROOT/$AGC/logs"; STATUS="$ROOT/$AGC/status"; SUMM="$ROOT/$AGC/summaries"
QAGY="$ROOT/.claude/agy-quota"; QCODEX="$ROOT/.claude/codex-quota"
FIVE_H="${AGC_FIVE_H:-18000}"
POLL="${AGC_POLL:-30}"
export AGY_RUN_TIMEOUT=0           # relay.sh enforces the step timeout itself

die() { echo "$*" >&2; exit "${2:-2}"; }
now_iso() { date -u +%Y-%m-%dT%H:%M:%SZ; }
epoch_iso() { date -u -d "@$1" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -r "$1" +%Y-%m-%dT%H:%M:%SZ; }
jesc() { printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' | tr '\n\t\r' '   '; }

# ================= Arguments =================
MODE=start TASK="" ROUTE="" OWNS="" BRIEF="" WORKTREE="" HARD=0 STEP_MIN=30 NOWAIT=0
VERDICT_ARG="" NOTES_ARG="" STATUS_TASK="" STEP_MIN_SET=0 NOWAIT_SET=0
CHECKS_ARGS=()
usage() {
  die "usage: relay.sh --task <slug> --route hydrogen|neon --owns \"<list>\" --brief <file> [--check \"<cmd>\"]... [--worktree <path>] [--hard] [--step-timeout <min>] [--no-wait]
       relay.sh --resume <task> [--claude-verdict pass|fail --notes <file>] [--no-wait] [--step-timeout <min>]
       relay.sh --status [<task>]"
}
while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help)        usage ;;
    --task)           TASK="${2:-}"; shift 2 ;;
    --route)          ROUTE="${2:-}"; shift 2 ;;
    --owns)           OWNS="${2:-}"; shift 2 ;;
    --brief)          BRIEF="${2:-}"; shift 2 ;;
    --check)          [ -n "${2:-}" ] || usage; CHECKS_ARGS+=("$2"); shift 2 ;;
    --worktree)       WORKTREE="${2:-}"; shift 2 ;;
    --hard)           HARD=1; shift ;;
    --step-timeout)   STEP_MIN="${2:-}"; STEP_MIN_SET=1; shift 2 ;;
    --no-wait)        NOWAIT=1; NOWAIT_SET=1; shift ;;
    --resume)         MODE=resume; TASK="${2:-}"; shift 2 ;;
    --claude-verdict) VERDICT_ARG="${2:-}"; shift 2 ;;
    --notes)          NOTES_ARG="${2:-}"; shift 2 ;;
    --status)         MODE=status
                      if [ $# -ge 2 ] && [[ "$2" != --* ]]; then STATUS_TASK="$2"; shift; fi
                      shift ;;
    *) die "unknown argument: $1" ;;
  esac
done

if [ "$MODE" = status ]; then
  if [ -n "$STATUS_TASK" ]; then
    [ -f "$STATUS/$STATUS_TASK.json" ] || die "no status for task: $STATUS_TASK"
    cat "$STATUS/$STATUS_TASK.json"
  else
    "$SCRIPTS/agy-run.sh" --status || true
    "$SCRIPTS/codex-run.sh" --status || true
  fi
  exit 0
fi

# ================= Tools and validation =================
TMO=""
if command -v timeout >/dev/null 2>&1; then TMO=timeout; elif command -v gtimeout >/dev/null 2>&1; then TMO=gtimeout; fi
[ -n "$TMO" ] || die "timeout (or gtimeout) not installed"
command -v git >/dev/null 2>&1 || die "git not installed"
command -v agy >/dev/null 2>&1 || die "agy not installed"
command -v codex >/dev/null 2>&1 || die "codex not installed"
{ [ -x "$SCRIPTS/agy-run.sh" ] && [ -x "$SCRIPTS/codex-run.sh" ]; } || die "agy-run.sh or codex-run.sh missing or not executable in $SCRIPTS"
[[ "$STEP_MIN" =~ ^[1-9][0-9]*$ ]] || die "bad --step-timeout (minutes, a whole number): $STEP_MIN"
[[ "$TASK" =~ ^[a-z0-9][a-z0-9-]*$ ]] || die "bad or missing task slug (lowercase letters, digits, dashes): $TASK"
mkdir -p "$BRIEFS" "$LOGS" "$STATUS" "$SUMM" "$QAGY" "$QCODEX"

# ================= State =================
STATE_VARS=(TASK ROUTE OWNS BRIEF WORKTREE HARD STEP_MIN NOWAIT STARTED DONE CUR ACTOR VERDICT PHASE STEP
  RELAY_STATE BUILT_BY_SOL OPUS_TRIED WK_GEM WK_CODEX WK_CLAUDE WT_GEM WT_CODEX WT_CLAUDE NOTES_FILE
  LAST_EXIT LAST_MODEL PARTIAL CLAUDE_FIX WAIT_FAM WAIT_KEY WAIT_UNTIL)
DONE="" CUR="" ACTOR="" VERDICT="" PHASE="" STEP=0 RELAY_STATE=running BUILT_BY_SOL=0 OPUS_TRIED=0
WK_GEM=0 WK_CODEX=0 WK_CLAUDE=0 WT_GEM=0 WT_CODEX=0 WT_CLAUDE=0 NOTES_FILE="" LAST_EXIT=0 LAST_MODEL=""
PARTIAL=0 CLAUDE_FIX=0 WAIT_FAM="" WAIT_KEY="" WAIT_UNTIL=0 STARTED="" DONE_NOTE=""
SF="$STATUS/$TASK.state"; HIST="$STATUS/$TASK.history"; CHK="$STATUS/$TASK.checks"
NOTES="$STATUS/$TASK.notes"; CHKRES="$STATUS/$TASK.checkres"; SUMMARY="$SUMM/$TASK.md"
JSON="$STATUS/$TASK.json"

save_state() {
  local t v; t=$(mktemp "$STATUS/.tmp.XXXXXX")
  for v in "${STATE_VARS[@]}"; do printf '%s=%q\n' "$v" "${!v}"; done > "$t"
  mv -f "$t" "$SF"
}
load_state() {
  # shellcheck disable=SC1090
  . "$SF"
}

RUNDIR="$ROOT"
OWNED=()
setup_owned() {
  local p _parts
  [ -n "$WORKTREE" ] && RUNDIR="$WORKTREE"
  OWNED=()
  IFS=',' read -ra _parts <<< "$OWNS"
  for p in "${_parts[@]}"; do
    p="${p#"${p%%[![:space:]]*}"}"; p="${p%"${p##*[![:space:]]}"}"
    [ -n "$p" ] && OWNED+=("$p")
  done
}

IS_GIT=0
changed_lines() {
  local n=0 a r f
  { [ $IS_GIT -eq 1 ] && [ ${#OWNED[@]} -gt 0 ]; } || { echo 0; return; }
  while read -r a r _; do
    [[ "$a" =~ ^[0-9]+$ ]] && n=$((n + a))
    [[ "$r" =~ ^[0-9]+$ ]] && n=$((n + r))
  done < <(git -C "$RUNDIR" diff --numstat -- "${OWNED[@]}" 2>/dev/null || true)
  while IFS= read -r f; do
    [ -f "$RUNDIR/$f" ] && n=$((n + $(wc -l < "$RUNDIR/$f")))
  done < <(git -C "$RUNDIR" ls-files --others --exclude-standard -- "${OWNED[@]}" 2>/dev/null || true)
  echo "$n"
}

hist() {   # step | stage | model | exit | result | log
  printf '%s|%s|%s|%s|%s|%s\n' "$STEP" "${CUR:-none}/${PHASE:-none}" "${LAST_MODEL:--}" "$1" "$2" "${3:--}" >> "$HIST"
}

write_status() {
  local t; t=$(mktemp "$STATUS/.tmp.XXXXXX")
  printf '{"task":"%s","route":"%s","stage":"%s","model":"%s","attempt":%s,"started":"%s","updated":"%s","last_exit":%s,"state":"%s"}\n' \
    "$(jesc "$TASK")" "$(jesc "$ROUTE")" "$(jesc "${CUR:-none}/${PHASE:-none}")" "$(jesc "$LAST_MODEL")" "$STEP" \
    "$STARTED" "$(now_iso)" "${LAST_EXIT:-0}" "$(jesc "$RELAY_STATE")" > "$t"
  mv -f "$t" "$JSON"
}

reviewer_name() {   # opus above 800 changed lines and for all hard/sensitive (neon) tasks
  local n; n=$(changed_lines)
  if [ "$HARD" = 1 ] || [ "$ROUTE" = neon ] || [ "$n" -gt 800 ]; then echo opus-reviewer; else echo sonnet-reviewer; fi
}

write_summary() {
  local t verdict n pools
  t=$(mktemp "$STATUS/.tmp.XXXXXX")
  case "$RELAY_STATE" in
    done)                 verdict="PASS ($DONE_NOTE)" ;;
    needs-claude-review)  verdict="PENDING Claude review (stage $CUR)" ;;
    ladder-exhausted)     verdict="FAIL: ladder exhausted, ask the user" ;;
    timeout)              verdict="TIMEOUT at $CUR/$PHASE" ;;
    waiting)              verdict="WAITING for the ${WAIT_FAM} pool" ;;
    drained)              verdict="STOPPED: Gemini and Codex both drained, ask the user" ;;
    error)                verdict="ERROR at $CUR/$PHASE" ;;
    *)                    verdict="RUNNING" ;;
  esac
  n=$(changed_lines)
  pools="gemini=$([ "$WK_GEM" = 1 ] && echo weekly || echo ok) codex=$([ "$WK_CODEX" = 1 ] && echo weekly || echo ok) agy-claude=$([ "$WK_CLAUDE" = 1 ] && echo weekly || echo ok)"
  {
    echo "# Relay summary: $TASK"
    echo
    echo "- verdict: $verdict"
    echo "- state: $RELAY_STATE (last exit $LAST_EXIT)"
    echo "- route: $ROUTE$([ "$HARD" = 1 ] && echo ' (hard)')"
    echo "- stage reached: ${CUR:-none}/${PHASE:-none}, step $STEP, rungs finished: ${DONE:-none}"
    if [ $IS_GIT -eq 1 ]; then echo "- changed lines (owned, git diff --numstat): $n"; else echo "- not a git repo: no line count"; fi
    echo "- Claude reviewer if needed: $(reviewer_name)"
    echo "- pools: $pools"
    echo "- owned files: $OWNS"
    echo
    echo "## Changed files"
    if [ $IS_GIT -eq 1 ] && [ ${#OWNED[@]} -gt 0 ]; then
      git -C "$RUNDIR" status --short -- "${OWNED[@]}" 2>/dev/null | sed 's/^/    /'
    fi
    echo
    echo "## Check results (latest run)"
    if [ -s "$CHKRES" ]; then sed 's/^/- /' "$CHKRES"; else echo "- none run yet, or no checks given"; fi
    echo
    echo "## Steps"
    echo "| step | stage | model | exit | result | log |"
    echo "|---|---|---|---|---|---|"
    if [ -f "$HIST" ]; then awk -F'|' '{printf "| %s | %s | %s | %s | %s | %s |\n",$1,$2,$3,$4,$5,$6}' "$HIST"; fi
    echo
    echo "## Notes for the next fix (latest, verbatim)"
    if [ -s "$NOTES" ]; then sed 's/^/    /' "$NOTES"; else echo "    none"; fi
    echo
    echo "Logs: $LOGS/ (names start with $TASK-s). Status: $JSON"
    echo "On failure or timeout, the log-reader (Haiku low) reads these logs. Do not read them in the main chat."
  } > "$t"
  mv -f "$t" "$SUMMARY"
}

checkpoint() { save_state; write_status; write_summary; }

finish() {   # $1 exit code  $2 relay state  then message lines
  local code=$1 st=$2 l; shift 2
  RELAY_STATE="$st"; LAST_EXIT=$code
  checkpoint
  for l in "$@"; do echo "$l"; done
  echo "summary: $SUMMARY"
  exit "$code"
}
finish_done() { DONE_NOTE="$1"; PHASE=done; finish 0 done "done: $TASK ($1)"; }

# ================= Pools =================
# Family names: gem (hydrogen, neon), codex (sol, astra), claude (agy Sonnet and Opus).
M_E=0 M_KNOWN=0 P_STATE=ok P_UNTIL=0
read_marker() {   # $1 file: sets M_E (epoch, 0 when absent or expired) and M_KNOWN
  local u e k
  M_E=0; M_KNOWN=0
  [ -f "$1" ] || return 0
  u=$(sed -n 's/^until=//p' "$1" | head -n 1 | tr -d '\r')
  e=$(date -u -d "$u" +%s 2>/dev/null || true)
  [[ "$e" =~ ^[0-9]+$ ]] || return 0
  [ "$(date +%s)" -lt "$e" ] || return 0
  M_E=$e
  k=$(sed -n 's/^known=//p' "$1" | head -n 1 | tr -d '\r')
  [ "$k" = 1 ] && M_KNOWN=1
  return 0
}
set_weekly() { case "$1" in gem) WK_GEM=1 ;; codex) WK_CODEX=1 ;; claude) WK_CLAUDE=1 ;; esac; }
fam_name() { case "$1" in gem) echo gemini ;; codex) echo codex ;; claude) echo agy-claude ;; esac; }
clear_guess_marker() { case "$1" in gem) rm -f "${QAGY:?}/gemini-pool" ;; claude) rm -f "${QAGY:?}/claude-pool" ;; codex) rm -f "${QCODEX:?}/5h" ;; esac; }
pool_check() {   # $1 family: sets P_STATE ok|wait|weekly and P_UNTIL (epoch)
  local fam=$1 wk=0 wt=0 now
  case "$fam" in gem) wk=$WK_GEM; wt=$WT_GEM ;; codex) wk=$WK_CODEX; wt=$WT_CODEX ;; claude) wk=$WK_CLAUDE; wt=$WT_CLAUDE ;; esac
  P_STATE=ok; P_UNTIL=0
  if [ "$wk" = 1 ]; then P_STATE=weekly; return 0; fi
  now=$(date +%s)
  case "$fam" in
    gem)    read_marker "$QAGY/gemini-pool" ;;
    claude) read_marker "$QAGY/claude-pool" ;;
    codex)  read_marker "$QCODEX/weekly"
            if [ "$M_E" -gt 0 ]; then set_weekly codex; P_STATE=weekly; return 0; fi
            read_marker "$QCODEX/5h" ;;
  esac
  [ "$M_E" -gt 0 ] || return 0
  if [ "$M_KNOWN" = 1 ]; then
    if [ $((M_E - now)) -le "$FIVE_H" ] && [ "$wt" -lt 3 ]; then P_STATE=wait; P_UNTIL=$M_E
    else set_weekly "$fam"; P_STATE=weekly; fi
  else   # no reset time found: wait once, retry once, then weekly
    if [ "$wt" -lt 1 ]; then
      P_STATE=wait; P_UNTIL=$M_E; [ $((M_E - now)) -gt "$FIVE_H" ] && P_UNTIL=$((now + FIVE_H))
    elif [ "$WAIT_KEY" = "$fam" ] && [ "$WAIT_UNTIL" -gt "$now" ]; then
      P_STATE=wait; P_UNTIL=$WAIT_UNTIL                          # the one wait is still running
    elif [ "$WAIT_KEY" = "$fam" ] && [ "$WAIT_UNTIL" -gt 0 ]; then
      WAIT_UNTIL=0; clear_guess_marker "$fam"; P_STATE=ok        # the wait is over: drop the guess marker, retry once
    else
      set_weekly "$fam"; P_STATE=weekly
    fi
  fi
  return 0
}
refresh_pools() { pool_check gem; pool_check codex; pool_check claude; }

do_wait() {   # $1 family; P_UNTIL is set
  local fam=$1 until=$P_UNTIL left
  if [ "$WAIT_KEY" != "$fam" ] || [ "$WAIT_UNTIL" != "$until" ]; then   # a new wait, not a continued one
    case "$fam" in gem) WT_GEM=$((WT_GEM + 1)) ;; codex) WT_CODEX=$((WT_CODEX + 1)) ;; claude) WT_CLAUDE=$((WT_CLAUDE + 1)) ;; esac
    WAIT_KEY=$fam; WAIT_UNTIL=$until
  fi
  WAIT_FAM=$(fam_name "$fam")
  if [ "$NOWAIT" = 1 ]; then
    finish 3 waiting "waiting: $WAIT_FAM until $(epoch_iso "$until")" "resume: scripts/relay.sh --resume $TASK"
  fi
  RELAY_STATE=waiting; checkpoint
  echo "relay: waiting for the $WAIT_FAM pool until $(epoch_iso "$until")"
  while [ "$(date +%s)" -lt "$until" ]; do
    left=$((until - $(date +%s)))
    [ "$left" -gt "$POLL" ] && left=$POLL
    sleep "$left"
  done
  RELAY_STATE=running; WAIT_FAM=""; checkpoint
}
ensure_family() {   # 0 = usable now (waited if needed), 1 = weekly (family dropped)
  while :; do
    pool_check "$1"
    case "$P_STATE" in
      ok) return 0 ;;
      weekly) checkpoint; return 1 ;;
      *) do_wait "$1" ;;
    esac
  done
}

# ================= Ladder =================
ladder() {   # id actor verdict [flag]
  if [ "$ROUTE" = neon ]; then
    echo "build-n neon codex"
    echo "fix-n neon codex+claude"
    echo "fix-sol sol claude gemonly"
    echo "fix-agy agy claude"
    echo "fix-astra astra claude"
  else
    echo "build-h hydrogen codex"
    echo "fix-h hydrogen codex"
    echo "fix-sol sol claude"
    echo "fix-neon neon claude"
    echo "fix-agy agy claude"
    echo "fix-astra astra claude"
  fi
}
in_done() { case " $DONE " in *" $1 "*) return 0 ;; esac; return 1; }
rung_ok() {   # $1 id  $2 actor  $3 flag
  case "$2" in
    hydrogen|neon) [ "$WK_GEM" = 1 ] && return 1 ;;
    sol) [ "$WK_CODEX" = 1 ] && return 1
         [ "${3:-}" = gemonly ] && [ "$WK_GEM" != 1 ] && return 1 ;;
    astra) [ "$WK_CODEX" = 1 ] && return 1
           [ "$OPUS_TRIED" = 1 ] || return 1 ;;
  esac
  [ "$1" = fix-h ] && [ "$WK_CODEX" = 1 ] && return 1   # the cheap Hydrogen self-fix is gated by a Sol review
  return 0
}
actor_family() { case "$1" in hydrogen|neon) echo gem ;; sol|astra) echo codex ;; agy) echo claude ;; esac; }

select_rung() {
  local id actor verdict flag
  refresh_pools
  if [ "$WK_GEM" = 1 ] && [ "$WK_CODEX" = 1 ]; then
    finish 4 drained "both-drained: Gemini and Codex weekly limits are used up" "ask the user before switching to Claude only (never a default)"
  fi
  if [ -z "$DONE" ] && [ "$WK_GEM" = 1 ]; then
    CUR=build-sol; ACTOR=sol; VERDICT=claude; BUILT_BY_SOL=1; PHASE=exec; checkpoint; return 0
  fi
  while read -r id actor verdict flag; do
    in_done "$id" && continue
    rung_ok "$id" "$actor" "$flag" || continue
    CUR=$id; ACTOR=$actor; VERDICT=$verdict; PHASE=exec; checkpoint; return 0
  done < <(ladder)
  CUR=""; PHASE=""
  finish 11 ladder-exhausted "ladder-exhausted: $TASK" "ask the user: every rung failed review or is unavailable"
}

eff_verdict() {
  local v=$VERDICT
  case "$ACTOR" in sol|astra) v=claude ;; esac
  [ "$BUILT_BY_SOL" = 1 ] && v=claude
  if [ "$v" != claude ]; then
    pool_check codex
    [ "$P_STATE" = weekly ] && v=claude
  fi
  echo "$v"
}

# ================= Running steps =================
STEP_SECS=${AGC_STEP_SECS:-$((STEP_MIN * 60))}
RC=0 LAST_OUT=""
run_step() {   # $1 slug, rest = command. Output in .agc/logs/<slug>.out, exit in RC
  local slug=$1; shift
  LAST_OUT="$LOGS/$slug.out"
  RC=0
  "$TMO" -k 10 "$STEP_SECS" "$@" > "$LAST_OUT" 2>&1 < /dev/null || RC=$?
}
is_timeout() { [ "$1" -eq 124 ] || [ "$1" -eq 137 ]; }
timeout_exit() {   # $1 log path
  hist "$RC" "timeout after ${STEP_SECS}s" "$1"
  finish 12 timeout "timeout: $CUR/$PHASE (step $STEP) after ${STEP_SECS}s" "log: $1" \
    "the log-reader (Haiku low) reads the log; retry the step with: scripts/relay.sh --resume $TASK"
}
error_exit() {   # $1 message  $2 log
  hist "$RC" "error" "$2"
  { echo "--- last 20 lines of $2 ---"; tail -n 20 "$2" 2>/dev/null || true; } >&2
  finish 1 error "error: $1 (exit $RC, step $STEP)" "log: $2" "the log-reader (Haiku low) reads the log"
}

build_step_brief() {   # $1 slug: writes $BRIEFS/<slug>.md (a build or a fix) and prints its path
  local f="$BRIEFS/$1.md"
  {
    cat "$BRIEF"
    echo
    if [ -s "$CHK" ]; then
      echo "## Checks"
      echo "The relay runs these checks after you finish (you cannot run them yourself):"
      sed 's/^/- /' "$CHK"
      echo
    fi
    if [ -n "$DONE" ]; then
      echo "## Fix round ($ACTOR)"
      echo "The previous attempt was checked and reviewed. Fix every defect below, only in the owned files."
      echo "Make the smallest change that resolves each note. Notes, verbatim:"
      echo
      if [ -s "$NOTES" ]; then cat "$NOTES"; else echo "(no notes were recorded)"; fi
    fi
    if [ "$PARTIAL" = 1 ]; then
      echo
      echo "A previous model stopped partway on a quota error; some of your owned files may be partly edited. Inspect them and finish the task."
    fi
  } > "$f"
  echo "$f"
}
build_review_brief() {   # $1 slug
  local f="$BRIEFS/$1.md"
  {
    echo "Review task $TASK. Owned files: $OWNS."
    echo "Run \`git diff -- <owned files>\` and read any new untracked owned file. Do not edit anything."
    echo "Judge the work against the brief below. Reply with PASS or FAIL on the first line, then numbered notes"
    echo "(file:line, problem, required change). Only defects that break the brief's acceptance criteria."
    echo
    echo "Checks the relay ran (latest):"
    if [ -s "$CHKRES" ]; then sed 's/^/- /' "$CHKRES"; else echo "- none"; fi
    echo
    echo "## Brief"
    cat "$BRIEF"
  } > "$f"
  echo "$f"
}
sol_effort() { if [ "$HARD" = 1 ] || [ "$ROUTE" = neon ]; then echo high; else echo medium; fi; }

claude_fix_exit() {
  local bf who lines
  STEP=$((STEP + 1)); lines=$(changed_lines)
  who=claude-sonnet-fixer
  if [ "$HARD" = 1 ] || [ "$ROUTE" = neon ] || [ "$lines" -gt 800 ]; then who=claude-opus-builder; OPUS_TRIED=1; fi
  bf=$(build_step_brief "$TASK-s$STEP")
  PHASE=claude; CLAUDE_FIX=1; LAST_MODEL="claude-pro:$who"
  hist 0 "agy Claude pool drained: fix moves to $who" "$bf"
  finish 10 needs-claude-review "needs-claude-fix: $CUR (agy Claude pool drained; run $who with the fix brief)" \
    "fix-brief: $bf" "after the fix and your review: scripts/relay.sh --resume $TASK --claude-verdict pass|fail --notes <file>"
}

do_exec() {
  local fam slug bf model lines wt=()
  fam=$(actor_family "$ACTOR")
  if ! ensure_family "$fam"; then
    [ "$ACTOR" = agy ] && claude_fix_exit
    PARTIAL=1; CUR=""; PHASE=""; checkpoint; return 0   # weekly: reselect without this family
  fi
  [ -n "$WORKTREE" ] && wt=(--worktree "$WORKTREE")
  STEP=$((STEP + 1)); slug="$TASK-s$STEP"
  bf=$(build_step_brief "$slug")
  case "$ACTOR" in
    hydrogen|neon) model="$ACTOR" ;;
    agy)
      lines=$(changed_lines)
      if [ "$HARD" = 1 ] || [ "$ROUTE" = neon ] || [ "$lines" -gt 800 ]; then model=opus; OPUS_TRIED=1; else model=sonnet; fi ;;
    sol)   model="sol-$(sol_effort)" ;;
    *)     model="astra" ;;
  esac
  LAST_MODEL="$model"; checkpoint
  case "$ACTOR" in
    sol|astra) run_step "$slug" "$SCRIPTS/codex-run.sh" --model "$model" --task "$slug" --owns "$OWNS" --brief "$bf" ${wt[@]+"${wt[@]}"} ;;
    *)         run_step "$slug" "$SCRIPTS/agy-run.sh" --model "$model" --task "$slug" --owns "$OWNS" --brief "$bf" ${wt[@]+"${wt[@]}"} ;;
  esac
  if is_timeout "$RC"; then timeout_exit "$LAST_OUT"; fi
  case "$RC" in
    0) hist 0 "ok" "$LAST_OUT"; PARTIAL=0; PHASE=check; checkpoint ;;
    3|5)
      hist "$RC" "drained" "$LAST_OUT"
      pool_check "$fam"
      if [ "$P_STATE" = ok ]; then   # no pool marker: only this model id is unavailable, skip the rung
        DONE="$DONE $CUR"; CUR=""; PHASE=""; PARTIAL=1
      fi
      checkpoint ;;
    4) hist 4 "concurrency" "$LAST_OUT"; error_exit "suspected concurrency limit" "$LAST_OUT" ;;
    *) error_exit "$model failed" "$LAST_OUT" ;;
  esac
}

do_checks() {
  local cmd rc failed=0 out="$LOGS/$TASK-s$STEP-checks.txt" one="$LOGS/$TASK-s$STEP-check-one.txt" newnotes="$NOTES.new"
  : > "$CHKRES"; : > "$out"; : > "$newnotes"
  if [ -s "$CHK" ]; then
    while IFS= read -r cmd <&3; do
      [ -n "$cmd" ] || continue
      rc=0
      (cd "$RUNDIR" && "$TMO" -k 5 "$STEP_SECS" bash -c "$cmd") > "$one" 2>&1 < /dev/null || rc=$?
      { echo "== check: $cmd (exit $rc)"; cat "$one"; } >> "$out"
      if is_timeout "$rc"; then RC=$rc; timeout_exit "$out"; fi
      if [ "$rc" -eq 0 ]; then
        echo "$cmd -> pass" >> "$CHKRES"
      else
        failed=1
        echo "$cmd -> FAIL (exit $rc)" >> "$CHKRES"
        { echo "Check failed: $cmd (exit $rc). Last output:"; tail -n 40 "$one" | sed 's/^/    /'; echo; } >> "$newnotes"
      fi
    done 3< "$CHK"
  fi
  if [ $failed -eq 1 ]; then
    mv -f "$newnotes" "$NOTES"
    hist 1 "checks FAILED (counts as FAIL, no review)" "$out"
    DONE="$DONE $CUR"; CUR=""; PHASE=""; checkpoint
    return 0
  fi
  rm -f "$newnotes" "$one"
  hist 0 "checks ok" "$out"
  PHASE=verdict; checkpoint
}

claude_review_exit() {   # $1 stage label
  PHASE=claude; CLAUDE_FIX=0
  hist 0 "waiting for the Claude review" "$SUMMARY"
  finish 10 needs-claude-review "needs-claude-review: $1" \
    "reviewer: $(reviewer_name) (changed lines $(changed_lines))" \
    "notes from the last Codex review (if any) are in the summary" \
    "then: scripts/relay.sh --resume $TASK --claude-verdict pass|fail --notes <file>"
}

do_verdict() {
  local ev slug bf model rv v wt=()
  ev=$(eff_verdict)
  if [ "$ev" = claude ]; then claude_review_exit "$CUR"; fi
  if ! ensure_family codex; then claude_review_exit "$CUR"; fi
  [ -n "$WORKTREE" ] && wt=(--worktree "$WORKTREE")
  STEP=$((STEP + 1)); slug="$TASK-s$STEP"
  bf=$(build_review_brief "$slug")
  model="sol-$(sol_effort)"; LAST_MODEL="$model"; checkpoint
  run_step "$slug" "$SCRIPTS/codex-run.sh" --review --model "$model" --task "$slug" --owns "$OWNS" --brief "$bf" ${wt[@]+"${wt[@]}"}
  rv="$LOGS/codex-last-$slug.md"
  if is_timeout "$RC"; then timeout_exit "$LAST_OUT"; fi
  case "$RC" in
    0) ;;
    3|5) hist "$RC" "drained" "$LAST_OUT"; checkpoint; return 0 ;;   # the loop re-enters: waits, or goes to Claude review
    4) error_exit "suspected concurrency limit" "$LAST_OUT" ;;
    *) error_exit "$model review failed" "$LAST_OUT" ;;
  esac
  v=""
  [ -s "$rv" ] && v=$(grep -m1 -v '^[[:space:]]*$' "$rv" | tr -d '*#`[:space:].:' | tr '[:lower:]' '[:upper:]')
  case "$v" in
    PASS*) hist 0 "review PASS" "$rv"; finish_done "Codex $model review PASS" ;;
  esac
  { if [ -s "$rv" ]; then cat "$rv"; else echo "FAIL"; echo "1. The reviewer returned no verdict. Re-check the owned files against the brief."; fi; } > "$NOTES"
  hist 0 "review FAIL" "$rv"
  if [ "$VERDICT" = "codex+claude" ]; then claude_review_exit "$CUR"; fi
  DONE="$DONE $CUR"; CUR=""; PHASE=""; checkpoint
}

main_loop() {
  while :; do
    [ -n "$CUR" ] || select_rung
    case "$PHASE" in
      exec)    do_exec ;;
      check)   do_checks ;;
      verdict) do_verdict ;;
      claude)  claude_review_exit "$CUR" ;;
      *)       finish 1 error "error: bad phase '$PHASE' in state" ;;
    esac
  done
}

# ================= Start or resume =================
if [ "$MODE" = start ]; then
  { [ "$ROUTE" = hydrogen ] || [ "$ROUTE" = neon ]; } || die "bad or missing --route (hydrogen or neon): $ROUTE"
  { [ -n "$OWNS" ] && [ "$OWNS" != none ]; } || die "--owns is required and cannot be none (the relay builds and fixes)"
  { [ -n "$BRIEF" ] && [ -f "$BRIEF" ]; } || die "brief not found: $BRIEF"
  if [ -n "$WORKTREE" ] && [ ! -d "$WORKTREE" ]; then die "worktree not found: $WORKTREE"; fi
  first_line=$(grep -m1 -v '^[[:space:]]*$' "$BRIEF" | tr -d '\r[:space:]' || true)
  [ "$first_line" != "design" ] || die "refused: design never runs on agy or Codex (design builds go to Claude subagents)"
  case "$BRIEF" in /*) ;; *) BRIEF="$ROOT/$BRIEF" ;; esac
  [ "$ROUTE" = neon ] && HARD=1
  rm -f "${HIST:?}" "${CHKRES:?}" "${NOTES:?}" "${SF:?}" "${JSON:?}" "${SUMMARY:?}"
  : > "$CHK"
  if [ ${#CHECKS_ARGS[@]} -gt 0 ]; then printf '%s\n' "${CHECKS_ARGS[@]}" > "$CHK"; fi
  STARTED=$(now_iso)
  setup_owned
  git -C "$RUNDIR" rev-parse --git-dir >/dev/null 2>&1 && IS_GIT=1
  checkpoint
  echo "relay: task $TASK route $ROUTE owns $OWNS"
else
  [ -f "$SF" ] || die "no state for task: $TASK"
  CLI_STEP_MIN=$STEP_MIN CLI_NOWAIT=$NOWAIT
  load_state
  [ "$STEP_MIN_SET" = 1 ] && STEP_MIN="$CLI_STEP_MIN"
  NOWAIT=$CLI_NOWAIT                 # --no-wait applies to this call only
  STEP_SECS=${AGC_STEP_SECS:-$((STEP_MIN * 60))}
  setup_owned
  git -C "$RUNDIR" rev-parse --git-dir >/dev/null 2>&1 && IS_GIT=1
  case "$RELAY_STATE" in
    done) echo "done: $TASK (already finished)"; echo "summary: $SUMMARY"; exit 0 ;;
    ladder-exhausted) echo "ladder-exhausted: $TASK"; echo "summary: $SUMMARY"; exit 11 ;;
  esac
  if [ "$PHASE" = claude ]; then
    case "$VERDICT_ARG" in
      pass) hist 0 "Claude review PASS" "$SUMMARY"; finish_done "Claude review PASS at $CUR" ;;
      fail)
        { [ -n "$NOTES_ARG" ] && [ -f "$NOTES_ARG" ]; } || die "--claude-verdict fail needs --notes <file>"
        cp "$NOTES_ARG" "$NOTES"
        hist 0 "Claude review FAIL" "$NOTES"
        DONE="$DONE $CUR"; CUR=""; PHASE=""; CLAUDE_FIX=0; RELAY_STATE=running; checkpoint ;;
      *) die "task $TASK waits for a Claude review: pass --claude-verdict pass|fail (and --notes <file> for fail)" ;;
    esac
  else
    [ -z "$VERDICT_ARG" ] || die "task $TASK is not waiting for a Claude review (state $RELAY_STATE, stage ${CUR:-none}/${PHASE:-none})"
    RELAY_STATE=running; checkpoint
  fi
fi

[ -f "$CHK" ] || : > "$CHK"
main_loop
