Read this as soon as `relay.sh` exits 3 or 4, a quota marker is active, `--status` shows a drained family, or the user mentions Claude only. Self-contained. Cross-rules: both families drained = ask the user; Claude only never without the user's answer; design and shell work stays on Claude; the main session never implements.

# Quota families and markers
Three pools, one marker each (written atomically by the script into `.claude/agy-quota/` and `.claude/codex-quota/`):

| Family | Covers | Marker |
|---|---|---|
| Gemini | every `gemini-*` model (Hydrogen, Neon) | `.claude/agy-quota/gemini-pool` |
| agy Claude | agy Sonnet and agy Opus | `.claude/agy-quota/claude-pool` |
| Codex | Sol, Terra, Luna, Astra | `.claude/codex-quota/5h` and `weekly` |

A marker holds `until=` and `reason=`. It is active while now is before `until`. Clear one by deleting the file.

# 5-hour or weekly (the script decides)
- It reads the reset time from the quota error. **Under 5 hours away = 5-hour limit:** that pool's tasks WAIT (the script sleeps and polls up to the reset), while the other pool keeps working. If it must hand the wait back, it exits **3** with `waiting: <family> until <time>`: let other tasks run, then re-run the same `relay.sh` call after the time (it continues from `.agc/status/<task>.json`; verify on first real run).
- **Later reset = weekly limit:** switch family (below).
- **No reset time found:** wait once (one 5-hour wait), then treat it as weekly.
- Verify on first real run: the Codex quota error wording, the reset-time format, whether Sol and Astra share one pool on Plus.

# Weekly limit: what changes (the script does it; you only plan around it)
- **Gemini weekly drained:** Sol medium builds (Sol high for hard tasks). No Codex review step: straight to Claude review (exit 10). Fixes go Sol, then agy Sonnet/Opus, then Astra medium.
- **Codex weekly drained:** Hydrogen or Neon builds, the first Codex review is skipped: straight to Claude review. Fixes go Neon, then agy Sonnet/Opus.
- **agy Claude pool drained** (weekly): those fix rungs move to Claude Pro subagents: `claude-sonnet-fixer` (Sonnet medium, up to 800 lines), `claude-opus-builder` (Opus medium, above 800, hard or sensitive). Each fix is followed by a Claude review as usual. Claude launches them itself, then calls `--resume`.
- Design, shell and sensitive work never moved: it was on Claude already.

# Both families drained (exit 4)
Both Gemini and Codex are out (weekly). STOP and ask the user, one question in words, no decision box:
"Antigravity (Gemini) and Codex are both drained (until <times>). Wait for the reset, or switch the remaining tasks to Claude only?"
- Let running tasks finish and be reviewed first. Do nothing on Claude builders for held tasks until the user answers. An answer in the original prompt counts.
- Wait: stop. Next run, `relay.sh --status` first; ask again if still drained.
- Claude only: this is the `Claude only` module, not this one. Tell the user to use it. Never a standing default.
- Reset times are unpublished guesses unless the error gave one: a marker past `until` counts as cleared.
