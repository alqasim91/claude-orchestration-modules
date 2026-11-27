# Claude + Antigravity + Codex: Gemini and Codex build and review each other, Claude judges

**Three plans, one loop.** Gemini 4 Hydrogen and Neon (through `agy`, Google AI Pro) build. GPT 6.2 Sol (through `codex exec`, ChatGPT Plus) reviews read-only. A script, `scripts/relay.sh`, runs the whole build, check, review, fix loop with no Claude in between. Claude Opus only plans, then makes ONE call per task and reads the summary and the diff. Claude Pro does design, shell work, the Claude reviews and the last fix rungs.

Not sure which module to use? Pick this one if you have Google AI Pro, ChatGPT Plus and Claude Pro. With only two of the three, pick Claude + Antigravity (Hydrogen) or Claude + Codex.

Claude Opus is the boss. It never edits files, not even a one-liner, and never runs builds. Even Opus-level work runs in a subagent.

## Who does what

| Model | Runs through | Role |
|---|---|---|
| Hydrogen high (`gemini-4-hydrogen-high`, alias `hydrogen`) | `agy` | Default builder. Fixes its own work once. Never reviews. |
| Neon high (`gemini-4-neon-high`, alias `neon`) | `agy` | Hard tasks (xhigh only for the hardest). Fixes Hydrogen's work. Never reviews. |
| Sol (`gpt-6.2-sol`) | `codex exec` | Reviewer: medium for Hydrogen work, high for Neon work and hard tasks, always read-only. Also fixes Hydrogen work and builds when Gemini is drained. |
| Terra | `codex exec` | Docs and content. |
| Luna | `codex exec` | Scouting and mechanical work. |
| Astra (`gpt-6.2-astra`) | `codex exec` | Escalation only, medium only, never high. Used when an Opus fix fails the first time. |
| Sonnet 5.5 and Opus 5.5 inside agy | `agy` | Fixes only. Never build, never review. |
| Claude Sonnet and Opus subagents | Claude Pro | Design, shell work, sensitive work, reviews (Sonnet up to 800 changed lines, Opus above 800 and for hard or sensitive tasks), and fixes when the agy Claude pool is drained. |
| Haiku low (`log-reader`) | Claude Pro | Reads logs ONLY after a failure or timeout. |

Design and shell work stay on Claude (Sonnet high or Opus medium, through an agent). They never go to Gemini or Codex. No Carbon, Argon or Flash in this module.

# Part 1: Setup

You only use the Claude desktop app. Claude does the setup for you.

## Step 1. Get your three plans
- **Google AI Pro**: your Antigravity builders. Sign in with this Google account.
- **ChatGPT Plus**: your Codex reviewers and fixers.
- **Claude Pro**: design, Claude reviews, the last fix rungs.

## Step 2. Let Claude set it up
1. Put `claude-antigravity-codex-files.zip` in your project folder.
2. Open the Claude desktop app. Click **New session** and pick your project folder.
3. Paste this line:
   ```
   Unzip claude-antigravity-codex-files.zip in this folder, then read claude-antigravity-codex/SETUP.md and follow it.
   ```

Claude unzips the files, asks you one question (may it edit files without asking each time), installs the module, checks for `agy` and `codex` and their sign-in, and tells you what is left. It asks your approval for the first one or two commands; that is normal. Both sign-ins happen in your browser. When it finishes, start a new session and choose Opus.

**The installer command (Claude runs it for you).** Mac, Linux or Git Bash: `bash claude-antigravity-codex/install.sh`. Windows without bash: `powershell -ExecutionPolicy Bypass -File claude-antigravity-codex\install.ps1`. `--accept-edits` (Windows: `-AcceptEdits`) answers the edit question with yes, `--no-accept-edits` (`-NoAcceptEdits`) with no. Running it again is safe.

**What the setup does**
- Copies the agents to `.claude/agents/` and the rule files to `.claude/agc/`.
- Copies `scripts/relay.sh`, `agy-run.sh` and `codex-run.sh` and makes them runnable.
- Copies `CLAUDE.md` and `AGENTS.md`. If you already have your own, it does not overwrite them: it saves the new text as `CLAUDE.claude-antigravity-codex.md` and Claude asks whether to put it at the top of your file.
- Merges the approvals list into `.claude/settings.json` (your other settings stay). A yes to the edit question also sets `"defaultMode": "acceptEdits"`.
- Adds `.claude/agy-quota/`, `.claude/codex-quota/` and `.agc/` to `.gitignore`.
- Starts git and makes a first commit if the folder has none. It never touches your `.env` files.
- Checks `agy`, `codex` and the Codex login. Claude offers to install what is missing.

## Step 3. Try it
Start a new session in the project folder, choose Opus, and paste the prompt from `claude-antigravity-codex/test-prompt.md`, unchanged.

