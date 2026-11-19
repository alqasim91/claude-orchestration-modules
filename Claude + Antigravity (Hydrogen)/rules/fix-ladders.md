Read this before launching the first fix step of a run (any review returned FAIL). Self-contained. Cross-rules: Hydrogen, Neon and Flash never review; Flash never builds or fixes; no agy model reviews; the main session never implements.

# Fix ladders (max 3 steps per task; 4 for Hydrogen-built work)
When a task fails review, send the defect list to the next step of the ladder for whoever built it. "Built by" = the model that actually ran (the report's `model that ran`, after any fallback). Skip a step whose agy model is drained (fresh marker, or `agy-run.sh` exit 3 "drained"). A drained model is never replaced by another agy model in a fix, except that Argon takes the Gemini steps when the Gemini pool is drained (below).

| Built by | r1 | r2 | r3 | r4 |
|---|---|---|---|---|
| Hydrogen (default route) | **Hydrogen high** (`agy-run.sh --model hydrogen --no-fallback`) | **Neon high** (`--model neon --no-fallback`) | `claude-sonnet-fixer` (Sonnet medium) | `claude-opus-builder` (Opus medium), then record and continue |
| Neon (hard task) | **Neon high** (the same model, `--no-fallback`) | `claude-sonnet-builder` (Sonnet high) | `claude-opus-builder` (Opus medium) | - |
| Argon (fallback build or hard task), agy Sonnet or agy Opus | the same agy model (`agy-run.sh --no-fallback`) | `claude-sonnet-builder` (Sonnet high) | `claude-opus-builder` (Opus medium) | - |
| `claude-sonnet-builder` (design) | the same agent | `claude-opus-builder` | record and continue | - |
| `claude-opus-builder` (design or sensitive) | the same agent | record and continue | - | - |
| `claude-haiku-builder` (tiny edit) | the same agent | `claude-sonnet-builder` | `claude-opus-builder` | - |

- Hydrogen-built ladder, exactly: Hydrogen high, then Neon high, then Sonnet medium, then Opus medium. Skip drained steps. Neon is stronger than Hydrogen, so it is the second try, not the first.
- **Gemini pool drained** (fresh `gemini-pool` marker, or exit 3 on a Hydrogen or Neon fix): Hydrogen and Neon are both out, so skip them and use **Argon medium** (`--model argon --no-fallback`, slug `-r2`) as the one agy step, then the Claude steps. For a Neon-built task that replaces r1. Argon drained too: go straight to the Claude steps (Hydrogen-built: `claude-sonnet-fixer` then `claude-opus-builder`; Neon-built: `claude-sonnet-builder` then `claude-opus-builder`). Argon is a fix step only when the Gemini pool is drained.
- Hydrogen safety switch tripped (`safety-switch.md`)? Skip the Hydrogen step for fixes as well: start at Neon high.
- Hydrogen, Neon and Flash never review; Flash never builds or fixes. Never use Argon high or another agy model for these fixes. Argon drained = fresh `gemini-4-argon-medium` marker, or exit 3 `drained: gemini-4-argon-medium, no fallback`.
- A fix of Hydrogen-built work is one task for the whole task, not per mini-task. Hydrogen, Neon and Argon fix steps get the whole task diff and the defect list and own all the task's files.
- If the ladder is used up and the task still fails review: record the defect in the final summary and continue.
- Claude only mode uses its own ladder (see `drained-pools.md`).

## Launching fix steps
- After reviewing a wave, send all defect fixes together in one message, same caps. A fix task keeps the original `owns:` (for a task split into mini-tasks, every file of the task) and gets `task: <id>-r1` ... `<id>-r4`, matching its step in the ladder (a skipped step leaves its number unused: with the Gemini pool and Argon drained, a Hydrogen-built fix starts at `-r3`).
- The brief body is the defect list (for a Hydrogen, Neon or Argon fix of Hydrogen-built work: the whole task diff and the defect list). Add a note if an earlier run stopped partway on a quota error.
- Any Claude-plan fix is printed in the plan line (e.g. `w1-home-r3 -> claude-sonnet-fixer (Claude plan, Sonnet medium; Gemini pool and Argon drained)`) and goes in `.m10/last-run.md`.
