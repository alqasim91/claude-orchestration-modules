# Claude + Antigravity + Opencode (Hydrogen): Claude plans, Antigravity Hydrogen builds, OpenCode free models take the overflow, Neon takes the hard tasks, Carbon escalates

Claude Opus is the boss. It splits your request into phases and tasks and sends each task to the right pool:
- **Antigravity Hydrogen** (`gemini-4-hydrogen-high`) is the default builder. It takes every task that splits into small, exact pieces and the bulk work that cannot be specced exactly (docs, copy, standard logic, tests). It scored below Neon and Carbon on one index (secondary source, unverified).
- **OpenCode free models** are the overflow and fallback: they take Hydrogen's work silently when Hydrogen runs dry, and they handle scouting, image/audio/large-context work.
- **Neon** (Antigravity, `gemini-4-neon-high`) takes the hard tasks and the second fix try for Hydrogen's work. **Carbon** (`gemini-4-carbon-high`) is the escalation after Neon fails review and for long-horizon hard reasoning: about 2x slower and heavier on quota, so it is used sparingly. There is no Gemini fallback when the shared quota is drained: OpenCode takes over silently. **agy Sonnet and agy Opus** take fix rounds only. **Flash** is only a scout fallback now: it shares Hydrogen's quota, so it cannot build in its place.
- **Your Claude plan** does design, sensitive work, every review, and fix steps when agy Sonnet or Opus is drained.
- **Claude only** (Claude only) is the last fallback, only when you say so.

Hydrogen, Neon, Carbon, Flash, agy Sonnet and agy Opus run through `scripts/agy-run.sh`, straight from a script, with no helper agent in between. OpenCode runs the same way through `scripts/opencode-run.sh`. So launching an outside model costs no Claude usage.

It is Claude + Antigravity + Opencode (Flash) with Hydrogen as the builder (Claude + Antigravity + Opencode (Flash) used Flash high and sent the rest to OpenCode). Same rules as before: the main chat never implements, reviews by diff size (800 lines), "Phases", no decision boxes except one question when pools are drained.

# Part 1: Setup

You only use the Claude desktop app. Claude does the setup for you.

## Step 1. Your plans
- **Google AI Pro** for Antigravity (Hydrogen, Neon, Carbon, Flash, agy Sonnet and Opus).
- **Claude Pro** for Claude Code (design, reviews, fixes).
- **OpenCode**: no plan needed. The free models are free, for a limited time.

## Step 2. Let Claude set it up
1. Put `claude-antigravity-opencode-hydrogen-files.zip` in your project folder.
2. Open the Claude desktop app. Click **New session** and pick your project folder.
3. Paste this line:
   ```
   Unzip claude-antigravity-opencode-hydrogen-files.zip in this folder, then read claude-antigravity-opencode-hydrogen/SETUP.md and follow it.
   ```

Claude unzips the files, asks you one question (may it edit files without asking each time), installs the module, installs `agy` and `opencode` if they are missing (it asks first), checks them and tells you what is left. It will ask your approval for the first one or two commands; that is normal, the approvals list does not exist yet. Signing in to Antigravity with your Google account happens in your browser; Claude starts it and tells you when to finish it (if no browser opens, Claude asks you to sign in in the Antigravity app). OpenCode free models need no sign-in. When it finishes, start a new session and choose Opus.

**What the setup does**
- Copies the 7 agents to `.claude/agents/` and the rule files to `.claude/m11/`.
- Copies `scripts/agy-run.sh` and `scripts/opencode-run.sh` and makes them runnable.
- Copies `CLAUDE.md` and `AGENTS.md`. If you already have your own, it does not overwrite them: it saves the new text as `CLAUDE.claude-antigravity-opencode-hydrogen.md` and Claude asks whether to put it at the top of your file. An older Claude + Antigravity + Opencode (Hydrogen) copy is backed up and replaced.
- Adds the approvals list to `.claude/settings.json` (merged, your other settings stay). If you say yes to the edit question, it also sets `"defaultMode": "acceptEdits"` there.
- Adds three lines to `.gitignore`. Starts git and makes a first commit if the folder has none. It never touches your `.env` files.