## Approvals
The allow-list covers `scripts/relay.sh`, `agy-run.sh`, `codex-run.sh`, read-only git commands and the `.agc/` run folder. It blocks reading `.env` files. Never add `--dangerously-skip-permissions`. The scripts use only confirmed `agy` flags (`-p`, `--model`, `--print-timeout 0`, `--mode accept-edits`) and never a Codex flag that bypasses the sandbox or approvals.

# Part 2: How it works

## Routes
Every fix is followed by a review. A reviewer answers `PASS` or `FAIL` on the first line, then numbered notes (`file:line`, problem, required change). The notes go verbatim into the next fix prompt.

| Step | Hydrogen task | Neon task |
|---|---|---|
| Build | Hydrogen high | Neon high |
| Review 1 | Sol medium (read-only) | Sol HIGH (read-only) |
| Fix 1 | Hydrogen | Neon |
| Review 2 | Sol | Sol |
| Fix 2 | Sol | Claude review, then agy Sonnet/Opus fix |
| Review 3 | Claude (Sonnet or Opus) | Claude |
| Fix 3 | Neon high | Ask the user |
| Review 4 | Claude | |
| Fix 4 | agy Sonnet/Opus | |
| Review 5 | Claude | |
| Still failing | Ask the user | |

- Sol never reviews Neon work at medium and never fixes Neon work.
- Astra (medium) is consulted only when an agy Opus or Claude Opus fix fails the first time.
- Claude reviews: Sonnet for 800 changed lines or fewer, Opus above 800 and for every hard or sensitive task. The main chat never reads a full diff.
- Codex reviews run `codex exec --sandbox read-only`.
- Details live in `.claude/agc/fix-ladders.md`.

## The relay script
`scripts/relay.sh --task <slug> --route hydrogen|neon --owns "<files>" --brief <file> [--check "<cmd>"]...` runs the loop with no Claude in between. agy headless has no shell, so the script runs your checks itself. Claude makes ONE Bash call per task and reads only the summary (`.agc/summaries/<task>.md`) and the diff.

| Exit | Meaning |
|---|---|
| 0 | Done, passed, no more review needed |
| 10 | Needs a Claude review (`needs-claude-review: <stage>`). Review, then `relay.sh --resume <task> --claude-verdict pass\|fail --notes <file>` |
| 11 | Ladder exhausted: ask the user |
| 12 | Step timeout (default 30 minutes) |
| 3 | Pool wait (`waiting: <family> until <time>`) |
| 4 | Both families drained: ask the user |
| 1 / 2 | Other error / bad args or tools missing |

Progress is in `.agc/status/<task>.json`. `relay.sh --status <task>` prints it. Haiku low (`log-reader`) reads logs only on failure or timeout.

## Quota and fallback
One marker per pool, in `.claude/agy-quota/` (`gemini-pool` for all Gemini models, `claude-pool` for agy Sonnet and Opus) and `.claude/codex-quota/` (`5h`, `weekly`). The script reads the reset time from the quota error.
- Reset less than 5 hours away: a 5-hour limit. That pool's tasks wait while the other pool keeps working.
- Later reset: a weekly limit. Switch family.
- No reset time found: wait once, then treat it as weekly.

| Drained | What happens |
|---|---|
| Gemini weekly | Sol builds (medium, high for hard), no Codex review step, straight to Claude review. Fixes go Sol, agy Sonnet/Opus, Astra medium. |
| Codex weekly | Hydrogen/Neon build, the first Codex review is skipped, straight to Claude review. Fixes go Neon, agy Sonnet/Opus. |
| agy Claude pool | Those fixes move to Claude Pro Sonnet/Opus subagents. |
| Both families | STOP and ask you before switching to Claude only. Never a standing default. |

"Claude only" means the Claude only module. Details in `.claude/agc/fallback.md`.

# Part 3: Good to know

- **Run folder.** `.agc/` holds briefs, status, summaries and logs. It is git-ignored and safe to delete between runs.
- **Parallel tasks** use separate files, or a worktree when needed (`.claude/agc/worktree.md`).
- **Plan first.** Opus prints a plan table before the first edit and always ends with a summary.
- **After a context reset** the main chat re-reads `CLAUDE.md` and the rule files, then keeps delegating.
- **Secrets stay out.** Env files, keys and credentials make Claude stop and ask. Subagents follow the same rule.
- **Shared quotas.** All Gemini models share ONE pool. Parallel runs drain it faster.
- **Review every diff.** File ownership is enforced by instructions, not the filesystem.
- **Unverified, check on the first real run:** the Hydrogen and Neon model ids, whether `agy` opens the browser sign-in from Claude, whether `agy` allows concurrent sessions, the Codex quota error wording and reset-time format, whether Sol and Astra share one pool on Plus, whether the `effort` setting in the agent files is honored, and whether the scripts run on Windows (they are bash scripts, so Git Bash is likely needed).
