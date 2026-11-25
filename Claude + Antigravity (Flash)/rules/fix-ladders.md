Read this before launching the first fix step of a run (any review returned FAIL). Self-contained. Cross-rules: Flash never fixes and never reviews; no agy model reviews; the main session never implements.

# Fix ladders (max 4 steps per task)
When a task fails review, send the defect list to the next step of the ladder for whoever built it. A drained step is skipped. There is no Gemini fallback: Flash, Neon and Carbon share ONE quota pool (marker `gemini-pool`), so a drained Gemini pool skips every Gemini step and the ladder continues on Claude. A drained model is never replaced by another agy model in a fix.

| Built by | r1 | r2 | r3 | r4 |
|---|---|---|---|---|
| Flash (default route) | **Neon high** (`agy-run.sh --model neon --no-fallback`; gets the whole task diff and the defect list, owns all the task's files; `neon-xhigh` only for the hardest) | **Carbon high** (`--model carbon-high --no-fallback`) | `claude-sonnet-fixer` (Sonnet medium) | `claude-opus-builder` (Opus medium), then record and continue |
| Neon | Neon again, same effort (`--no-fallback`) | Carbon high (`--no-fallback`) | `claude-sonnet-builder` (Sonnet high) | `claude-opus-builder` (Opus medium), then record and continue |
| Carbon | `claude-sonnet-builder` (Sonnet high) | `claude-opus-builder` (Opus medium) | record and continue | - |
| agy Sonnet or agy Opus | the same agy model (`--no-fallback`) | `claude-sonnet-builder` (Sonnet high) | `claude-opus-builder` (Opus medium) | record and continue |
| `claude-sonnet-builder` (design) | the same agent | `claude-opus-builder` | record and continue | - |
| `claude-opus-builder` (design or sensitive) | the same agent | record and continue | - | - |
| `claude-haiku-builder` (tiny edit) | the same agent | `claude-sonnet-builder` | `claude-opus-builder` | - |

- Flash never fixes and never reviews. Its work goes straight to the Flash row.
- Flash-built ladder, exactly: Neon, then Carbon high, then Sonnet medium, then Opus medium. Neon-built: Neon, Carbon high, Sonnet, Opus.
- Neon runs high by default; `xhigh` only for the hardest tasks. Carbon exists only as `carbon-medium` and `carbon-high`: never carbon-low (it costs more per task than higher efforts) and never xhigh. Carbon high is the escalation when Neon fails review. It is about 2x slower and burns the shared Gemini pool faster: use it for nothing else in a fix.
- Gemini pool drained (fresh `gemini-pool` marker, or exit 3 `drained: gemini-...`)? Skip r1 and r2: a Flash-built fix starts at Sonnet medium (`-r3`), a Neon-built fix at Sonnet high. A marker that names one model only (a "not available" error) skips only that model: Neon unavailable but Carbon fine starts at Carbon.
- A fix of Flash-built work is one task for the whole task, not per mini-task.
- If the ladder is used up and the task still fails review: record the defect in the final summary and continue.
- Claude only mode uses its own ladder (see `drained-pools.md`).

## Launching fix steps
- After reviewing a wave, send all defect fixes together in one message, same caps. A fix task keeps the original `owns:` (for a task split into mini-tasks, every file of the task) and gets `task: <id>-r1` to `<id>-r4`, matching its step in the ladder (a skipped step leaves its number unused: with the Gemini pool drained, a Flash-built fix starts at `-r3`).
- The brief body is the defect list (for a Neon or Carbon fix of Flash work: the whole task diff and the defect list). Add a note if an earlier run stopped partway on a quota error.
- Any Claude-plan fix is printed in the plan line (e.g. `w1-home-r3 -> claude-sonnet-builder (Claude plan, Sonnet high; Gemini pool drained)` or `w1-pages-r3 -> claude-sonnet-fixer (Claude plan, Sonnet medium; Gemini pool drained)`) and goes in `.m6/last-run.md`.
