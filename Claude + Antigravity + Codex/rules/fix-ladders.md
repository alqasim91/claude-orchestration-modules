Read this before the first fix step of a run (any review returned FAIL, or `relay.sh` exited 10 or 11). Self-contained. Cross-rules: every fix is followed by a review; no agy or Gemini model reviews; reviewer is a grade above the builder; Sol never fixes Neon work; Astra medium only, never high; the main session never implements.

# Routes (the script walks them; Claude only judges at exit 10)
Reviewer verdict: first line `PASS` or `FAIL`, then numbered notes (`file:line`, problem, required change). Notes go verbatim into the next fix prompt. Codex reviews run `codex exec --sandbox read-only`. A PASS ends the task (exit 0).

**Hydrogen task** (`--route hydrogen`)

| Step | Who | Then |
|---|---|---|
| build | Hydrogen high | Sol medium reviews |
| fix 1 | Hydrogen | Sol medium reviews |
| fix 2 | Sol medium | **Claude review** (exit 10) |
| fix 3 | Neon high | Claude review |
| fix 4 | agy Sonnet/Opus | Claude review |
| fix 5 (only if Opus fixed and failed) | Astra medium | Claude review |
| still FAIL | - | exit 11, ASK THE USER |

**Neon task** (`--route neon`, or `--hard`)

| Step | Who | Then |
|---|---|---|
| build | Neon high | Sol **high** reviews (never Sol medium on Neon work) |
| fix 1 | Neon | Sol high reviews |
| (no fix) | - | **Claude review** (exit 10): Sol never fixes Neon work |
| fix 2 | agy Sonnet/Opus | Claude review |
| fix 3 (only if Opus fixed and failed) | Astra medium | Claude review |
| still FAIL | - | exit 11, ASK THE USER |

- **agy Sonnet or Opus:** Sonnet up to 800 changed lines, Opus above 800 and for hard or sensitive tasks (the same cut as the Claude reviewer). They only fix. They never build or review.
- **Astra:** consulted only when an agy Opus fix or a Claude Opus fix FAILS its first Claude review. One medium attempt, then a Claude review. Never high.
- **Claude review = Sonnet up to 800 changed lines, Opus above 800 and for all hard or sensitive tasks.** The same reviewer cut applies to every Claude review in a run.
- If a fix step is skipped because its pool is drained, take the substitute in `fallback.md`; the review after it stays.

# Claude-built work (design, sensitive, tiny)
No Codex review: Claude reviewer by the 800-line cut (Opus for sensitive).
- `claude-sonnet-builder`: fix 1 same agent, fix 2 `claude-opus-builder`, then ASK THE USER.
- `claude-opus-builder`: fix 1 same agent, then Astra medium once, then ASK THE USER.
- `claude-haiku-builder`: fix 1 `claude-sonnet-builder`, fix 2 `claude-opus-builder`.
Every fix is reviewed again, with the earlier defects in the reviewer's prompt.

# Using it
- After exit 10: spawn the reviewer, write its verdict to `.agc/notes/<task>.md`, call `relay.sh --resume <task> --claude-verdict pass|fail --notes <file>`. `fail` moves to the next fix step; `pass` ends the task. The script runs the fix and the checks, and stops again with 10, 11 or 0. Details: `relay.md`.
- A fix of Hydrogen or Neon work keeps the task's `owns:` and its whole diff in the prompt.
- When the user must be asked (exit 11), say in words which defects are left, which rungs were used and the summary path. Record it in `.agc/last-run.md`.
