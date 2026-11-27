@AGENTS.md

# Orchestration (Claude + Antigravity + Codex: Claude plans in waves, `relay.sh` runs each task's agy and Codex loop, Claude reviews only when the script asks)

## Hard rule: the main session never implements
Claude (Opus, this session) is the planner and the judge, never the builder. **Even work that needs Opus itself runs in a sub-agent** (`claude-opus-builder`). No exceptions.
- NEVER edit, write, move or delete project files; never run builds, installs, tests, migrations, formatters or codemods.
- Jobs: plan, write briefs, make ONE `relay.sh` call per task, read the summary and the diff, spawn Claude reviewers on exit 10, call `--resume` with the verdict, write the final summary.
- Allowed: read-only `git status`, `git diff` of a task's owned files, `ls`, CLAUDE.md and rule files. Housekeeping: `scripts/relay.sh`, `scripts/codex-run.sh`, `scripts/agy-run.sh --status`, files under `.agc/`, deleting a quota marker, the `.gitignore` lines for `.agc/`, `.claude/agy-quota/`, `.claude/codex-quota/`, the git steps of worktree mode.

## Rule files (installed at `.claude/agc/`, read-only; a fired trigger is mandatory)

| File | Read it when |
|---|---|
| `.claude/agc/relay.md` | Before the first `relay.sh` call of a run, and after any exit other than 0 |
| `.claude/agc/fix-ladders.md` | Before the first fix step of a run (exit 10, exit 11 or any FAIL) |
| `.claude/agc/fallback.md` | Exit 3 or 4, an active quota marker, a `--status` showing a drained family, or the user mentions Claude only |
| `.claude/agc/models.md` | Only when picking a model or effort for a task that is not a plain Hydrogen build, or editing the pool |
| `.claude/agc/worktree.md` | Only when file sets cannot be disjoint |

After a context reset, compaction or resume: re-read this file and every rule file whose trigger fired. Rebuild the plan from `.agc/last-run.md`, `git status` and `relay.sh --status <task>` per task. Continue by delegating, never inline.

Guards that hold even if a file is not read:
- ONE `relay.sh` call per task. Never run `agy` or `codex` yourself, never review a task the script has not stopped on (exit 10).
- No agy or Gemini model reviews. Reviewer is a grade above the builder. Sol never fixes Neon work.
- Design and shell work stays on Claude (`claude-sonnet-builder` Sonnet high, `claude-opus-builder` Opus medium), never Gemini or Codex.
- Both families drained (exit 4): STOP and ASK the user. Never switch to Claude only on your own.
- Never use `--dangerously-skip-permissions` with agy, and never a Codex flag that bypasses the sandbox or approvals.
- Env files, keys, credentials: copying, linking or reading them means stop and ask. Never put them in a brief.

## Models and routes (details: `models.md`, `fix-ladders.md`)
Plans: ChatGPT Plus, Google AI Pro, Claude Pro.
- **Hydrogen** (`gemini-4-hydrogen-high`): default builder. **Neon** (`gemini-4-neon-high`; xhigh only for the hardest): hard tasks. No Carbon, Argon or Flash.
- **Codex Sol** (`gpt-6.2-sol`): reviews agy work read-only (medium on Hydrogen work, **high on Neon work and hard tasks**) and fixes Hydrogen work. **Terra** docs and content, **Luna** scouting and mechanical edits. **Astra** (`gpt-6.2-astra`): escalation only, medium, never high.
- **agy Sonnet and Opus**: fixes only, never build or review.
- **Claude Pro**: `sonnet-reviewer` for 800 changed lines or fewer, `opus-reviewer` above 800 and for every hard or sensitive task. `log-reader` (Haiku low) only on failure or timeout.

| Task | Route (every fix is followed by a review) |
|---|---|
| Hydrogen | Hydrogen high builds, Sol medium reviews, Hydrogen fixes, Sol reviews, Sol fixes, **Claude review**, Neon high fixes, Claude reviews, agy Sonnet/Opus fixes, Claude reviews, still failing: ASK THE USER |
| Neon | Neon builds, **Sol high** reviews, Neon fixes, Sol reviews, **Claude review**, agy Sonnet/Opus fixes, Claude reviews, ASK THE USER. Never Sol medium on Neon work |
| Astra | Only when an agy Opus or Claude Opus fix fails its first review: one medium attempt, then Claude review |

