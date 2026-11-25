# Claude plans, other models build

Setup guides and ready-to-copy files for running Claude Code (Opus) as the planner and reviewer, with other models building through a CLI: Google's Antigravity (`agy`), OpenAI's Codex (`codex`) or OpenCode's free models.

## Start here

| What | Where |
|---|---|
| **Pick the module that matches what you have. Each module's README has a one-command install for Mac and Windows.** | See the Modules table below |
| Original minimal setup (one Argon helper, Mac only, older flags), English | [setup/mac-setup-en.md](setup/mac-setup-en.md) |
| Original minimal setup, Egyptian Arabic | [setup/mac-setup-ar.md](setup/mac-setup-ar.md) |

## Modules

| Setup | You need | What it does | Folder |
|---|---|---|---|
| **Claude only** | Claude Pro | Opus plans, scores and reviews. Haiku scouts, Haiku, Sonnet and Opus build by task difficulty, an Opus fixer takes over after failed reviews. Pro plan only, no `agy` needed. | [Claude only](<Claude only>) |
| **Claude + Antigravity (Argon)** | Claude Pro + Google AI Pro | Opus plans in waves. Argon, Flash, Sonnet and Opus build several tasks at once through `agy`; Argon is the builder, Carbon (Gemini 4, medium/high only) is the fix step, and all Gemini models share one quota pool. Runs `agy` from a script, with no relay agent. Three fix rounds, quota fallback. | [Claude + Antigravity (Argon)](<Claude + Antigravity (Argon)>) |
| **Claude + Antigravity (Flash)** | Claude Pro + Google AI Pro | Same as Claude + Antigravity (Argon) but without Argon: Gemini Flash (high) builds exact small pieces, Gemini 4 Neon builds the rest and fixes Flash's work, and Gemini 4 Carbon (medium/high only) is the escalation after Neon and for long-horizon hard reasoning. All Gemini models share one quota pool. | [Claude + Antigravity (Flash)](<Claude + Antigravity (Flash)>) |
| **Claude + Codex** | Claude Pro + a ChatGPT plan with Codex | Opus plans in phases. Luna, Terra and Sol build several tasks at once through `codex exec` on a ChatGPT plan. No relay subagent, graded reviews, three fix rounds, quota fallback. | [Claude + Codex](<Claude + Codex>) |
| **Claude + Opencode** | Claude Pro (OpenCode free models need no plan) | Opus plans in phases. Ten free OpenCode models build tasks at once through `opencode run`; the script falls back to the next model when one hits its free limit. Zero-retention models for private code, graded reviews, four fix rounds, Claude only fallback. | [Claude + Opencode](<Claude + Opencode>) |
| **Claude + Antigravity + Opencode (Flash)** | Claude Pro + Google AI Pro (OpenCode is free) | Combines Claude + Antigravity (Flash) and Claude + Opencode. Outside models run from scripts, with no relay agent. Flash builds exact mini-tasks first, Neon builds the rest and fixes Flash's work, and Carbon (medium/high only) is the escalation after Neon and for long-horizon hard reasoning. All Gemini models share one quota pool; when it is drained, OpenCode free models take over silently (and handle scouting, images, big inputs). Claude plan designs, reviews and fixes. Claude only fallback. | [Claude + Antigravity + Opencode (Flash)](<Claude + Antigravity + Opencode (Flash)>) |
| **Claude + Antigravity (Hydrogen)** | Claude Pro + Google AI Pro | Opus plans in waves. Gemini 4 Hydrogen (high) builds every non-design task; Gemini 4 Neon takes the hard ones and takes over if Hydrogen fails review too often; Gemini 4 Carbon (medium/high only) is the escalation after Neon and for long-horizon hard reasoning; Flash only scouts. Argon is not used. All Gemini models share one quota pool, with no Gemini fallback when it is drained (follow the drained-pool question). Fix ladder Hydrogen, Neon, Carbon, Sonnet, Opus. Quota fallback. | [Claude + Antigravity (Hydrogen)](<Claude + Antigravity (Hydrogen)>) |
| **Claude + Antigravity + Opencode (Hydrogen)** | Claude Pro + Google AI Pro (OpenCode free models need no plan) | Claude + Antigravity + Opencode (Flash) with Gemini 4 Hydrogen as the default builder (scored about the same as Argon on one index (secondary source, unverified)) for exact mini-tasks and bulk work. OpenCode free models are the overflow and fallback and handle scouting, images and big inputs. Gemini 4 Neon takes the hard tasks; Gemini 4 Carbon (medium/high only) is the escalation after Neon and for long-horizon hard reasoning; Flash is a scout fallback. Argon is not used. All Gemini models share one quota pool; when it is drained there is no Gemini fallback and OpenCode takes over silently. Fix ladder Hydrogen, Neon, Carbon, Sonnet, Opus. Claude plan designs, reviews and fixes. Claude only fallback. | [Claude + Antigravity + Opencode (Hydrogen)](<Claude + Antigravity + Opencode (Hydrogen)>) |

Open the module's `README.md` for the step-by-step setup on Mac and Windows, and `test-prompt.md` for a ready test prompt. Every module can be set up from inside Claude Code: drop its zip into your project folder and paste one line (see the module's README). A one-command installer is there too.

## Layout

