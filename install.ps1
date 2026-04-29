# Installs Claude Code dotfiles into $env:USERPROFILE\.claude
# Idempotent: safe to re-run.
$ErrorActionPreference = "Stop"

$RepoDir = $PSScriptRoot
$Target  = if ($env:CLAUDE_HOME) { $env:CLAUDE_HOME } else { Join-Path $env:USERPROFILE ".claude" }
$Stamp   = Get-Date -Format "yyyyMMdd-HHmmss"
$Backup  = Join-Path $Target "backups\dotclaude-$Stamp"

Write-Host "==> Repo:   $RepoDir"
Write-Host "==> Target: $Target"

New-Item -ItemType Directory -Force -Path $Target, $Backup | Out-Null

Get-ChildItem -Force -Path (Join-Path $RepoDir "home") | ForEach-Object {
    $dst = Join-Path $Target $_.Name
    if (Test-Path $dst) {
        Write-Host "  backup: $($_.Name)"
        Move-Item $dst $Backup
    }
    Copy-Item $_.FullName $dst -Recurse
    Write-Host "  install: $($_.Name)"
}

$claude = Get-Command claude -ErrorAction SilentlyContinue
$plugFile = Join-Path $RepoDir "plugins.json"
if ($claude -and (Test-Path $plugFile)) {
    $p = Get-Content $plugFile -Raw | ConvertFrom-Json
    Write-Host "==> Installing plugin marketplaces"
    foreach ($m in $p.marketplaces) {
        $ref = if ($m.source -eq "github") { $m.repo } else { $m.url }
        Write-Host "  marketplace: $($m.name) ($ref)"
        & claude plugin marketplace add $m.name $ref 2>$null
    }
    Write-Host "==> Installing plugins"
    foreach ($pl in $p.plugins) {
        $id = "$($pl.name)@$($pl.marketplace)"
        Write-Host "  plugin: $id"
        & claude plugin install $id 2>$null
    }
} else {
    Write-Host "!! claude CLI not found — skipping plugin install."
}

$npmGlobals = Join-Path $RepoDir "npm-globals.json"
if ((Get-Command npm -ErrorAction SilentlyContinue) -and (Test-Path $npmGlobals)) {
    Write-Host "==> Installing global npm packages"
    $ng = Get-Content $npmGlobals -Raw | ConvertFrom-Json
    foreach ($pkg in $ng.packages) {
        Write-Host "  npm: $pkg"
        & npm install -g $pkg 2>$null
    }
} else {
    Write-Host "!! npm not found — skipping global npm packages."
}

Write-Host "`nDone. Start Claude Code: claude"