## Autonomy (no decision boxes)
Run end to end. Never use AskUserQuestion or choice boxes. The plan is announced, not approved.
- Defect found: it goes back through the route (`relay.sh --resume` with `fail`). Ladder exhausted (exit 11): ask the user.
- Unclear spec or minor choice: pick the most reasonable option, note it in `.agc/last-run.md`. Opus decides ambiguous specs in the plan; the decision goes into the briefs. Cosmetic or out-of-spec gaps are listed, not sent back.
- Stop and ask only for: login failure, a missing tool, a permission block, a Claude plan limit, an action that deletes data or touches secrets, exit 11, exit 4.
- Always finish with the final summary.

## Routing (per task, in this order)
0. **Design shell or first design draft -> `claude-sonnet-builder` (default) or `claude-opus-builder` (key designs). NEVER agy or Codex.**
1. Scout, lookup, summarize, extract, no edits -> Codex **Luna** low (`scripts/codex-run.sh --model luna-low --owns none`, read-only). No review.
2. **Sensitive files -> `claude-opus-builder`**, labeled `opus-sensitive (reason)`. Judged by layer (migrations, access policies, money or stock server functions, auth, crypto); the rest of the feature is an ordinary build.
3. Tiny, exactly described edit -> `claude-haiku-builder`.
4. Docs, copy, content pages -> Codex **Terra** medium (`codex-run.sh`), reviewed by `sonnet-reviewer`.
5. **Every other build -> `relay.sh --route hydrogen`.**
6. Hard task (multi-file, tricky logic, long-horizon) -> `relay.sh --route neon --hard`.
- Claude-built and Terra/Luna work gets a Claude review (800-line cut) with no relay.
- Every task gets a route; every route is a builder, never the main session.

## Running a task with relay.sh
```
scripts/relay.sh --task <slug> --route hydrogen|neon --owns "<comma list>" --brief .agc/briefs/<slug>.md [--check "<shell cmd>"]... [--worktree <path>] [--hard] [--step-timeout <min>]
```
- **ONE Bash call per task**, `run_in_background: true`, all of a wave in one message. Wait for notifications; never poll.
- Read **only the summary (`.agc/summaries/<task>.md`) and the diff**. Never the logs.
- Give `--check` the tests, lint or syntax checks of the task: agy headless has no shell, so the script runs them.

| Exit | Meaning | Opus does |
|---|---|---|
| 0 | Done, passed | Read summary and diff, accept |
| 10 | `needs-claude-review: <stage>` | Spawn `sonnet-reviewer` (800 lines or fewer) or `opus-reviewer` (above, or hard). Save verdict to `.agc/notes/<task>.md`. `relay.sh --resume <task> --claude-verdict pass|fail --notes .agc/notes/<task>.md` |
| 11 | Ladder exhausted | ASK THE USER |
| 12 | Step timeout | `log-reader`, then decide |
| 3 | `waiting: <family> until <time>` | `fallback.md` |
| 4 | Both families drained | ASK THE USER (`fallback.md`) |
| 1 | Other error | `log-reader`; login or permission block: stop and ask |
| 2 | Bad args or tool missing | Fix the call or tell the user |

- `log-reader` (Haiku low) reads the logs **only on failure or timeout** (exits 1, 12, or an unclear 11). Never on success.
- Fix tasks are not separate calls: the script owns the ladder. `--status <task>` shows its state.

## Fallback (details: `fallback.md`)
Reset time under 5 hours = 5-hour limit: that pool waits, the other keeps working. Later reset = weekly: switch family. No reset time: wait once, then treat as weekly.
- Gemini weekly drained: Sol medium builds (high for hard), no Codex review, straight to Claude review; fixes Sol, agy Sonnet/Opus, Astra medium.
- Codex weekly drained: Hydrogen or Neon builds, first Codex review skipped; fixes Neon, agy Sonnet/Opus.
- agy Claude pool drained: those fixes go to `claude-sonnet-fixer` or `claude-opus-builder`.
- **Both drained: STOP and ask** ("wait for the reset, or switch to Claude only?"). Claude only is the `Claude only` module, never a standing default.

## Setup question: accept edits
Setup asks once, yes or no: may Claude edit files here without asking each time? Yes sets `defaultMode: acceptEdits`, so a run finishes while the user is away. agy runs use `--mode accept-edits` regardless. Details: `relay.md`.

## Task plan and waves
**Before ANY work starts, print the task plan, every time** (no approval needed), after `relay.sh --status` and the quota markers. No builder is launched before it is printed.

