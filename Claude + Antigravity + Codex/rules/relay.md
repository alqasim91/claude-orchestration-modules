Read this before the first `scripts/relay.sh` call of a run, and again after any exit other than 0. Self-contained. Cross-rules: the main session never implements; ONE relay call per task; never add `--dangerously-skip-permissions` or any Codex flag that bypasses the sandbox or approvals; env files are secrets; design never goes to agy or Codex.

# What relay.sh does
Runs the whole agy and Codex loop for one task with no Claude in between: build, then checks (agy headless has no shell, so the script runs them), Codex review, fix, check, review, following `fix-ladders.md`. It calls `agy-run.sh` and `codex-run.sh`, never `agy` or `codex` directly. It stops at the first step that needs Claude.

# Calling it
```
scripts/relay.sh --task <slug> --route hydrogen|neon --owns "<comma list>" --brief .agc/briefs/<slug>.md [--check "<shell cmd>"]... [--worktree <path>] [--hard] [--step-timeout <min>]
scripts/relay.sh --resume <slug> --claude-verdict pass|fail --notes <file>
scripts/relay.sh --status <slug>
```
- One Bash call per task, all of a wave in ONE message. Use `run_in_background: true` for anything that may run long (a build plus review usually does). Wait for the completion notification; never poll with sleep.
- Brief: body only, in `.agc/briefs/<slug>.md` (goal, exact files, acceptance criteria, constraints). The script adds `task:`, `owns:`, "Read AGENTS.md first" and the no-shell line.
- `--owns` is a real file list, never `none`. `--check` is repeated, one shell command each (tests, lint, `node --check`); the script runs them after every agy step. `--hard` makes a hard task (Opus review, Sol high, Neon route). `--step-timeout` default 30 minutes.
- Not executable: `bash scripts/relay.sh ...`.

# Files
- `.agc/status/<slug>.json`: stage, model, attempt, started, updated, last_exit, state. Read it with `--status`, not by hand.
- `.agc/summaries/<slug>.md`: verdict, route stage reached, changed files, changed line count (`git diff --numstat`), check results, log paths. **This and the diff are all Opus reads.**
- `.agc/notes/<slug>.md`: reviewer verdicts Claude writes for `--resume` (first line PASS or FAIL, numbered notes).
- Logs: the paths in the summary. Never read them yourself.

# Exit codes

| Exit | Meaning | Opus does |
|---|---|---|
| 0 | Done, passed, no more review | Read summary and diff, accept |
| 10 | `needs-claude-review: <stage>` plus the summary path | Spawn the Claude reviewer (800-line cut), write its verdict to a notes file, `--resume` |
| 11 | Ladder exhausted | ASK THE USER (`fix-ladders.md`) |
| 12 | A step hit its timeout, state=timeout | `log-reader`, then decide: retry with a longer `--step-timeout`, fix the brief, or ask |
| 3 | `waiting: <family> until <time>` | `fallback.md` |
| 4 | Both families drained | `fallback.md`: ASK THE USER |
| 1 | Other error (login, crash, unknown flag) | `log-reader`; login failure or permission block = hard blocker, stop and ask |
| 2 | Bad arguments, or `agy`, `codex` or `git` missing | Fix the call; a missing tool is a hard blocker, tell the user |

# Exit 10 procedure
1. Read the summary (its changed line count and changed files). Read the diff of the listed files.
2. Spawn `sonnet-reviewer` (800 changed lines or fewer) or `opus-reviewer` (above 800, or `--hard`, or sensitive). Prompt: header (`task:`, `owns:`), the acceptance criteria, the summary path, and the earlier defects when this is a re-review. Give it read-only access to the diff.
3. Save the verdict to `.agc/notes/<slug>.md`. Call `relay.sh --resume <slug> --claude-verdict pass|fail --notes .agc/notes/<slug>.md`. The script continues the ladder and stops again with 0, 10, 11 or 12.

# Failure or timeout (exits 1, 12 and 11 when the cause is unclear)
Spawn `log-reader` (Haiku low) with the log paths from the summary. It returns the cause in 5 lines. Read nothing else from the logs. Never use it on success.

# Accept-edits
Setup asks once, yes or no, whether Claude may edit files here without asking (`install.sh --accept-edits` or `--no-accept-edits`). Yes sets `defaultMode: acceptEdits` in `.claude/settings.json`, so a run can finish while the user is away. agy always runs `-p --mode accept-edits --print-timeout 0`; with no shell, the checks are the script's job. Never add `--dangerously-skip-permissions`.

# Unverified, check on the first real run
- Hydrogen and Neon ids in `agy models`; whether `--mode accept-edits` blocks nothing a build needs.
- Codex quota error wording, reset-time format, Sol and Astra sharing one pool on Plus.
- Whether `agy` runs in parallel (the caps in `CLAUDE.md` are guesses).
- Exit 3 retry: re-running the same call after the reset time continues the task.
- Astra launch from the main flow after a Claude Opus fix (`codex-run.sh --model astra`, medium).
- The summary format and the real changed-line count with untracked files.
