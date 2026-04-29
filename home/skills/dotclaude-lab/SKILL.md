---
name: dotclaude-lab
description: Manage the dotclaude registry of skills, plugins, repos and npm-globals — list installed and lab (optional) entries, try/untry, add new entries, promote/demote between optional and required, remove entries, and update. Use whenever the user wants to inspect, install, test, or curate dotclaude entries (e.g. "show installed skills", "try visual-explainer", "promote peon-ping", "add this repo to my lab", "what optional skills do I have?", "update all my skills").
---

# dotclaude-lab

Skill management for the dotclaude config repo. Operates on `registry.json` in the dotclaude repo checkout and on `~/.claude/` for installed artifacts.

## Locating the dotclaude repo

The repo checkout is at `$DOTCLAUDE_REPO` if set, else `~/dotclaude`, else `~/claude-dotfiles`. If none of those exist, ask the user for the path. All `registry.json` reads/writes happen there. After every mutation, `cd` into that path and run `git add registry.json && git commit -m "<msg>"`. **Never push** unless the user explicitly asks.

`~/.claude/.dotclaude-cache/` is the install cache for cloned skills/repos.

## Registry shape

```json
{
  "marketplaces": [{ "name", "source": "github|git", "repo|url" }],
  "skills":      [{ "name", "type": "git|git-file|skills-cli", "ref", "subpath?", "skill?", "description", "status": "required|optional" }],
  "plugins":     [{ "name", "marketplace", "description", "status" }],
  "repos":       [{ "name", "url", "description", "install_cmd_unix?", "install_cmd_windows?", "status" }],
  "npm_globals": [{ "name", "description", "status" }]
}
```

Use `Read` for the file then write the whole file back via `Write` (preserves valid JSON). Order entries: `required` block first, then `optional`, alphabetical within each.

## Commands

### `list` — show installed + lab entries
1. Read `registry.json`
2. Print one table per bucket (skills/plugins/repos/npm_globals), columns: name, status, type/marketplace, description (trimmed). Mark a row with ✓ if currently installed (skill dir exists in `~/.claude/skills/<name>/`, plugin via `claude plugin list`, repo via cache dir, npm via `npm ls -g --depth=0`).
3. End with a one-line hint: "Use `/dotclaude-lab try <name>` to test an optional entry."

### `try <name>` — install an optional entry temporarily
1. Find the entry (any bucket). Refuse if `status=required` (already installed) — tell the user it's already on the required list.
2. Dispatch by bucket/type — same logic as `install.sh`:
   - **skill type=git**: clone `ref` into `~/.claude/.dotclaude-cache/skills/<name>/`, then copy `[subpath/]` contents into `~/.claude/skills/<name>/`
   - **skill type=git-file**: same but with `git clone --depth 1 --filter=blob:none --sparse` + `sparse-checkout set <subpath>`
   - **skill type=skills-cli**: `npx -y skills add <ref> --skill <skill>`
   - **plugin**: `claude plugin install <name>@<marketplace>`
   - **repo**: prefer `install_cmd_unix` (Linux/Mac) or `install_cmd_windows` (Windows), else `git clone <url>` into `~/.claude/.dotclaude-cache/repos/<name>/`
   - **npm_global**: `npm install -g <name>`
3. **Do not** modify `registry.json`. Tell the user it's installed for this machine and how to test, then ask if they want to promote.

### `untry <name>` — remove a test installation
Reverse of `try` — delete `~/.claude/skills/<name>/`, `claude plugin uninstall`, `npm uninstall -g`, `rm -rf` cache dir as appropriate. Don't touch `registry.json`.

### `add <type> <ref> [--name ...] [--description ...]` — register a new entry
- `type` ∈ `skill-git | skill-git-file | skill-skills-cli | plugin | repo | npm`
- For skills, ask follow-ups if needed: `subpath`, `skill`, `marketplace`. Infer `name` from `ref` (last URL segment) if not given.
- New entries default to `status: optional`.
- Append to the right bucket in `registry.json`, write back, commit with `Add <name> to lab (optional)`.
- Then offer to immediately `try` it.

### `promote <name>` — flip optional → required
1. Find entry, change `status` to `"required"`.
2. Write `registry.json`, commit with `Promote <name> to required`.
3. Suggest the user runs `./install.sh` (or `install.ps1`) to actually install it on this machine if not already done via `try`.

### `demote <name>` — flip required → optional
1. Find entry, change `status` to `"optional"`.
2. Write `registry.json`, commit with `Demote <name> to optional`.
3. Ask if the user wants to also uninstall it locally (`untry` semantics).

### `remove <name>` — delete entry from registry
1. Find entry, remove from bucket.
2. Write `registry.json`, commit with `Remove <name> from registry`.
3. Ask if the user wants to also uninstall locally.

### `update [<name>]` — pull upstream updates
For each `required` entry (or just `<name>` if given):
- **skill type=git or git-file**: `git -C ~/.claude/.dotclaude-cache/skills/<name> pull --ff-only`, then re-copy `[subpath/]` contents into `~/.claude/skills/<name>/`
- **skill type=skills-cli**: `npx -y skills update` (or re-add if no update command exists)
- **plugin**: `claude plugin update <name>`
- **repo**: `git -C ~/.claude/.dotclaude-cache/repos/<name> pull --ff-only`, or re-run install_cmd if defined
- **npm_global**: `npm update -g <name>`

Print a one-line summary per entry: name → updated / unchanged / failed.

## Conventions

- Always `Read` `registry.json` before mutating; never blind-`Edit` it.
- After any mutation: `cd` into the dotclaude repo and stage+commit only `registry.json` (and never anything else from the user's working tree).
- Never auto-push. If the user wants the change synced, they can do `git push` themselves.
- All shell calls go through `Bash`. On Windows hosts, prefer `install_cmd_windows` and PowerShell-friendly variants of git/npm commands.
- When the user gives ambiguous intent ("install this skill") and the entry could be either `try` (one-off) or `promote+install` (commit to required), ask before mutating the registry.