**The installer command (Claude runs it for you, you do not type it).** On Mac, Linux or Git Bash: `bash claude-antigravity-opencode-hydrogen/install.sh`. On Windows without bash: `powershell -ExecutionPolicy Bypass -File claude-antigravity-opencode-hydrogen\install.ps1`. Adding `--accept-edits` (Windows: `-AcceptEdits`) answers the edit question with yes, `--no-accept-edits` (`-NoAcceptEdits`) with no. Running it again is safe: it changes nothing the second time.

Both `agy` and `opencode` read `AGENTS.md`, which is how the other models get the rules.

## Step 3. Try it
Start a new session in the project folder, choose Opus, and paste a prompt from `claude-antigravity-opencode-hydrogen/test-prompt.md`.

## Approvals
The setup adds an allow-list to `.claude/settings.json`: the two runner scripts, read-only git commands and the `.m11/` run folder. So a run does not stop to ask for each launch. It also blocks reading `.env` files. It never adds `--auto` or `--dangerously-skip-permissions`.

## Models this module uses
- `agy` (Google AI Pro): `gemini-4-hydrogen-high` (plus `-low`, `-medium`, `-xhigh`), `gemini-4-neon-high` (plus `-low`, `-medium`, `-xhigh`), `gemini-4-carbon-high` (plus `-medium`; never carbon-low or carbon-xhigh), `gemini-3.8-flash-medium`, `claude-sonnet-5-5-medium`, `claude-opus-5-5-medium` (the last two for fix rounds only).
- OpenCode free models, checked 2026-11-04: `beam-free`, `big-pickle`, `crouton-alpha-free`, `deepseek-v4.1-flash-free`, `flint-40b-free`, `glm-5.3-flash-free`, `mimo-v2.6-flash-free`, `nemotron-3.5-lightning-free`, `nemotron-3.5-super-vl-free`, `pulse-alpha-free`. The script asks OpenCode which free models exist at run time, so the list needs no upkeep.

# Part 2: How it works

## Who builds what
| Task kind | First choice | If drained |
|---|---|---|
| Design shell, first design draft | Claude Sonnet high (Opus medium for key designs) | never waits |
| Sensitive files (migrations, access policies, money functions, auth, crypto) | Claude Opus medium | never waits |
| Tiny exact edit | Claude Haiku (or one Hydrogen mini-task) | never waits |
| Read-only scouting | OpenCode `scout` | Flash scout, else held |
| Splits into exact mini-tasks | **Hydrogen high** | OpenCode `build` (silent), then Neon high as a last resort (only when Hydrogen is tripped) |
| Not hard, cannot be specced exactly (docs, logic, tests) | **Hydrogen high** (whole task) | OpenCode `build` (silent), then the same last resort, else held |
| Hard (D = 2, two 2s, or A = 2 with C = 2) | **Neon** | Carbon high, then OpenCode `hard` (silent) |
| A failed review | see the fix table below: Hydrogen, Neon, agy Sonnet, agy Opus, OpenCode | Claude Sonnet / Opus of the same tier (silent) |
| Images, audio/video, over 150k tokens | OpenCode `vision` / `av` / `large` | held |

## Hydrogen, Neon, Carbon, Flash and Sonnet 5.5 at a glance
| | Hydrogen | Neon | Carbon | Flash 3.8 | Claude Sonnet 5.5 |
|---|---|---|---|---|---|
| Artificial Analysis index (Nov 2026) | 51 (high) | 61 (xhigh) / 60 (high) | 60 (high) | 31 | 55 |
| Cost per task | n/a | $3.74 (high) | $7.76 (high), about 2x slower | n/a | n/a |
| Terminal-Bench 4.0 | 54% | 63.6% | beats Neon here only | n/a | 64% |
| Price per M tokens (in / out) | $1.50 / $7.50 | $3 / $15 | n/a | n/a | n/a |
| Quota pool | Gemini Models | Gemini Models | Gemini Models | Gemini Models | Claude plan |
| Role here | default builder | hard tasks, second fix try | escalation after Neon, long-horizon work | scout fallback | design, reviews, fixes |

