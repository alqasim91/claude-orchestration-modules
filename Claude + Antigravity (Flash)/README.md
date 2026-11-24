# Claude + Antigravity (Flash): Flash builds the small pieces, Neon builds the rest

**How this differs from the other Claude + Antigravity setups:** Gemini Flash (high) builds first. Any task that splits into small, exact pieces goes to Flash, which spares the costlier Gemini 4 models. Gemini 4 Neon then builds only what can't be spelled out exactly, and it fixes Flash's work when a review fails. Gemini 4 Carbon is the escalation step when Neon's fix fails.
Not sure which Claude + Antigravity setup to use? Pick this one if your Gemini quota runs out fast. Pick a setup where Neon builds everything if you want the strongest model on every task.

**One Gemini quota.** Every Gemini model in Antigravity (Flash, Neon, Carbon) draws on ONE shared quota. Claude and GPT models in `agy` (Sonnet, Opus) are a separate pool. So when Gemini runs dry, no other Gemini model can take over.

Claude Opus is the boss. It splits your request into tasks, and each task into small mini-tasks when it can write an exact spec for every piece. Builds go out through the Antigravity CLI (`agy`), straight from a script (`scripts/agy-run.sh`) with no helper agent in between, and run at the same time. Launching an Antigravity model costs no Claude usage. Design, reviews and the later fix steps stay on your Claude plan.

# Part 1: Setup

Short on time? Skip to Step 4 (Install the files): Claude Code can do most of this for you.

Do the steps in order. Each step shows **Mac** (Terminal) and **Windows** (PowerShell).

## Step 1. Get your two plans
- **Google AI Pro**: subscribe with the Google account you will use for `agy`. Your Antigravity builders run on this plan.
- **Claude Pro**: the plan you already use to sign in to Claude Code. Design, reviews and fixes run on it.

## Step 2. Install `agy`
**Mac**
```bash
curl -fsSL https://antigravity.google/cli/install.sh | bash
agy --version
```
**Windows (PowerShell)**
```powershell
irm https://antigravity.google/cli/install.ps1 | iex
agy --version
```
You should see a version number. If the command is not found, close the terminal, open a new one, and try again.

## Step 3. Log in
```
agy
```
1. Choose **Google OAuth**.
2. Sign in with your AI Pro account in the browser.
3. Quit `agy`, then check your models:
```
agy models
```
Make sure these six are in the list:
- `gemini-3.8-flash-high`
- `gemini-4-neon-high`
- `gemini-4-carbon-high`
- `gemini-3.8-flash-medium`
- `claude-sonnet-5-5-medium`
- `claude-opus-5-5-medium`

## Step 4. Install the files (one command)

**Easiest: let Claude Code set it up**

1. Put `claude-antigravity-flash-files.zip` in your project folder.
2. Open the Claude desktop app. Click **New session** and pick your project folder.
3. Paste this line:
   ```
   Unzip claude-antigravity-flash-files.zip in this folder, then read claude-antigravity-flash/SETUP.md and follow it.
   ```

Claude Code unzips the files, asks you one question (may it edit files without asking each time), installs the module, checks the outside tools and tells you what is left. It will ask your approval for the first one or two commands; that is normal, the approvals list does not exist yet. Signing in to `agy` stays with you, because it opens a browser. When it finishes, start a new session and choose Opus.

**Or run the installer yourself**

Unzip `claude-antigravity-flash-files.zip` **inside your project folder** (it creates a `claude-antigravity-flash` folder). Open a terminal in the project folder. Run one command.

**Mac**
```bash
bash claude-antigravity-flash/install.sh
```
**Windows (PowerShell)**
```powershell
powershell -ExecutionPolicy Bypass -File claude-antigravity-flash\install.ps1
```
It prints one line per step. Running it again is safe: it changes nothing the second time.

