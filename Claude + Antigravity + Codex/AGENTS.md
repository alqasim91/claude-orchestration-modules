# Project rules, Claude + Antigravity + Codex (shared by Claude Code subagents, Antigravity models and Codex models)

- Your brief lists the files you own (`owns:`). Edit only those files. Reading any file is fine.
- Need a change in a file you do not own? Do not make it. Add `needs: <file>: <change>` to your report; an integration task will pick it up.
- Your brief may name a contract: read `.agc/contract.md` first and use only the names defined there. Do not invent names.
- Other agents may be editing other files at the same time. Never revert, reformat or delete changes you did not make. Modified files you did not touch are probably theirs: leave them alone.
- Do not run repo-wide formatters or codemods, `git checkout`, `git stash`, `git reset`, `git clean`, or dependency installs (npm, pip, etc.) unless your task owns that.
- Never commit or push. Leave changes uncommitted for review.
- Headless `agy` has no shell. Antigravity models edit files only; `relay.sh` runs the checks. Other runs: run the project's tests/lint before reporting done if your sandbox allows it, scoped to your files. Failures in files you do not own: report them, do not fix them. If checks were not run, say so.
- Never read, edit, copy or link secrets: env files (`.env`, `.env.local` and so on), keys, credentials. This includes copying or linking an env file into a worktree. If your task seems to need one, stop and report it as a blocker.
- Scratch databases: you may test migrations on a local, throwaway database that holds no real data and uses no real credentials. Never touch a real or shared database.
- Scratch files go in `.agc/logs/` or /tmp, not elsewhere in the repo.
- Read-only task or review (`owns: none`)? Change nothing. Report findings only.
- Reviewers: first line `PASS` or `FAIL`. Then numbered notes: `file:line`, the problem, the required change. Non-blocking remarks go after a line `Non-blocking:`.
- Final report: files changed, checks run, `needs:` lines, anything not done. Max 10 lines.
