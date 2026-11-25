Read this as soon as any task is held, Flash or an agy pool is drained (marker or `agy-run.sh` exit 3), or the user mentions Claude only. Self-contained. Cross-rules: Claude only never without the user's answer; the main session never implements.

# When an agy pool is drained
There are exactly two agy pools. The **Gemini pool** (Flash, Neon, Carbon: all share one quota, marker `gemini-pool`) and the **agy Claude pool** (agy Sonnet, agy Opus; marker `claude-pool`). A "not available" error marks only that model, by its id. Gemini drained = Flash, Neon and Carbon are all drained at once: **there is no Gemini fallback**, so nothing ever "falls back to" another Gemini model. Detect it with a fresh `gemini-pool` marker (`scripts/agy-run.sh --status`) or exit 3 `drained: gemini-...`.
1. Stop launching on a drained pool. Let running tasks finish and review them. Design tasks and Claude-plan fix steps do not need the agy pools, so they keep running as planned.
2. **Gemini drained, Claude pool free.** Neon and Carbon builds chain by themselves to agy Sonnet, then agy Opus (the script does it). **Flash pieces cannot start** (a Flash build never falls back): hold them and ask the question in step 4. A Flash scout whose pool is drained: stop and tell the user. Fix steps skip every Gemini step (`fix-ladders.md`).
3. **Claude pool drained, Gemini free.** Flash and Neon keep building as usual; agy Sonnet or agy Opus tasks chain to Neon by themselves. Nothing to ask.
4. **Both drained, or Gemini drained with Flash pieces held.** Run what can still run (design, Claude-plan fixes, reviews). Do not start a wave that depends on held tasks. When everything that can run has run and been reviewed, stop and ask the user ONE question, in words (no decision box), then wait:
   "The Gemini pool (Flash, Neon, Carbon) is drained (marker times: <times>)[ and so is agy Sonnet and Opus]. Some remaining tasks cannot run without it. Wait for the reset, or switch to Claude only?"
   Do nothing on the held tasks (no Claude builds either) until the user answers. Reset times are unpublished: a marker past its `until` time counts as cleared (the default `until` is a 6-hour guess).
   - Wait -> stop. On the next run, re-check the markers (`scripts/agy-run.sh --status`); if still drained, ask again.
   - Claude only -> Claude only mode for the held tasks (see below).
   - An answer given in the original prompt ("wait", "use Claude only") counts as the user's answer.
5. **Flash drained while building** (fresh `gemini-pool` marker, a `gemini-3.8-flash-high` marker, or exit 3 `drained: gemini-3.8-flash-high, no fallback`): stop and ask "Flash is drained (the whole Gemini pool is). Wait for the reset, or switch to Claude only?" (same answers). Never move the pieces to Neon or Carbon on your own: they are the same pool.
6. If the safety switch tripped AND Gemini is drained, new tasks go to agy Sonnet or Opus when the Claude pool is free; if it is drained too, all remaining non-design builds are held: ask the question in step 4.

# Claude only mode (only after the user answered "switch to Claude only")
Claude-only building with Claude builder subagents. No agy at all for the remaining tasks, including Flash. Tasks already built and accepted on Flash, Neon or Carbon stay as they are. Score every remaining build task 0 / 1 / 2 on each dimension (takes 10 seconds):

| | 0 | 1 | 2 |
|---|---|---|---|
| **A** Ambiguity | exact spec, diff describable in one sentence | clear goal, small local choices | open-ended, approach undecided |
| **N** Novelty | copies an existing pattern | adapts a pattern | no precedent; new abstraction |
| **C** Coupling | 1–2 files, no shared types | 3+ files or shared type/interface | cross-cutting, public API |
| **R** Reversibility | `git revert` undoes it | user-visible behavior or config | prod data, releases, money, external side effects |
| **S** Sensitivity | none | near auth/PII | auth, crypto, secrets, payments, PHI, tenancy |
| **V** Verifiability | a test/type/lint/build check fully covers it | partly covered | races, performance, security, UX judgment |
| **D** Diagnosis | cause known / none needed | reproducible, cause unknown | intermittent, prod-only, no repro |

Route each remaining task. First match wins:
- Read-only (find, explain, research, summarize) -> `scout`. No review.
- Opus trigger (ANY of: D = 2 · two or more dimensions = 2 · S = 2 and N >= 1 · A = 2 and C = 2) -> `claude-opus-builder`.
- Easy (A, R, S, V, D all 0, total <= 2, complete spec, a tool can verify it) -> `claude-haiku-builder`.
- Everything else (design, S = 2, docs, logic) -> `claude-sonnet-builder`.
- Tie-breakers: unsure haiku vs sonnet -> sonnet. Unsure sonnet vs opus -> sonnet, unless D = 2 or S = 2 -> opus.

Rules:
- Tasks already accepted from agy stay as they are. A task cut off by a drain may be partly edited: add to its brief "An agy run may have partly edited the owned files before it stopped. Inspect them first, then finish the task."
- Reviews: the usual 400-line rule (`sonnet-reviewer` up to 400 changed lines, `opus-reviewer` above).
- Fix ladder: round 1 the same agent, round 2 the next tier up (haiku -> `claude-sonnet-builder` -> `claude-opus-builder`), round 3 `claude-opus-builder`, then record and continue. An opus-builder task stays on opus-builder.
- Concurrency: total 4, no per-model caps. Plan lines end with `(Claude only mode)`. `.m6/last-run.md` lists which tasks ran in Claude only mode.
- Stay in Claude only mode for the rest of the session unless the user says to retry agy.
