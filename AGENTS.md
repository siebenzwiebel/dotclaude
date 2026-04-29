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
   - Copy everything from `home/` into `~/.claude/` (CLAUDE.md, settings, commands, hud, the `dotclaude-lab` skill)
   - Register plugin marketplaces from `registry.json`
   - Install all entries with `status: required` from `registry.json`:
     - skills (cloned from upstream into `~/.claude/.dotclaude-cache/skills/<name>/`, content placed in `~/.claude/skills/<name>/`)
     - plugins (`claude plugin install <name>@<marketplace>`)
     - repos (own `install_cmd_*` if defined, else `git clone` into cache)
     - npm globals (`npm install -g <name>`)
   - Entries with `status: optional` are **not** auto-installed.

3. After install, tell the user to **restart Claude Code** so the new settings,
   commands, skills, hooks and plugins are picked up. Mention they can manage
   the optional list and update upstream skills via `/dotclaude-lab list|try|promote|update`.

## What is tracked vs. not

Tracked (in `home/`): `CLAUDE.md`, `settings.json`, `.omc-config.json`,
`commands/`, `skills/dotclaude-lab/`, `hud/`. Plus `registry.json` at the repo root.

Never tracked (see `.gitignore`): `.credentials.json`, `settings.local.json`,
`sessions/`, `projects/`, `history.jsonl`, `cache/`, `backups/`, `plugins/`
(plugins are re-installed from `registry.json`), upstream skill clones in
`~/.claude/.dotclaude-cache/`, and any machine-local state.

## Updating the repo from a machine

For inline files: copy changed files from `~/.claude/` into `home/` (respecting
`.gitignore`), commit and push. Do not pull `.credentials.json` or
`settings.local.json` — they are machine-specific.

For upstream skills/plugins/repos: do NOT copy the cloned content into
`home/skills/`. Update the `ref` / version pin in `registry.json` if needed
(usually no change required — `git pull` keeps them current). The
`/dotclaude-lab update` command refreshes them in place via `git pull` or the
respective package CLI.

## Managing the registry from inside Claude Code

The `dotclaude-lab` skill provides commands for the user (and you, on their
behalf): `list`, `try`, `untry`, `add`, `promote`, `demote`, `remove`, `update`.
Read `home/skills/dotclaude-lab/SKILL.md` for the full semantics.