The installer asks one question: may Claude edit files in this folder without asking each time? Answer `y` for runs you can leave alone, or `n` to approve each edit yourself. To answer yes up front, add `--accept-edits` to the Mac command or `-AcceptEdits` to the Windows command. You can change it later in `.claude/settings.json`.

**What it does**
- Copies the 7 agents to `.claude/agents/` and the 5 rule files to `.claude/m6/`.
- Copies `scripts/agy-run.sh` and makes it runnable.
- Copies `CLAUDE.md` and `AGENTS.md`. If you already have your own, it does not overwrite them: it saves the new text as `CLAUDE.claude-antigravity-flash.md` and tells you to paste it in. An older Claude + Antigravity (Flash) copy is backed up and replaced.
- Adds the approvals list to `.claude/settings.json` (merged, your other settings stay).
- Asks the one edit question described above and, only if you say yes, sets `"defaultMode": "acceptEdits"` in that file.
- Adds two lines to `.gitignore` (`.claude/agy-quota/` and `.m6/`).
- Starts git and makes a first commit if the folder has none. It never touches your `.env` files.
- Checks that `agy` is installed and tells you how to get it if not.

<details>
<summary>Manual install (only if you prefer to copy by hand)</summary>

**Mac**
```bash
mkdir -p .claude/agents .claude/m6 .claude/agy-quota scripts
cp claude-antigravity-flash/CLAUDE.md claude-antigravity-flash/AGENTS.md .
cp claude-antigravity-flash/agents/*.md .claude/agents/
cp claude-antigravity-flash/rules/*.md .claude/m6/
cp claude-antigravity-flash/scripts/agy-run.sh scripts/
chmod +x scripts/agy-run.sh
cp claude-antigravity-flash/settings.json .claude/settings.json
printf '.claude/agy-quota/\n.m6/\n' >> .gitignore
git init && git add -A && git commit -m "start"
```
**Windows (PowerShell)**
```powershell
New-Item -ItemType Directory -Force .claude\agents, .claude\m6, .claude\agy-quota, scripts | Out-Null
Copy-Item claude-antigravity-flash\CLAUDE.md, claude-antigravity-flash\AGENTS.md .
Copy-Item claude-antigravity-flash\agents\*.md .claude\agents\
Copy-Item claude-antigravity-flash\rules\*.md .claude\m6\
Copy-Item claude-antigravity-flash\scripts\agy-run.sh scripts\
Copy-Item claude-antigravity-flash\settings.json .claude\settings.json
Add-Content .gitignore ".claude/agy-quota/", ".m6/"
```
Already have a `CLAUDE.md`, `AGENTS.md` or `.claude/settings.json`? Do not overwrite them: paste the new text into your file. Not using git yet? The review step reads `git diff`, so run `git init && git add -A && git commit -m "start"` once.
Want Claude to edit files here without asking each time? Add `"defaultMode": "acceptEdits"` inside `"permissions"` in `.claude/settings.json`.
</details>

**Check it worked:** `ls -la .claude/agents .claude/m6 scripts`. You should see:
- 7 agents: `claude-sonnet-builder`, `claude-opus-builder`, `claude-sonnet-fixer`, `claude-haiku-builder`, `scout`, `sonnet-reviewer`, `opus-reviewer`.
- 5 files in `.claude/m6/`: `fix-ladders.md`, `drained-pools.md`, `safety-switch.md`, `worktree.md`, `models.md`.
- One executable script: `agy-run.sh`.

`.claude` is hidden, so Finder won't show it (press `Cmd+Shift+.` to show hidden files). "No such file" means the terminal was not in the project folder: run `cd ` (with a space), drag the project folder into Terminal, press Enter, and run the commands again.

## Step 5. Start Claude Code and check the agents
```
claude
```
Inside Claude Code, type `/agents`. You should see the 7 agents: `claude-sonnet-builder`, `claude-opus-builder`, `claude-sonnet-fixer`, `claude-haiku-builder`, `scout`, `sonnet-reviewer` and `opus-reviewer`. Not there? Quit `claude`, start it again, and re-check Step 4. Then check the script can see its quota markers:
```
scripts/agy-run.sh --status
```
It should print `agy: 0 models limited`.

