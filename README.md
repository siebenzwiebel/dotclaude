# dotclaude

Portable Claude Code configuration with a registry-based install. Clone on a new
machine, run the installer, and the new Claude instance has the same `CLAUDE.md`,
settings, commands, plus all required skills/plugins/repos pulled from their
upstream sources (so you actually get updates).

Optional and recommended entries live in the same registry but are not
auto-installed by default — manage them in-session via the `dotclaude-lab`
skill (`/dotclaude-lab list`, `try`, `recommend`, `promote`, ...).

## Install on a new machine

```bash
git clone <this-repo> ~/dotclaude
cd ~/dotclaude
./install.sh                       # Linux / macOS / Git-Bash / WSL
./install.sh --with-recommended    # also pull "recommended" entries
# or on Windows PowerShell:
./install.ps1
./install.ps1 -WithRecommended     # also pull "recommended" entries
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
| `home/skills/dotclaude-lab/` | Skill that manages this registry |
| `home/hud/` | HUD config |
| `registry.json` | Marketplaces + skills + plugins + repos + npm globals (required & optional) |

## What's NOT tracked

Secrets (`.credentials.json`), machine-local overrides (`settings.local.json`),
session/history/cache data, the `plugins/` directory itself, and the
`~/.claude/.dotclaude-cache/` install cache for cloned upstream skills/repos.

## Registry

`registry.json` is the single source of truth. Each entry has one of three
statuses:

| Status | Auto-installed? | Use case |
|---|---|---|
| `required` | always (`install.sh`) | core stack — every machine needs it |
| `recommended` | only with `--with-recommended` (or `DOTCLAUDE_INCLUDE_RECOMMENDED=1`) | curated suggestion — opt-in per machine |
| `optional` | never (lab only — install via `try`) | on-the-shelf for experimentation |

Top-level `settings.autoPush` (default `true`) controls whether `dotclaude-lab`
mutations are pushed to the remote automatically. Set it to `false` to keep
commits local. Per-call override: `DOTCLAUDE_AUTOPUSH=0`.

Entry shapes per bucket:

- **skills** — `type: git` (full clone, optional `subpath`), `git-file`
  (sparse-checkout `subpath`), or `skills-cli` (`npx skills add`)
- **plugins** — installed via `claude plugin install <name>@<marketplace>`
- **repos** — generic git repos with their own installer (`install_cmd_unix` /
  `install_cmd_windows`) or a plain `git clone`
- **npm_globals** — `npm install -g <name>`

The installer resolves marketplaces first, then plugins, then skills, repos,
npm globals. Cloned upstream sources live under `~/.claude/.dotclaude-cache/`
so `update` can `git pull` them in place.

## Managing entries from inside Claude Code

The `dotclaude-lab` skill is registered automatically by `install.sh`. Use it
in any Claude Code session:

| Command | Effect |
|---------|--------|
| `/dotclaude-lab list` | Show all entries with status and install state |
| `/dotclaude-lab try <name>` | Install a non-required entry locally to test it (no commit) |
| `/dotclaude-lab untry <name>` | Remove a test installation |
| `/dotclaude-lab add <type> <ref> [--status ...] [--description ...]` | Add a new entry (default optional), commit |
| `/dotclaude-lab recommend <name>` | Set `recommended`, commit |
| `/dotclaude-lab promote <name>` | Step up: optional → recommended → required, commit |
| `/dotclaude-lab demote <name>` | Step down: required → recommended → optional, commit |
| `/dotclaude-lab remove <name>` | Delete entry from registry, commit |
| `/dotclaude-lab update [<name>]` | Pull upstream updates for installed entries |

All mutations commit `registry.json` and (by default) auto-push to the remote
so other machines see the change. Disable via `settings.autoPush: false` in
`registry.json` or per-call via `DOTCLAUDE_AUTOPUSH=0`.

## Updating from a machine

For inline files (CLAUDE.md, settings.json, commands, hud, dotclaude-lab):
copy changed files from `~/.claude/` into `home/`, commit, push.

For upstream skills/plugins/repos: don't copy files — `/dotclaude-lab update`
pulls upstream changes via `git pull` / `claude plugin update` / etc.
