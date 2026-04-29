# Installs Claude Code dotfiles into $env:USERPROFILE\.claude and provisions required
# skills/plugins/repos from registry.json. Idempotent: safe to re-run.
# status=optional entries are NEVER auto-installed — manage via /dotclaude-lab in Claude Code.
$ErrorActionPreference = "Stop"

$RepoDir  = $PSScriptRoot
$Target   = if ($env:CLAUDE_HOME) { $env:CLAUDE_HOME } else { Join-Path $env:USERPROFILE ".claude" }
$Stamp    = Get-Date -Format "yyyyMMdd-HHmmss"
$Backup   = Join-Path $Target "backups\dotclaude-$Stamp"
$Cache    = Join-Path $Target ".dotclaude-cache"
$Registry = Join-Path $RepoDir "registry.json"

Write-Host "==> Repo:   $RepoDir"
Write-Host "==> Target: $Target"

New-Item -ItemType Directory -Force -Path $Target, $Backup, $Cache, (Join-Path $Target "skills") | Out-Null

# ---------- 1. Copy home/* into ~/.claude/* (with backup) ----------
Get-ChildItem -Force -Path (Join-Path $RepoDir "home") | ForEach-Object {
    $dst = Join-Path $Target $_.Name
    if (Test-Path $dst) {
        Write-Host "  backup: $($_.Name)"
        Move-Item $dst $Backup
    }
    Copy-Item $_.FullName $dst -Recurse
    Write-Host "  install: $($_.Name)"
}

if (-not (Test-Path $Registry)) {
    Write-Host "!! no registry.json — done."
    exit 0
}

$reg = Get-Content $Registry -Raw | ConvertFrom-Json
$claude = Get-Command claude -ErrorAction SilentlyContinue
$git    = Get-Command git    -ErrorAction SilentlyContinue
$npx    = Get-Command npx    -ErrorAction SilentlyContinue
$npm    = Get-Command npm    -ErrorAction SilentlyContinue

# ---------- 2. Register marketplaces ----------
if ($claude) {
    Write-Host "==> Registering marketplaces"
    foreach ($m in @($reg.marketplaces)) {
        $ref = if ($m.source -eq "github") { $m.repo } else { $m.url }
        Write-Host "  marketplace: $($m.name) ($ref)"
        & claude plugin marketplace add $m.name $ref 2>$null
    }

    # ---------- 3. Install required plugins ----------
    Write-Host "==> Installing required plugins"
    foreach ($p in @($reg.plugins)) {
        if ($p.status -ne "required") { continue }
        $id = "$($p.name)@$($p.marketplace)"
        Write-Host "  plugin: $id"
        & claude plugin install $id 2>$null
    }
} else {
    Write-Host "!! claude CLI not found — skipping marketplaces and plugins."
}

# ---------- 4. Install required skills ----------
Write-Host "==> Installing required skills"
foreach ($s in @($reg.skills)) {
    if ($s.status -ne "required") { continue }
    Write-Host "  skill: $($s.name) ($($s.type))"
    $cacheDir = Join-Path $Cache "skills\$($s.name)"
    $dest     = Join-Path $Target "skills\$($s.name)"
    switch ($s.type) {
        "git" {
            if (-not $git) { Write-Host "    !! git not available"; continue }
            if (Test-Path (Join-Path $cacheDir ".git")) {
                & git -C $cacheDir pull --ff-only 2>$null | Out-Null
            } else {
                if (Test-Path $cacheDir) { Remove-Item -Recurse -Force $cacheDir }
                & git clone --depth 1 $s.ref $cacheDir 2>$null | Out-Null
            }
            $srcPath = if ($s.subpath) { Join-Path $cacheDir $s.subpath } else { $cacheDir }
            if (Test-Path $dest) { Remove-Item -Recurse -Force $dest }
            New-Item -ItemType Directory -Force -Path $dest | Out-Null
            Copy-Item -Path (Join-Path $srcPath "*") -Destination $dest -Recurse -Force
        }
        "git-file" {
            if (-not $git) { Write-Host "    !! git not available"; continue }
            if (Test-Path (Join-Path $cacheDir ".git")) {
                & git -C $cacheDir pull --ff-only 2>$null | Out-Null
            } else {
                if (Test-Path $cacheDir) { Remove-Item -Recurse -Force $cacheDir }
                & git clone --depth 1 --filter=blob:none --sparse $s.ref $cacheDir 2>$null | Out-Null
                if ($s.subpath) { & git -C $cacheDir sparse-checkout set $s.subpath 2>$null | Out-Null }
            }
            $srcPath = if ($s.subpath) { Join-Path $cacheDir $s.subpath } else { $cacheDir }
            if (Test-Path $dest) { Remove-Item -Recurse -Force $dest }
            New-Item -ItemType Directory -Force -Path $dest | Out-Null
            Copy-Item -Path (Join-Path $srcPath "*") -Destination $dest -Recurse -Force
        }
        "skills-cli" {
            if ($npx) {
                & npx -y skills add $s.ref --skill $s.skill 2>$null
            } else {
                Write-Host "    !! npx not available"
            }
        }
        default {
            Write-Host "    !! unknown skill type: $($s.type)"
        }
    }
}

# ---------- 5. Install required repos ----------
Write-Host "==> Installing required repos"
foreach ($r in @($reg.repos)) {
    if ($r.status -ne "required") { continue }
    Write-Host "  repo: $($r.name)"
    if ($r.install_cmd_windows) {
        try { Invoke-Expression $r.install_cmd_windows } catch { Write-Host "    !! install_cmd failed: $_" }
    } elseif ($r.url -and $git) {
        $cacheDir = Join-Path $Cache "repos\$($r.name)"
        if (Test-Path (Join-Path $cacheDir ".git")) {
            & git -C $cacheDir pull --ff-only 2>$null | Out-Null
        } else {
            & git clone --depth 1 $r.url $cacheDir 2>$null | Out-Null
        }
    }
}

# ---------- 6. Install required global npm packages ----------
if ($npm) {
    Write-Host "==> Installing required npm globals"
    foreach ($pkg in @($reg.npm_globals)) {
        if ($pkg.status -ne "required") { continue }
        Write-Host "  npm: $($pkg.name)"
        & npm install -g $pkg.name 2>$null
    }
} else {
    Write-Host "!! npm not found — skipping npm globals."
}

Write-Host "`nDone. Optional entries can be managed via /dotclaude-lab in Claude Code."