## Step 6. Run a test prompt
1. Open `claude-antigravity-flash/test-prompt.md`.
2. Copy **Prompt A** (the Driftwood site) or **Prompt B** (the Orbit Catch game) into Claude Code, unchanged.
3. Watch for: a task plan table first, the design shell built by `claude-sonnet-builder` or `claude-opus-builder` (never by `agy`), page and script tasks split into Flash-high mini-tasks launched together, ONE Sonnet review per task (after all its mini-tasks), and a short final message. The main chat itself edits no project files and reads no full diff.

## Approvals
The installer adds an allow-list to `.claude/settings.json`: the runner script, read-only git commands and the `.m6/` run folder. So a run does not stop to ask for each launch. It also blocks reading `.env` files. The installer also asks one question: may Claude edit files in this folder without asking each time? Yes sets `"defaultMode": "acceptEdits"` in that file (`--accept-edits` on Mac or `-AcceptEdits` on Windows answers yes up front); no leaves every edit asking as usual. Never add `--dangerously-skip-permissions`.

# Part 2: How it works

**The main chat stays clean on purpose.** Opus is the head chef who never touches a pan: it only plans and judges, and every line of code gets cooked in a sub-agent.

## The cast
| Who | Role |
|---|---|
| **Opus** (your Claude session) | The boss. Only plans and judges: launches sub-agents, reads their short reports, and never edits files, runs builds or reads a full diff. |
| **Flash high** (`gemini-3.8-flash-high`) | The first-choice builder. Gets small mini-tasks with an exact spec (files, names, markup, a check to run). Light on the shared Gemini quota. Never fixes or reviews. |
| **Neon** (`gemini-4-neon-high`) | Builds what Opus can't spec exactly (high by default; `xhigh` only for the hardest tasks). Also the first fixer of Flash's work. Shares the Gemini quota with Flash and Carbon. |
| **Carbon** (`gemini-4-carbon-high`; also `-medium`, never low or xhigh) | The escalation step when Neon's fix fails review, and for tasks that need long-horizon hard reasoning. About 2x slower than Neon and it burns the shared quota faster: used sparingly. |
| **Sonnet / Opus via agy** | Specialists for non-design builds. Sonnet for careful edits and docs. Opus for hard multi-file work. Small pools. |
| **Flash scout** (`gemini-3.8-flash-medium`) | Read-only: lookups, summaries, checks. Light on the shared Gemini quota. |
| **`scripts/agy-run.sh`** | The runner script. Sends one task or mini-task to one Antigravity model, follows the fallback chain, and reports what changed. It refuses design. |
| **`claude-sonnet-builder`** | Design shells and first drafts (Sonnet high). Fix step 2 for work agy Sonnet or agy Opus built, step 3 for Neon-built work, step 1 for Carbon-built work. |
| **`claude-opus-builder`** | Sensitive work (migrations, access policies, money and stock functions, auth, crypto) and the most important designs (Opus medium). Last fix step for agy-built, Neon-built and Flash-built work. |
| **`claude-sonnet-fixer`** | Fix step 3 for Flash-built work (Sonnet medium), the first step if the Gemini pool is drained. Fixes only. |
| **`sonnet-reviewer`** | Reads one task's diff of 400 changed lines or fewer. Returns PASS or FAIL. |
| **`opus-reviewer`** | Reads one task's diff of more than 400 changed lines (Opus medium). Returns PASS or FAIL. |
| **`claude-haiku-builder`** | Tiny, exactly described edits. In Claude only mode: easy builds. |
| **`scout`** | Claude only mode only: all read-only work. |

Everything in the Claude rows runs on your Claude plan. No Antigravity model ever reviews.

