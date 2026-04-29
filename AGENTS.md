# Instructions for Claude

This repository contains the user's personal Claude Code configuration (`~/.claude`).
If the user clones this repo onto a new machine and asks you to "set it up",
"install it", "mach fertig" or similar:

## Bootstrap steps

1. Detect the platform:
   - Windows native PowerShell → run `./install.ps1`
   - Git-Bash, WSL, Linux, macOS → run `./install.sh`

2. The install script will:
   - Back up any existing `~/.claude/*` entries to `~/.claude/backups/dotclaude-<timestamp>/`
   - Copy everything from `home/` into `~/.claude/`
   - Register plugin marketplaces from `plugins.json` via `claude plugin marketplace add`
   - Install plugins from `plugins.json` via `claude plugin install`

3. After install, tell the user to **restart Claude Code** so the new settings,
   commands, skills, hooks and plugins are picked up.

## What is tracked vs. not

Tracked (in `home/`): `CLAUDE.md`, `settings.json`, `.omc-config.json`,
`commands/`, `skills/`, `hooks/`, `teams/`, `hud/`.

Never tracked (see `.gitignore`): `.credentials.json`, `settings.local.json`,
`sessions/`, `projects/`, `history.jsonl`, `cache/`, `backups/`, `plugins/`
(plugins are re-installed from `plugins.json`, not copied as files), and any
machine-local state.

## Updating the repo from a machine

If the user has changed their local config and wants to push it back, copy
modified files from `~/.claude/` into `home/` (respecting `.gitignore`), commit
and push. Do not pull `.credentials.json` or `settings.local.json` — they are
machine-specific.

Also refresh `plugins.json` from `~/.claude/plugins/installed_plugins.json` +
`known_marketplaces.json` if new plugins have been installed.
