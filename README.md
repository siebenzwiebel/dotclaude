# dotclaude

Portable Claude Code configuration. Clone on a new machine, run the installer,
and the new Claude instance has the same `CLAUDE.md`, settings, commands,
skills, hooks, teams, and plugins as the source machine.

## Install on a new machine

```bash
git clone http://git.drewers.dev/Steven/dotclaude.git ~/dotclaude
cd ~/dotclaude
./install.sh          # Linux / macOS / Git-Bash / WSL
# or on Windows PowerShell:
./install.ps1
```

Alternatively just clone and tell Claude: *"set this up"* — it reads
[AGENTS.md](AGENTS.md) and runs the installer itself.

The installer is **idempotent**. Existing `~/.claude/*` entries are moved to
`~/.claude/backups/dotclaude-<timestamp>/` before being overwritten.

## What's in here

| Path | Purpose |
|------|---------|
| `home/CLAUDE.md` | Global user instructions loaded into every session |
| `home/settings.json` | Global settings (hooks, permissions, env) |
| `home/.omc-config.json` | oh-my-claudecode config |
| `home/commands/` | Custom slash commands |
| `home/skills/` | Custom skills |
| `home/hooks/` | Hook scripts |
| `home/teams/` | Team definitions |
| `home/hud/` | HUD config |
| `plugins.json` | Marketplaces + plugins to install |

## What's NOT tracked

Secrets (`.credentials.json`), machine-local overrides
(`settings.local.json`), session/history/cache data, and the `plugins/`
directory itself (plugins are reinstalled via `plugins.json`).

## Updating from a machine

Copy changed files from `~/.claude` into `home/` (mind `.gitignore`), commit, push.