## A build in 5 beats
```
 1 PLAN        Opus prints a task table first, before any work: id, model, owned files, after
      |
 2 WAVE 0      design shell alone, built by Claude (Sonnet high or Opus medium)
      |
 3 WAVE 1+     tasks run in parallel: Flash-high mini-tasks when Opus can spec them
               exactly, Neon when it can't. One owner per file
      |
 4 SCOUTS      Flash checks links, leftovers, accessibility
      |
 5 REVIEW      once per task, after all its mini-tasks: Sonnet reviews small diffs,
               an Opus reviewer reads big ones; defects go back for fixing
```
- **One owner per file.** Two tasks never touch the same file in a wave. Mini-tasks on the same file run one after another.
- **Flash first.** While planning, Opus checks every non-design build task: can I write an exact spec for each small piece? Yes (4 mini-tasks by default, more if needed) means Flash high, with no question to you. No means Neon (high; Carbon high only for long-horizon hard reasoning).
- **Waves.** Each wave is reviewed fully before the next one starts.
- **Sensitive files go to `claude-opus-builder`** (Opus medium, on your Claude plan): database migrations, access policies, functions that move money or stock, auth and crypto. It is judged by layer: the screens, types and labels of the same feature are ordinary builds.
- **Tiny edits go to `claude-haiku-builder` (or Flash, when the edit can be specced exactly).** Opus itself never edits, not even a one-liner. Unclear specs and architecture choices: Opus decides them in the plan, then delegates.
- **Design never goes to Antigravity** (not Flash, Neon or Carbon). Shells and first design drafts always go to a Claude builder.

## Who reviews
Opus counts the changed lines of the task (added plus removed, plus new files). A task built from mini-tasks is reviewed ONCE, after all its mini-tasks finish, on the combined diff, never per mini-task.

| Changed lines | Reviewer |
|---|---|
| 400 or fewer | `sonnet-reviewer` |
| More than 400 | `opus-reviewer` (Opus medium) |

Same rule for every builder, `claude-opus-builder` included. The main chat never reads the full diff, only the verdict. Flash never reviews. If a fix pushes a task over 400, the next review moves up to `opus-reviewer`.

## When a review fails
Up to 4 steps. Who fixes depends on who built it.

| Built by | Step 1 | Step 2 | Step 3 | Step 4 |
|---|---|---|---|---|
| Flash | Neon high (`gemini-4-neon-high`) | Carbon high (`gemini-4-carbon-high`) | `claude-sonnet-fixer` (Sonnet medium) | `claude-opus-builder` (Opus medium) |
| Neon | Neon again | Carbon high | `claude-sonnet-builder` (Sonnet high) | `claude-opus-builder` (Opus medium) |
| Carbon | `claude-sonnet-builder` (Sonnet high) | `claude-opus-builder` (Opus medium) | record and continue | - |
| agy Sonnet or agy Opus | the same model | `claude-sonnet-builder` (Sonnet high) | `claude-opus-builder` (Opus medium) | - |
| `claude-sonnet-builder` (design) | the same agent | `claude-opus-builder` | record and continue | - |
| `claude-opus-builder` (design or sensitive) | the same agent | record and continue | - | - |
| `claude-haiku-builder` (tiny edit) | the same agent | `claude-sonnet-builder` | `claude-opus-builder` | - |

- Gemini quota drained? Flash, Neon and Carbon are all drained together, so skip straight to the Claude steps. No other Gemini model takes over.
- Flash never fixes and never reviews. Neon and Carbon get the whole task's diff and the defect list, and fix the whole task.
- Carbon only ever runs as `carbon-high` (or `-medium`). Never `carbon-low`: it costs more per task than the higher efforts.
- Still failing after the last step? It goes in the final summary and the build keeps going.

## The Flash safety switch
Opus keeps score. From the 3rd reviewed Flash-built task on, if more than 1 in 3 failed their first review, Opus stops sending new tasks to Flash for the rest of that run. Those tasks go to Neon high instead, and Opus says so in the plan and the final summary.

