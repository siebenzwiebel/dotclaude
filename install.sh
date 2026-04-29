#!/usr/bin/env bash
# Installs Claude Code dotfiles into ~/.claude and provisions required skills/plugins/repos
# from registry.json. Idempotent: safe to re-run. Existing files backed up to
# ~/.claude/backups/dotclaude-<timestamp>/. Status=optional entries are NEVER auto-installed —
# manage them via the dotclaude-lab skill (/dotclaude-lab list|try|promote|...).
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET="${CLAUDE_HOME:-$HOME/.claude}"
STAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP="$TARGET/backups/dotclaude-$STAMP"
CACHE="$TARGET/.dotclaude-cache"
REGISTRY="$REPO_DIR/registry.json"

echo "==> Repo:   $REPO_DIR"
echo "==> Target: $TARGET"

mkdir -p "$TARGET" "$BACKUP" "$CACHE" "$TARGET/skills"

# ---------- 1. Copy home/* into ~/.claude/* (with backup) ----------
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
shopt -u dotglob nullglob

if [ ! -f "$REGISTRY" ]; then
  echo "!! no registry.json — done."
  exit 0
fi
if ! command -v node >/dev/null 2>&1; then
  echo "!! node not found — cannot parse registry.json. Skipping skills/plugins/repos."
  exit 0
fi

read_json() { node -e "$1" "$REGISTRY"; }

# ---------- 2. Register marketplaces ----------
if command -v claude >/dev/null 2>&1; then
  echo "==> Registering marketplaces"
  read_json '
    const r = require(process.argv[1]);
    for (const m of r.marketplaces || []) {
      const ref = m.source === "github" ? m.repo : m.url;
      console.log(`${m.name}\t${ref}`);
    }
  ' | while IFS=$'\t' read -r name ref; do
    [ -z "$name" ] && continue
    echo "  marketplace: $name ($ref)"
    claude plugin marketplace add "$name" "$ref" 2>/dev/null || true
  done

  # ---------- 3. Install required plugins ----------
  echo "==> Installing required plugins"
  read_json '
    const r = require(process.argv[1]);
    for (const p of r.plugins || []) if (p.status === "required") console.log(`${p.name}@${p.marketplace}`);
  ' | while read -r id; do
    [ -z "$id" ] && continue
    echo "  plugin: $id"
    claude plugin install "$id" 2>/dev/null || true
  done
else
  echo "!! claude CLI not found — skipping marketplaces and plugins."
fi

# ---------- 4. Install required skills (dispatch by type) ----------
echo "==> Installing required skills"
read_json '
  const r = require(process.argv[1]);
  for (const s of r.skills || []) if (s.status === "required") {
    console.log([s.name, s.type, s.ref || "", s.subpath || "", s.skill || ""].join("\t"));
  }
' | while IFS=$'\t' read -r name type ref subpath skill; do
  [ -z "$name" ] && continue
  echo "  skill: $name ($type)"
  case "$type" in
    git)
      cache_dir="$CACHE/skills/$name"
      dest="$TARGET/skills/$name"
      if [ -d "$cache_dir/.git" ]; then
        git -C "$cache_dir" pull --ff-only 2>/dev/null || true
      else
        rm -rf "$cache_dir"
        git clone --depth 1 "$ref" "$cache_dir" 2>/dev/null || { echo "    !! clone failed"; continue; }
      fi
      src_path="$cache_dir"
      [ -n "$subpath" ] && src_path="$cache_dir/$subpath"
      rm -rf "$dest" && mkdir -p "$dest"
      cp -r "$src_path/." "$dest/"
      ;;
    git-file)
      cache_dir="$CACHE/skills/$name"
      dest="$TARGET/skills/$name"
      if [ -d "$cache_dir/.git" ]; then
        git -C "$cache_dir" pull --ff-only 2>/dev/null || true
      else
        rm -rf "$cache_dir"
        git clone --depth 1 --filter=blob:none --sparse "$ref" "$cache_dir" 2>/dev/null || { echo "    !! clone failed"; continue; }
        [ -n "$subpath" ] && git -C "$cache_dir" sparse-checkout set "$subpath" 2>/dev/null || true
      fi
      src_path="$cache_dir"
      [ -n "$subpath" ] && src_path="$cache_dir/$subpath"
      rm -rf "$dest" && mkdir -p "$dest"
      cp -r "$src_path/." "$dest/"
      ;;
    skills-cli)
      if command -v npx >/dev/null 2>&1; then
        npx -y skills add "$ref" --skill "$skill" 2>/dev/null || echo "    !! npx skills add failed"
      else
        echo "    !! npx not available"
      fi
      ;;
    *)
      echo "    !! unknown skill type: $type"
      ;;
  esac
done

# ---------- 5. Install required repos ----------
echo "==> Installing required repos"
read_json '
  const r = require(process.argv[1]);
  for (const e of r.repos || []) if (e.status === "required") {
    console.log([e.name, e.url || "", e.install_cmd_unix || ""].join("\t"));
  }
' | while IFS=$'\t' read -r name url cmd; do
  [ -z "$name" ] && continue
  echo "  repo: $name"
  if [ -n "$cmd" ]; then
    bash -c "$cmd" || echo "    !! install_cmd failed"
  elif [ -n "$url" ]; then
    cache_dir="$CACHE/repos/$name"
    if [ -d "$cache_dir/.git" ]; then
      git -C "$cache_dir" pull --ff-only 2>/dev/null || true
    else
      git clone --depth 1 "$url" "$cache_dir" 2>/dev/null || echo "    !! clone failed"
    fi
  fi
done

# ---------- 6. Install required global npm packages ----------
if command -v npm >/dev/null 2>&1; then
  echo "==> Installing required npm globals"
  read_json '
    const r = require(process.argv[1]);
    for (const p of r.npm_globals || []) if (p.status === "required") console.log(p.name);
  ' | while read -r pkg; do
    [ -z "$pkg" ] && continue
    echo "  npm: $pkg"
    npm install -g "$pkg" 2>/dev/null || true
  done
else
  echo "!! npm not found — skipping npm globals."
fi

echo ""
echo "Done. Optional entries can be managed via /dotclaude-lab in Claude Code."
