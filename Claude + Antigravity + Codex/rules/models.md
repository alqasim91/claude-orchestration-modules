Read this only when picking a model or effort for a task that is not a plain Hydrogen build, or when editing the pool. Reference: `scripts/agy-run.sh` and `scripts/codex-run.sh` are the source of truth for aliases and effort suffixes; keep CLAUDE.md in step. Plans: ChatGPT Plus, Google AI Pro, Claude Pro.

IDs: Hydrogen `gemini-4-hydrogen-<effort>`, Neon `gemini-4-neon-<effort>` (Hydrogen and Neon ids from the Hydrogen module's `agy models` output; verify on first real run). Codex ids from learn.chatgpt.com/docs/models. Efforts: low, medium, high, xhigh.

# Antigravity models (`agy`, via `relay.sh` or `agy-run.sh`)

| Alias | Model | Use for | Pool |
|---|---|---|---|
| hydrogen | `gemini-4-hydrogen-high` | **Default builder** for every non-design build task. Fix rung 1. Never reviews | Gemini pool (`gemini-pool`) |
| neon | `gemini-4-neon-high` (`-xhigh` only for the hardest) | **Hard tasks**, and fix rung 2 for Hydrogen work. Never reviews, never designs. Sol never fixes Neon work | Gemini pool (same one) |
| sonnet | agy Claude Sonnet 5.5 | **Fixes only**, late rungs. Never builds, never reviews | agy Claude pool (`claude-pool`) |
| opus | agy Claude Opus 5.5 | **Fixes only**, last agy rung. Never builds, never reviews | agy Claude pool (same one) |

No Carbon, Argon or Flash. One `gemini-pool` marker covers every `gemini-*` model: one drained, all drained. Scouting is Codex Luna, not Gemini.

# Codex models (`codex exec`, via `relay.sh` or `codex-run.sh`)

| Alias | Model | Use for |
|---|---|---|
| sol | `gpt-6.2-sol` | **Reviewer** of agy work (read-only, `--sandbox read-only`): medium for Hydrogen work, **high for Neon work and hard tasks**. Fixer for Hydrogen work. Builder only when the Gemini pool is drained (medium; high for hard) |
| terra | `gpt-6.1-terra` | Docs, copy, content pages (medium) |
| luna | `gpt-6-luna` | Scouting, lookups, read-only (low); tests, formatting, mechanical edits (medium) |
| astra | `gpt-6.2-astra` | **Escalation only** (`fix-ladders.md`). Medium effort, never high. Not a builder or reviewer |

Never add a Codex flag that bypasses the sandbox or approvals. Whether Sol and Astra share one pool on Plus: verify on first real run.

# Claude-plan agents (in `.claude/agents/`, Claude Pro, model set explicitly)

| Agent | Model | Use for |
|---|---|---|
| `claude-sonnet-builder` | sonnet, effort high | Design shells and first drafts. Claude fixes when the agy Claude pool is drained. Merge conflicts |
| `claude-opus-builder` | opus, effort medium | The most important designs. **Sensitive work.** Last Claude fix rung |
| `claude-haiku-builder` | haiku | Tiny, exactly described edits |
| `claude-sonnet-fixer` | sonnet, effort medium | Fixes only, when the agy Claude pool is drained |
| `sonnet-reviewer` | sonnet | Claude review of ONE task, **800 changed lines or fewer**, read-only |
| `opus-reviewer` | opus, effort medium | Claude review above 800 lines, and every hard or sensitive task, read-only |
| `log-reader` | haiku, effort low | Reads the logs ONLY after a failure or timeout. Returns the cause in 5 lines. Never edits |

Design and shell work stays on Claude (Sonnet high or Opus medium via agent), never Gemini or Codex.