Hydrogen scored below Neon and Carbon on one index (secondary source, unverified) and is reported weaker on terminal and long-horizon work, which is why hard tasks go to Neon. These figures are secondary and unverified (third-party indexes and press numbers); do not rely on them for anything that matters. Neon's default effort is high (`neon-xhigh` for the hardest tasks): hard work is where reasoning effort pays, and xhigh spends the most of the shared Gemini quota.

## Quota pools
ALL Gemini models (Hydrogen, Neon, Carbon, Flash) share ONE quota (a weekly limit plus a 5-hour limit, as the Antigravity usage screen of the Google AI Pro plan shows). They share ONE marker, `.claude/agy-quota/gemini-pool`: when any of them hits its limit, all are skipped until the reset (a "not available to" error marks only that one model). agy Sonnet and Opus are a second pool, with their own markers. OpenCode keeps a marker per model in `.claude/opencode-quota/`. Neon work spends the same budget as Hydrogen builds, so a run of hard tasks can drain the pool for builds too.
- Check any time: `scripts/agy-run.sh --status` and `scripts/opencode-run.sh --status --role build`.
- Delete a marker file to clear it by hand (`gemini-pool` clears Hydrogen, Neon and Flash together).
- An agy marker holds a reset time. If the tool gives none, the script uses 6 hours from now (a guess).

## OpenCode models
The script asks OpenCode which free models exist right now. It skips ones that were removed and tries brand-new free ones last (never for private code). You no longer edit the model list by hand when a model disappears. The preferred order lives in `chain_for` at the top of the script, for people who want to change it.

A free model that hangs for 30 minutes is skipped and the next one is tried. Two hangs in a row stop the task.

## Caps (parallel tasks, all guesses)
4 total. Hydrogen 3, Neon and Carbon combined 2, OpenCode 3 (`hard` or `large` 1), agy Sonnet 1, agy Opus 1. Flash scouting counts inside the total only, and so do Claude sub-agents. Opus lowers a cap when it sees a concurrency error or a shared free limit.

## What may go to which model
- Normal code: any pool.
- Code near auth or personal data (S = 1): OpenCode `--private` (only `deepseek-v4.1-flash-free` and `glm-5.3-flash-free`, which keep nothing and do not train), or Hydrogen, Neon or Carbon.
- Secrets, auth, crypto, payments (S = 2): never a free model. Claude builds it.
- A client's or employer's repo: `--private` on every OpenCode task including scouting. Gemini (Hydrogen, Neon, Carbon, Flash) is allowed. If you do not want Gemini to see that code, say so in the prompt.

## Who reviews and fixes
| Diff size | Reviewer |
|---|---|
| 800 changed lines or fewer | `sonnet-reviewer` |
| more than 800 | `opus-reviewer` sub-agent |
| any size, hard-routed (Neon, Carbon, OpenCode `hard`) or sensitive | `opus-reviewer` |

One review per task (after all its mini-tasks). No agy or OpenCode model reviews, because a reviewer must not edit.

| Built by | r1 | r2 | r3 | r4 | r5 |
|---|---|---|---|---|---|
| Hydrogen | Hydrogen high | Neon high | Carbon high | agy Sonnet | agy Opus |
| OpenCode build/mech | same model | Neon high | Carbon high | agy Sonnet | agy Opus |
| Neon (hard) | same Neon | Carbon high | agy Sonnet | agy Opus | |
| Carbon (hard, Neon unavailable) | same Carbon | agy Sonnet | agy Opus | | |
| OpenCode hard | same model | agy Sonnet | agy Opus | | |
| OpenCode large/vision/av | same model | Claude Sonnet | Claude Opus | | |

