# Setup for Claude + Antigravity + Codex

You are setting up Claude + Antigravity + Codex for a user who is not technical. Do the steps in order. Use plain, short sentences with the user. Run the commands yourself; do not ask the user to open a terminal unless a step says so. Setup is the one job you do yourself in this folder: do not build anything, do not start the user's project work, and do not read any `.env` file.

1. Check the place. `claude-antigravity-codex/install.sh` must exist here. If not, or if the folder looks wrong (for example the home folder), stop and tell the user to put `claude-antigravity-codex-files.zip` in their project folder, open a new session of the Claude desktop app on that folder and paste the line again.

2. Ask ONE plain question in the chat, no choice box, and wait: "While it works, Claude writes and changes files in this folder. Should it do that without asking you each time? Yes lets a run finish while you are away. No means you approve each change. You can change this later."

3. Run `bash claude-antigravity-codex/install.sh --accept-edits` for yes or `bash claude-antigravity-codex/install.sh --no-accept-edits` for no. If `bash` is not found, run `powershell -ExecutionPolicy Bypass -File claude-antigravity-codex\install.ps1 -AcceptEdits` (or `-NoAcceptEdits`).

4. Read the output (lines start `ok:`, `skipped:` or `NOTE:`). Tell only what matters, plainly. Cases:
- "you already have your own" `CLAUDE.md`/`AGENTS.md` (saved as `CLAUDE.claude-antigravity-codex.md`/`AGENTS.claude-antigravity-codex.md`): the module does not work until its rules are in that file. Ask whether to put them at the top of their file, their text below; do it only on a yes.
- "not valid JSON" or "I need node or python3": approvals not merged. Show the lines in `.claude/settings.claude-antigravity-codex.json` to add by hand (and `"defaultMode": "acceptEdits"` if they said yes).
- "git is not installed": reviews need git. Mac: `xcode-select --install`. Windows: Git for Windows (git-scm.com).
- "could not make the first commit": ask for a name and email, then run `git config user.name "<name>"` and `git config user.email "<email>"` (no `--global`) and `git add -A -- . ':(exclude,glob)**/.env*' && git commit -q -m start`.

5. Outside tools. For each tool below, run `command -v <tool>`. Missing: say in one sentence what it is, ask "May I install it?". Yes: run the install command. No: give them the command, go on. Still missing: suggest a restart. Installed: run its check, 20 second timeout. You cannot sign in for the user: if a check fails, hangs or lacks the models, say which are missing in plain words and go on. Never ask the user to open a terminal.
- `agy`: Google's Antigravity, runs the Gemini builders (Hydrogen, Neon) and the agy Sonnet and Opus fixers. Needs a Google AI Pro plan. Install: Mac/Linux `curl -fsSL https://antigravity.google/cli/install.sh | bash`; Windows `powershell -c "irm https://antigravity.google/cli/install.ps1 | iex"`. Check: `agy models`, listing gemini-4-hydrogen-high, gemini-4-neon-high, claude-sonnet-5-5-medium, claude-opus-5-5-medium (Hydrogen and Neon ids: verify on first real run). Sign-in (UNVERIFIED): if the check says not signed in, start `agy` yourself (20 second timeout, Google OAuth) so the sign-in page opens in the user's browser, tell the user in plain words to finish it with the Google AI Pro account, then run `agy models` again. If no browser opens or the check still fails, tell the user to open the Antigravity app and sign in there, then run `agy models` again.
- `codex`: OpenAI's Codex, runs the Sol, Terra and Luna builders and the read-only reviews. Needs a ChatGPT Plus plan (or any plan that includes Codex). Install: `npm i -g @openai/codex` (needs Node.js; Mac also `brew install codex`). Check: `codex --version`, then `codex login status`. Sign-in (opens a browser, so the user does it): if not signed in, run `codex login` yourself (20 second timeout), choose Sign in with ChatGPT, tell the user in plain words to finish it in the browser, then run `codex login status` again. If that fails, tell the user to run `codex login` in a terminal.

6. Check. Run `scripts/relay.sh --help` (expect a usage text), `scripts/agy-run.sh --status` and `scripts/codex-run.sh --status` (expect no limits active). `ls .claude/agents | wc -l` (7+) and `ls .claude/agc | wc -l` (4+). Report in one line.

7. Finish in at most 6 short lines: what is installed; what is left (sign-ins, rules to paste); START A NEW session in the Claude desktop app on this folder (rules load at session start) and choose Opus; then they can paste a request or the test prompt from `claude-antigravity-codex/test-prompt.md`; the `claude-antigravity-codex` folder and zip can stay or go.

## Rules
- Never add `--dangerously-skip-permissions`, `--auto` or any flag that bypasses permissions or a sandbox.
- Never read, print or ask for `.env` files, keys, tokens or passwords.
- If a command fails twice, stop and show the user the exact error. Edit no project files beyond these steps.