```
setup/                                  first-time setup guides
Claude only/
  README.md                             steps and how it works
  CLAUDE.md                             routing rules (project root)
  install.sh / install.ps1              one-command installer (Mac, Linux, Windows)
  SETUP.md                              setup steps Claude Code follows
  settings.json                         approvals list (merged into .claude/settings.json)
  agents/                               7 subagents (go to .claude/agents/)
  claude-only-files.zip                    the same files, zipped
Claude + Antigravity (Argon)/
  README.md                             steps and how it works
  CLAUDE.md                             routing rules (project root)
  AGENTS.md                             same rules for other tools (project root)
  install.sh / install.ps1              one-command installer (Mac, Linux, Windows)
  SETUP.md                              setup steps Claude Code follows
  settings.json                         approvals list (merged into .claude/settings.json)
  agents/                               7 subagents (go to .claude/agents/)
  rules/                                3 on-demand rule files (go to .claude/m6/)
  scripts/agy-run.sh                    agy runner (go to scripts/, chmod +x)
  claude-antigravity-argon-files.zip                    the same files, zipped
  test-prompt.md
Claude + Antigravity (Flash)/
  README.md                             steps and how it works
  CLAUDE.md                             routing rules (project root)
  AGENTS.md                             same rules for other tools (project root)
  install.sh / install.ps1              one-command installer (Mac, Linux, Windows)
  SETUP.md                              setup steps Claude Code follows
  settings.json                         approvals list (merged into .claude/settings.json)
  agents/                               7 subagents (go to .claude/agents/)
  rules/                                5 on-demand rule files (go to .claude/m6/)
  scripts/agy-run.sh                    agy runner (go to scripts/, chmod +x)
  claude-antigravity-flash-files.zip              the same files, zipped
  test-prompt.md
Claude + Codex/
  README.md                             steps and how it works
  CLAUDE.md                             routing rules (project root)
  AGENTS.md                             shared rules for Codex and builders (project root)
  install.sh / install.ps1              one-command installer (Mac, Linux, Windows)
  SETUP.md                              setup steps Claude Code follows
  settings.json                         approvals list (merged into .claude/settings.json)
  agents/                               5 subagents (go to .claude/agents/)
  rules/                                4 on-demand rule files (go to .claude/m7/)
  scripts/codex-run.sh                  Codex runner (go to scripts/, chmod +x)
  claude-codex-files.zip                    the same files, zipped
  test-prompt.md
Claude + Opencode/
  README.md                             steps and how it works
  CLAUDE.md                             routing rules (project root)
  AGENTS.md                             shared rules for OpenCode models and builders (project root)
  install.sh / install.ps1              one-command installer (Mac, Linux, Windows)
  SETUP.md                              setup steps Claude Code follows
  settings.json                         approvals list (merged into .claude/settings.json)
  agents/                               5 subagents (go to .claude/agents/)
  rules/                                4 on-demand rule files (go to .claude/m8/)
  scripts/opencode-run.sh               OpenCode runner (go to scripts/, chmod +x)
  claude-opencode-files.zip                    the same files, zipped
  test-prompt.md
  model-research.md                     notes on the free models
Claude + Antigravity + Opencode (Flash)/
  README.md                             steps and how it works
  CLAUDE.md                             routing rules (project root)
  AGENTS.md                             shared rules for all builders (project root)
  install.sh / install.ps1              one-command installer (Mac, Linux, Windows)
  SETUP.md                              setup steps Claude Code follows
  settings.json                         approvals list (merged into .claude/settings.json)
  agents/                               7 subagents (go to .claude/agents/)
  rules/                                5 on-demand rule files (go to .claude/m9/)
  scripts/agy-run.sh                    agy runner (go to scripts/, chmod +x)
  scripts/opencode-run.sh               OpenCode runner (go to scripts/, chmod +x)
  claude-antigravity-opencode-flash-files.zip                    the same files, zipped
  test-prompt.md
Claude + Antigravity (Hydrogen)/
  README.md                             steps and how it works
  CLAUDE.md                             routing rules (project root)
  AGENTS.md                             same rules for other tools (project root)
  install.sh / install.ps1              one-command installer (Mac, Linux, Windows)
  SETUP.md                              setup steps Claude Code follows
  settings.json                         approvals list (merged into .claude/settings.json)
  agents/                               7 subagents (go to .claude/agents/)
  rules/                                5 on-demand rule files (go to .claude/m10/)
  scripts/agy-run.sh                    agy runner (go to scripts/, chmod +x)
  claude-antigravity-hydrogen-files.zip                   the same files, zipped
  test-prompt.md
Claude + Antigravity + Opencode (Hydrogen)/
  README.md                             steps and how it works
  CLAUDE.md                             routing rules (project root)
  AGENTS.md                             shared rules for all builders (project root)
  install.sh / install.ps1              one-command installer (Mac, Linux, Windows)
  SETUP.md                              setup steps Claude Code follows
  settings.json                         approvals list (merged into .claude/settings.json)
  agents/                               7 subagents (go to .claude/agents/)
  rules/                                5 on-demand rule files (go to .claude/m11/)
  scripts/agy-run.sh                    agy runner (go to scripts/, chmod +x)
  scripts/opencode-run.sh               OpenCode runner (go to scripts/, chmod +x)
  claude-antigravity-opencode-hydrogen-files.zip                   the same files, zipped
  test-prompt.md
```
