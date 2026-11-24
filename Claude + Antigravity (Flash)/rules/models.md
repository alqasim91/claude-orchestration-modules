Read this only when picking an agy effort level or model for a task that is not a plain Flash build, or when editing the pool. Reference: `scripts/agy-run.sh` is the source of truth for aliases, effort suffixes and chains (the marked block at its top); keep CLAUDE.md in step.

Model IDs from `agy models` (Neon and Carbon added 2026-11-24; check yours). Each ID embeds effort. An alias takes a `-low`, `-medium`, `-high` or `-xhigh` suffix (`sonnet-high`, `neon-xhigh`); a full ID is used as given.

**Quota pools.** All Gemini models (Flash, Neon, Carbon) share ONE pool: one marker, `.claude/agy-quota/gemini-pool`. agy Sonnet and agy Opus share a separate pool: marker `claude-pool`. A "not available" error marks only that model, by its id.

# Antigravity models (run through `scripts/agy-run.sh`, on the Google AI Pro plan)

| Alias | agy model ID | Use for | Quota notes |
|---|---|---|---|
| flash (build) | `gemini-3.8-flash-high` | **First-choice builder** for any non-design task Opus can split into small, exactly specced mini-tasks. Always with a real `owns:` list. Never fixes, never reviews | Shared Gemini pool (large) |
| flash (scout) | `gemini-3.8-flash-medium` (`-low` for pure lookups) | Scouting: file lookup, grep-style questions, summaries, extraction, formatting. Read-only | Shared Gemini pool (large) |
| neon | `gemini-4-neon-high` (default; `-xhigh` only for the hardest tasks, `-medium` / `-low` for lighter ones) | Builds what Opus cannot spec exactly: bulk code, tests, refactors, large-context work, hard multi-file logic. **Fix step 1 for Flash-built and Neon-built work** (high). Artificial Analysis Nov 2026: xhigh 61, high 60, about $3.74/task | Shared Gemini pool |
| carbon | `gemini-4-carbon-high` (`-medium` also exists; **never `-low` (costs more per task than higher efforts), never xhigh**) | Escalation when Neon fails review (fix step 2), and tasks needing long-horizon hard reasoning. Same score as Neon high (60) at about $7.76/task and about 2x slower; ahead only on Terminal-Bench 4.0 (65.2 vs 63.6). Use sparingly | Shared Gemini pool, burns it faster |
| sonnet | `claude-sonnet-5-5-medium` (`-low` for trivial) | Non-design tasks that need Claude-style judgment: nuanced edits, careful refactors, writing/docs | Claude pool (small) |
| opus | `claude-opus-5-5-medium` (`-high`, `-low` also exist) | Hard multi-file or architecture-heavy implementation only | Claude pool; spend rarely |

# Claude-plan agents (in `.claude/agents/`, on the Claude Pro plan, never relays)

| Agent | Model | Use for |
|---|---|---|
| `claude-sonnet-builder` | sonnet, effort high | Design shells and first design drafts. Fix step 2 for work built by agy Sonnet or agy Opus, step 1 for Carbon-built, step 3 for Neon-built. Claude only mode: design, docs, and everything not easy or Opus-trigger |
| `claude-opus-builder` | opus, effort medium | **Sensitive work** (Routing 2) and the most important or complex designs. Last fix step for agy-built and Flash-built work, step 2 for Claude-built design work. Claude only mode: Opus-trigger tasks and last-step fixes |
| `claude-sonnet-fixer` | sonnet, effort medium | Fix step 3 for Flash-built work (the first step when the Gemini pool is drained). Fixes only |
| `claude-haiku-builder` | haiku | Tiny, exactly described edits (Routing 3). Claude only mode: easy, tool-verifiable build tasks |
| `scout` | haiku | Claude only mode only: all read-only work, with file:line or URL evidence. Never edits |
| `sonnet-reviewer` | sonnet | Reviews ONE task's diff of 400 changed lines or fewer (`claude-opus-builder` work included), read-only. Returns PASS or FAIL |
| `opus-reviewer` | opus, effort medium | Reviews ONE task's diff of more than 400 changed lines, read-only, so the main session never reads a full diff. Returns PASS or FAIL with a numbered defect list |
