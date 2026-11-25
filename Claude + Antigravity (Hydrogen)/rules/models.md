Read this only when picking an agy effort level or model for a task that is not a plain Hydrogen build, or when editing the pool. Reference: `scripts/agy-run.sh` is the source of truth for aliases, effort suffixes and chains (the marked block at its top); keep CLAUDE.md in step.

Model IDs confirmed from the user's `agy models` output: Hydrogen `gemini-4-hydrogen-low`, `-medium`, `-high`, `-xhigh` (2026-11-13); Neon `gemini-4-neon-low`, `-medium`, `-high`, `-xhigh` (2026-11-19); Carbon `gemini-4-carbon-medium`, `-high` only (2026-11-24; no low, no xhigh; never carbon-low, it costs more per task than higher efforts). Real runs on the real tool are not done yet. Each ID embeds effort. An alias takes a `-low`, `-medium` or `-high` suffix (`sonnet-high`), `hydrogen` and `neon` also `-xhigh`, `carbon` only `-medium` or `-high` (the script refuses `carbon-low` and `carbon-xhigh`); a full ID is used as given. The aliases `hydrogen`, `neon` and `carbon` alone mean high; every other alias alone means medium.

# Antigravity models (run through `scripts/agy-run.sh`, on the Google AI Pro plan)

| Alias | agy model ID | Use for | Quota notes |
|---|---|---|---|
| hydrogen | `gemini-4-hydrogen-high` (`-medium`, `-low`, `-xhigh` selectable) | **Default builder** for every non-design build task, split into exact mini-tasks or bulk. Artificial Analysis index 51 (Nov 2026) vs Neon 60-61; reported weaker on terminal and long-horizon work. Always with a real `owns:` list. Fix step 1 for its own work. Never reviews | **Gemini pool** (shared with Neon, Carbon and Flash): one weekly limit plus one 5-hour limit |
| neon | `gemini-4-neon-high` (`-xhigh` for the hardest, `-medium` lighter, `-low` trivial) | **Hard tasks** (multi-file, tricky logic, terminal-heavy or long-horizon work), fix step 2 for Hydrogen-built work (step 1 for Neon-built), and builds after the Hydrogen safety switch trips. Index 61 xhigh / 60 high; about $3.74 and 15 min per task at high. Needs a real `owns:`. Never reviews, never designs. Default effort high: hard work is where reasoning effort pays, and `-xhigh` costs the most of the shared pool, so keep it for the hardest tasks | **Gemini pool** (same one as Hydrogen). Higher price than Hydrogen ($3/$15 vs $1.50/$7.50 per million tokens) |
| carbon | `gemini-4-carbon-high` (`-medium` exists; NO `-low`, NO `-xhigh`) | **Escalation.** Fix step after Neon fails review (Neon xhigh failed -> Carbon high; step 3 for Hydrogen-built work, step 2 for Neon-built), and long-horizon hard-reasoning tasks (Routing 5). Index 60, same as Neon high, but about $7.76 and 33 min per task (about 2x slower, burns the pool faster): use sparingly. Beats Neon only on Terminal-Bench 4.0. Needs a real `owns:`. Never reviews, never designs | **Gemini pool** (same one as Hydrogen and Neon) |
| flash (scout) | `gemini-3.8-flash-medium` (`-low` for pure lookups) | Scouting only: file lookup, grep-style questions, summaries, extraction, formatting. Read-only. **Never builds** (it is in the Hydrogen quota pool, so it is no fallback) | **Gemini pool** |
| sonnet | `claude-sonnet-5-5-medium` (`-low` for trivial) | Non-design tasks that need Claude-style judgment: nuanced edits, careful refactors, writing/docs | Small pool |
| opus | `claude-opus-5-5-medium` (`-high`, `-low` also exist) | Hard multi-file or architecture-heavy implementation only | Smallest pool; spend rarely |

# Claude-plan agents (in `.claude/agents/`, on the Claude Pro plan, never relays)

| Agent | Model | Use for |
|---|---|---|
| `claude-sonnet-builder` | sonnet, effort high | Design shells and first design drafts. Fix step 3 for Neon-built work, step 2 for Carbon-, agy Sonnet- and agy Opus-built work. Claude only mode: design, docs, and everything not easy or Opus-trigger |
| `claude-opus-builder` | opus, effort medium | **Sensitive work** (Routing 2) and the most important or complex designs. Last fix step for agy-built work (step 3; step 4 for Neon-built; step 5 for Hydrogen-built), step 2 for Claude-built design work. Claude only mode: Opus-trigger tasks and last-step fixes |
| `claude-sonnet-fixer` | sonnet, effort medium | Fix step 4 for Hydrogen-built work (earlier when the Gemini steps are skipped). Fixes only |
| `claude-haiku-builder` | haiku | Tiny, exactly described edits (Routing 3). Claude only mode: easy, tool-verifiable build tasks |
| `scout` | haiku | Claude only mode only: all read-only work, with file:line or URL evidence. Never edits |
| `sonnet-reviewer` | sonnet | Reviews ONE task's diff of 400 changed lines or fewer (`claude-opus-builder` work included), read-only. Returns PASS or FAIL |
| `opus-reviewer` | opus, effort medium | Reviews ONE task's diff of more than 400 changed lines, read-only, so the main session never reads a full diff. Returns PASS or FAIL with a numbered defect list |

# Quota pools (confirmed from the user's Antigravity usage screen on the Google AI Pro plan, 2026-11-19)
- **Gemini Models**: ALL Gemini models (Gemini 4 Neon, Carbon, Hydrogen, Orchestrator (Neon) and Gemini 3.8 Flash) share ONE pool with a weekly limit and a 5-hour limit (user decision 2026-11-24). One drained = all drained, so there is no Gemini fallback. Marker: `gemini-pool`. A "not available" error marks only that model.
- **Claude and GPT models** (agy Sonnet, agy Opus): a separate pool with a weekly and a 5-hour limit.
- Benchmarks (Artificial Analysis, Nov 2026): Neon xhigh 61, Neon high 60 ($3.74 per task, 15 min); Carbon high 60 ($7.76 per task, 33 min); Hydrogen high 51. Carbon beats Neon only on Terminal-Bench 4.0. Neon list price $3 in / $15 out per million tokens.