A drained agy Sonnet or Opus step is replaced by Claude Sonnet or Opus of the same tier. A drained or tripped Hydrogen, Neon, Carbon or OpenCode step is skipped. When the whole Gemini pool is drained, every Hydrogen, Neon and Carbon step is skipped (no Gemini fallback). Carbon is only the escalation after Neon, never carbon-low or carbon-xhigh. Design, sensitive and tiny-edit fixes stay on Claude. Still failing after the last step: recorded in the summary.

## Safety switches
Opus tallies first-review failures per pool (Hydrogen, OpenCode). From the 3rd reviewed task, more than 1 in 3 failing trips that pool for the rest of the run. Hydrogen tripped: its work goes to OpenCode `build`. OpenCode tripped: it takes no new builds (they stay on Hydrogen). A tripped Hydrogen with OpenCode unavailable: Neon high (the Gemini pool still has quota). With the Gemini pool drained and OpenCode unavailable: held (the question below). There is no switch for Neon or Carbon.

## When pools are drained
Fallbacks between pools are silent. A task is held only when every pool that may take it is drained (for builds: Hydrogen, OpenCode and the last resort Neon; for hard tasks: Neon, Carbon and OpenCode `hard`). Opus then asks once: "Free pools are drained for <tasks>. Wait for the reset, or switch the held tasks to Claude only?" Nothing runs on Claude for build work until you answer. Claude only mode is Claude only: scout, Haiku, Sonnet, Opus by the same scores, 800-line review rule.

# Part 3: Good to know
- **No relay.** All outside models are launched by scripts. The main chat only reads their short reports.
- **Run folder.** `.m11/` holds briefs, logs, the shared contract (`contract.md`), the task log (`TASKS.md`) and the detailed table of the last run (`last-run.md`). It is git-ignored and safe to delete between runs.
- **The final message is short.** A few plain lines. Details are in `.m11/last-run.md`.
- **Rule files.** Rarely needed rules live in `.claude/m11/`. Opus reads them only when needed, which keeps every message cheaper.
- **agy Sonnet and Opus are fix-only.** They never build first, review or design, so their small pools are spent only when a review failed.
- **A non-hard task that cannot be specced** goes to Hydrogen, then OpenCode `build`, and is held when both are drained, before the last resort (Neon, only when Hydrogen is tripped and the Gemini pool has quota). Edit Routing 7 in `CLAUDE.md` if you prefer to hold it instead.
- **agy runs have no shell.** Headless `agy` (`--mode accept-edits`) edits files but denies shell commands, so Hydrogen, Neon, Carbon, Flash, agy Sonnet and Opus can't run tests. The reviewer runs the safe, read-only checks.
- **Free models can say "done" and change nothing.** The script prints `changed lines (owned)`; 0 on a build task is a failure.
- **Edit the tables.** Routing and caps live in `CLAUDE.md`. The preferred order of the free models lives in `chain_for` at the top of `scripts/opencode-run.sh`.
- **Review every diff.** File ownership is enforced by instructions, not by the filesystem.
- **Known unknowns:** nothing in this module has been run on the real tools yet. Claude + Antigravity + Opencode (Flash) had one real run (a landing-site test, only Flash and Claude Sonnet took part). The Hydrogen route, the Neon and Carbon routes, the one shared Gemini pool marker, the OpenCode route, the fix ladders and the drained-pool paths are tested only against stand-in tools. Whether starting `agy` from Claude opens the browser sign-in page (the sign-in step in `SETUP.md` is untried; fallback: sign in in the Antigravity app), exact quota wording and reset times, whether Carbon really shares the Gemini quota with Hydrogen, Neon and Flash, whether the `gemini-4-carbon-*` ids exist in `agy models`, whether `opencode run` exits non-zero on a limit, whether `--agent plan` is read-only, concurrency caps, and model benchmarks and prices (third-party or vendor-reported) are unconfirmed.
