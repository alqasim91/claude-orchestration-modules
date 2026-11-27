Read this only when file sets cannot be disjoint (worktree mode, optional, default off). Self-contained. Cross-rules: never commit on the user's branch, never push; `owns:` still applies inside a worktree; env files are never copied.

# Worktree mode
Needs a git repo with at least one commit. Commit the files the builders need first (including AGENTS.md): a worktree has only committed files. Never copy or link a `.env` file into a worktree: that touches secrets, so stop and ask.
Per task:
1. `git worktree add ../wt-<task> -b agc/<task>`
2. Pass `--worktree ../wt-<task>` to `relay.sh` (it hands the path to `agy-run.sh` and `codex-run.sh`). Claude builders work only inside it. Briefs, `.agc/` and quota markers stay in the main tree. Briefs that point at `.agc/contract.md` give its absolute path.
3. After the run, a reviewer sub-agent reads `git -C ../wt-<task> diff`; the main session reads only the summary and the stat. Commit approved work on the throwaway branch only (`git -C ../wt-<task> add -A && git -C ../wt-<task> commit -m "agc/<task>"`), then `git merge --squash agc/<task>` in the main tree, without committing there.
4. Merge conflicts are never resolved in the main session: send them to `claude-sonnet-builder` with the conflicted files in `owns:`.
5. `git worktree remove ../wt-<task>` and `git branch -D agc/<task>`.
Record worktree use in `.agc/last-run.md`.