## When quota runs out
- A drained pool gets a marker file in `.claude/agy-quota/` with a reset time: `gemini-pool` (Flash, Neon and Carbon together) or `claude-pool` (agy Sonnet and Opus). A "not available" error marks only that one model, by its id. If agy gives no reset time, the script uses 6 hours from now (a guess). Opus skips it until then. Check with `scripts/agy-run.sh --status`. Delete a marker to clear it.
- A Neon or Carbon build moves to agy Sonnet, then agy Opus, by itself in the script (there is no Gemini fallback: the Gemini quota is shared). An agy Sonnet build moves to Neon, then Opus.
- **Gemini and agy Claude pools both drained?** Tasks that need either are held, and Opus asks you ONE question: **"wait for the reset, or switch to Claude only?"** It never switches on its own. Only the agy Claude pool drained: Flash and Neon keep building as usual.
- **Flash drained on a build** (the whole Gemini quota is)? Opus stops and asks: **"Flash is drained. Wait for the reset, or switch to Claude only?"**
- **Claude only mode.** Claude builds the rest, with no Antigravity. Opus scores each task, then picks `claude-haiku-builder` (easy), `claude-sonnet-builder` (normal and design) or `claude-opus-builder` (hardest). Read-only work goes to `scout`. Reviews use the same 400-line rule.

# Part 3: Good to know

- **No relay.** Antigravity models are launched by `scripts/agy-run.sh`. The main chat only reads its short report.
- **Run folder.** `.m6/` holds the briefs, the logs, the shared contract (`contract.md`) and the detailed table of the last run (`last-run.md`). It is git-ignored and safe to delete between runs.
- **Shared contract.** The names every Flash piece must agree on (classes, ids, functions) live in `.m6/contract.md`. Each brief points to it instead of repeating the list.
- **The final message is short.** A few plain lines. Details are in `.m6/last-run.md`.
- **Rule files.** Rarely needed rules live in `.claude/m6/`. Opus reads them only when needed, which keeps every message cheaper.
- **agy runs have no shell.** Headless `agy` (`--mode accept-edits`) edits files but denies shell commands, so the models can't run tests. The reviewer runs the safe, read-only checks.
- **Parallel runs drain quota faster.** Several models spend your Google quota at once. Prefer fewer, bigger tasks.
- **Default caps:** 4 tasks total (neon 2, carbon 1, flash 3, agy sonnet 1, agy opus 1). Claude subagent runs count toward the total only. Edit the caps table in `CLAUDE.md`.
- **Flash high spares Neon and Carbon.** Most of the building runs on Flash, which draws less of the shared Gemini quota per task. Neon spends quota only on tasks that can't be split and on fixing Flash's mistakes; Carbon (about $7.76 per task against Neon's $3.74, and about 2x slower, on Artificial Analysis Nov 2026 numbers) only when Neon's fix failed or the task needs long-horizon hard reasoning.
- **Design, sensitive builds, reviews and the Sonnet and Opus fix steps use your Claude plan**, not Google quota. Watch your Claude usage too.
- **Review every diff.** File ownership is enforced by instructions, not the filesystem. Fallbacks can switch models mid-task.
- **Unverified:** whether `agy` allows concurrent sessions, the real quota error text, whether the `effort` setting in the Claude agent files is honored, and whether the script flow works on Windows (the script is a bash script, so it likely needs Git Bash). The script was tested against a stand-in `agy`, not the real tool.
- **After a context reset** the main chat re-reads `CLAUDE.md`, re-prints the plan with each task's status, and keeps delegating. It never carries on inline.
- **Secrets stay out.** Copying, linking or reading `.env` files, keys or credentials makes Claude stop and ask, and sub-agents follow the same rule. Sub-agents may test migrations only on a local throwaway database.
- **A summary always arrives**, even when all the work went to one sub-agent.