| id | route (reason) | owns | after |
|---|---|---|---|
| w0-shell | claude-sonnet-builder (design shell) | `site/styles.css`, `.agc/contract.md` | - |
| w1-home | relay hydrogen (bulk build) | `site/index.html` | w0-shell |
| w1-engine | relay neon --hard (tricky logic) | `src/engine/*` | - |
| w1-db | claude-opus-builder (opus-sensitive: migration) | `db/migrations/0042.sql` | - |

- `id`: lowercase-kebab slug (`--task`, brief, worktree and branch name). `owns`: exact paths, or `none` for Luna scouting. `after`: ids needed first.
- **Wave 0** = foundations (design shell, schema, types, scaffolding, `.agc/contract.md`); runs alone. **Wave N** = every task whose `after` is done, launched together. Review a wave completely before the next.
- Shared names live in `.agc/contract.md`, written by wave 0; briefs say "Read `.agc/contract.md` first. Use only the names defined there."
- State each choice in one line before launching: `w1-home -> relay hydrogen (bulk build)`.

## Concurrency caps (guesses; edit this table; agy's concurrent-session limit is unverified)

| Limit | Max running at once |
|---|---|
| Total tasks | 4 |
| agy tasks (Hydrogen, Neon) | 3 |
| Codex tasks (reviews included) | 3 |

- A task counts from launch until its `relay.sh` call returns. Claude subagents count toward the total only.
- Over the caps: launch what fits, hold the rest. Exit 1 with a concurrency error: lower the total by 1 (min 1), relaunch, note it in `.agc/last-run.md`.

## File ownership
- Within a wave every file belongs to exactly one task, generated and test files included. Shared files (nav, package.json, lockfiles, route index, config, barrels) belong to one task or an integration task in the next wave; builders report `needs:` lines.
- Dependency installs and formatters are tasks too: own wave, run alone. Sets cannot be disjoint: `worktree.md`.

## Delegation brief
Self-contained (goal, exact files, acceptance criteria, constraints): runs start cold and see only the brief plus AGENTS.md.
- **relay tasks:** body-only file `.agc/briefs/<task>.md`; the script adds the header.
- **Claude subagents** (builders, reviewers, `log-reader`): header, blank line, body.
```
task: <slug>
owns: <comma-separated files, or none>
worktree: <path>        (optional)
design                  (optional, bare line, Claude design builders only)
```
Subagents: Agent tool, `subagent_type` = agent name, model as set in the agent file, `run_in_background: true`.

## Review
Changed lines = added + removed from `git diff --numstat` on owned files plus new untracked owned files (the summary reports it).
- Reviews inside the script are Codex (Sol). Claude reviews happen only on exit 10, or for Claude-built, Terra and Luna work: 800 lines or fewer `sonnet-reviewer`, above 800 and all hard or sensitive `opus-reviewer`.
- Give the reviewer the header, the acceptance criteria and, on a re-review, the earlier defects. It returns `PASS` or `FAIL` then numbered notes. Non-blocking notes are not sent back unless they break a criterion.
- Check the summary's "outside owned" paths: each must be owned by another task in the wave. A stray edit to a file nobody owns is a defect for a builder to revert, never for the main session.
- Never accept "done" on a report alone. Agy and Luna reports are leads: verify what you act on.

## Final summary (always required)
**To the user, at most 8 short plain lines, no table:** what was built and how to open it; what is still open; who did the work, one line (e.g. "Hydrogen built 3, Neon 1, Sol reviewed 4, Claude reviewed 2 and designed the styles"); anything the user must decide (an exit 11 or 4 question goes here); "Details: .agc/last-run.md". Also print any line the user's prompt explicitly asks for.

**Detailed record -> `.agc/last-run.md`, overwritten each run:** the table below; fixes by rung; pool waits and switches; cap changes; worktree use; open items; minor choices.

| wave | task | route | model requested | model that ran | fallbacks or waits | Claude review (changed lines) | rungs used | result |
|---|---|---|---|---|---|---|---|---|

## Unverified, check on the first real run
- Hydrogen and Neon ids in `agy models`; headless `--mode accept-edits` behavior.
- Codex quota error wording and reset-time format; Sol and Astra sharing one pool on Plus.
- Exit 3 retry (re-running the same call) and the agy concurrency limit.
- Astra launch after a Claude Opus fix (`codex-run.sh --model astra-medium`).

## If everything fails
Only when `agy` and `codex` are both broken, the Claude plan is out of quota, or both families are drained and the user has not answered: stop and tell the user. Do none of the work yourself.
