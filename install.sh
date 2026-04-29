#!/usr/bin/env bash
# Installs Claude Code dotfiles into ~/.claude
# Idempotent: safe to re-run. Existing files are backed up to ~/.claude/backups/dotclaude-<timestamp>/
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET="${CLAUDE_HOME:-$HOME/.claude}"
STAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP="$TARGET/backups/dotclaude-$STAMP"

echo "==> Repo:   $REPO_DIR"
echo "==> Target: $TARGET"

mkdir -p "$TARGET" "$BACKUP"

# Copy each entry from home/ into ~/.claude, backing up existing files
shopt -s dotglob nullglob
for src in "$REPO_DIR/home/"*; do
  name="$(basename "$src")"
  dst="$TARGET/$name"
  if [ -e "$dst" ]; then
    echo "  backup: $name -> backups/dotclaude-$STAMP/"
    mv "$dst" "$BACKUP/"
  fi
  cp -r "$src" "$dst"
  echo "  install: $name"
done

# Install plugin marketplaces + plugins
if command -v claude >/dev/null 2>&1 && [ -f "$REPO_DIR/plugins.json" ]; then
  echo "==> Installing plugin marketplaces"
  # Parse plugins.json with node (shipped with claude)
  node -e '
    const p = require("'"$REPO_DIR"'/plugins.json");
    for (const m of p.marketplaces||[]) {
      const ref = m.source === "github" ? m.repo : m.url;
      console.log(`${m.name}\t${ref}`);
    }
  ' | while IFS=$'\t' read -r name ref; do
    echo "  marketplace: $name ($ref)"
    claude plugin marketplace add "$name" "$ref" 2>/dev/null || true
  done

  echo "==> Installing plugins"
  node -e '
    const p = require("'"$REPO_DIR"'/plugins.json");
    for (const pl of p.plugins||[]) console.log(`${pl.name}@${pl.marketplace}`);
  ' | while read -r plugin; do
    echo "  plugin: $plugin"
    claude plugin install "$plugin" 2>/dev/null || true
  done
else
  echo "!! claude CLI not found — skipping plugin install. Run './install.sh' again after installing claude."
fi

# Install global npm packages
if command -v npm >/dev/null 2>&1 && [ -f "$REPO_DIR/npm-globals.json" ]; then
  echo "==> Installing global npm packages"
  node -e '
    const p = require("'"$REPO_DIR"'/npm-globals.json");
    for (const pkg of p.packages||[]) console.log(pkg);
  ' | while read -r pkg; do
    echo "  npm: $pkg"
    npm install -g "$pkg" 2>/dev/null || true
  done
else
  echo "!! npm not found — skipping global npm packages."
fi

echo ""
echo "Done. Start Claude Code: claude"
