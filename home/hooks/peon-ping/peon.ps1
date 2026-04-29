# peon-ping hook for Claude Code (Windows native)
# Called by Claude Code hooks on SessionStart, Stop, Notification, PermissionRequest, PostToolUseFailure, PreCompact

param(
    [string]$Command = "",
    [string]$Arg1 = "",
    [string]$Arg2 = "",
    [Parameter(ValueFromRemainingArguments)]$ExtraArgs = @()
)

# 8-second self-timeout safety net â€” kills this process if anything blocks unexpectedly.
# Uses System.Timers.Timer (not Forms.Timer) so it works in headless PowerShell without a message pump.
# Must fire before ANY I/O (config read, state read, stdin read).
if (-not $Command) {
    $safetyTimer = New-Object System.Timers.Timer
    $safetyTimer.Interval = 8000
    $safetyTimer.AutoReset = $false
    Register-ObjectEvent -InputObject $safetyTimer -EventName Elapsed -Action { [Environment]::Exit(1) } | Out-Null
    $safetyTimer.Start()
}

# Diagnostic logging: set PEON_DEBUG=1 to surface silent failure diagnostics on stderr
$peonDebug = $env:PEON_DEBUG -eq "1"

# Raw config read; repair is done at install/update time, so hook only needs plain read.
function Get-PeonConfigRaw {
    param([string]$Path)
    return Get-Content $Path -Raw
}

# Resolve the active pack from config using the default_pack -> active_pack -> "peon" fallback chain.
# Accepts any object with optional default_pack and/or active_pack properties.
function Get-ActivePack($config) {
    if ($config.default_pack) { return $config.default_pack }
    if ($config.active_pack) { return $config.active_pack }
    return "peon"
}

# --- CLI commands ---
if ($Command) {
    $InstallDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    $ConfigPath = Join-Path $InstallDir "config.json"

    # Ensure config exists
    if (-not (Test-Path $ConfigPath)) {
        Write-Host "Error: peon-ping not configured. Config not found at $ConfigPath" -ForegroundColor Red
        exit 1
    }

    switch -Regex ($Command) {
        "^--toggle$" {
            $raw = Get-PeonConfigRaw $ConfigPath
            $cfg = $raw | ConvertFrom-Json
            $newState = -not $cfg.enabled
            $raw = Get-Content $ConfigPath -Raw
            $updated = $raw -replace '"enabled"\s*:\s*(true|false)', "`"enabled`": $($newState.ToString().ToLower())"
            if ($updated -ne $raw) { Set-Content $ConfigPath -Value $updated -Encoding UTF8 }
            $state = if ($newState) { "ENABLED" } else { "PAUSED" }
            Write-Host "peon-ping: $state" -ForegroundColor Cyan
            return
        }
        "^--(pause|mute)$" {
            $raw = Get-Content $ConfigPath -Raw
            $updated = $raw -replace '"enabled"\s*:\s*(true|false)', '"enabled": false'
            if ($updated -ne $raw) { Set-Content $ConfigPath -Value $updated -Encoding UTF8 }
            Write-Host "peon-ping: PAUSED" -ForegroundColor Yellow
            return
        }
        "^--(resume|unmute)$" {
            $raw = Get-Content $ConfigPath -Raw
            $updated = $raw -replace '"enabled"\s*:\s*(true|false)', '"enabled": true'
            if ($updated -ne $raw) { Set-Content $ConfigPath -Value $updated -Encoding UTF8 }
            Write-Host "peon-ping: ENABLED" -ForegroundColor Green
            return
        }
        "^--status$" {
            try {
                $cfg = Get-PeonConfigRaw $ConfigPath | ConvertFrom-Json
                $state = if ($cfg.enabled) { "ENABLED" } else { "PAUSED" }
                Write-Host "peon-ping: $state | pack: $(Get-ActivePack $cfg) | volume: $($cfg.volume)" -ForegroundColor Cyan
                # Show path_rules info
                $rules = @()
                if ($cfg.path_rules) { $rules = @($cfg.path_rules) }
                if ($rules.Count -gt 0) {
                    $activeRule = $null
                    foreach ($r in $rules) {
                        if ($PWD.Path -like $r.pattern) {
                            $activeRule = $r
                            break
                        }
                    }
                    if ($activeRule) {
                        Write-Host "peon-ping: active path rule: $($activeRule.pattern) -> $($activeRule.pack)" -ForegroundColor Cyan
                    } else {
                        Write-Host "peon-ping: path rules: $($rules.Count) configured" -ForegroundColor Cyan
                    }
                }
            } catch {
                Write-Host "Error reading config: $_" -ForegroundColor Red
                exit 1
            }
            return
        }
        "^--packs$" {
            $packsDir = Join-Path $InstallDir "packs"
            $cfg = Get-PeonConfigRaw $ConfigPath | ConvertFrom-Json
            $available = Get-ChildItem -Path $packsDir -Directory | Where-Object {
                (Get-ChildItem -Path (Join-Path $_.FullName "sounds") -File -ErrorAction SilentlyContinue | Measure-Object).Count -gt 0
            } | ForEach-Object { $_.Name } | Sort-Object

            switch ($Arg1) {
                "use" {
                    if (-not $Arg2) {
                        Write-Host "Usage: peon packs use <pack-name>" -ForegroundColor Yellow
                        return
                    }
                    $newPack = $Arg2
                    if ($newPack -notin $available) {
                        Write-Host "Pack '$newPack' not found. Available: $($available -join ', ')" -ForegroundColor Red
                        return
                    }
                    $raw = Get-Content $ConfigPath -Raw
                    $updated = $raw -replace '"default_pack"\s*:\s*"[^"]*"', "`"default_pack`": `"$newPack`""
                    $updated = $updated -replace '"active_pack"\s*:\s*"[^"]*"', "`"active_pack`": `"$newPack`""
                    if ($updated -ne $raw) { Set-Content $ConfigPath -Value $updated -Encoding UTF8 }
                    Write-Host "peon-ping: switched to '$newPack'" -ForegroundColor Green
                    return
                }
                "next" {
                    $currentPack = Get-ActivePack $cfg
                    $idx = [array]::IndexOf($available, $currentPack)
                    $newPack = $available[($idx + 1) % $available.Count]
                    $raw = Get-Content $ConfigPath -Raw
                    $updated = $raw -replace '"default_pack"\s*:\s*"[^"]*"', "`"default_pack`": `"$newPack`""
                    $updated = $updated -replace '"active_pack"\s*:\s*"[^"]*"', "`"active_pack`": `"$newPack`""
                    if ($updated -ne $raw) { Set-Content $ConfigPath -Value $updated -Encoding UTF8 }
                    Write-Host "peon-ping: switched to '$newPack'" -ForegroundColor Green
                    return
                }
                "bind" {
                    if (-not $Arg2) {
                        Write-Host "Usage: peon packs bind <pack> [--pattern <glob>] [--install]" -ForegroundColor Yellow
                        return
                    }
                    $packName = $Arg2
                    $bindPattern = ""
                    $bindInstall = $false
                    # Parse extra args for --pattern and --install flags
                    for ($i = 0; $i -lt $ExtraArgs.Count; $i++) {
                        switch ($ExtraArgs[$i]) {
                            "--pattern" {
                                if ($i + 1 -lt $ExtraArgs.Count) {
                                    $bindPattern = $ExtraArgs[$i + 1]
                                    $i++  # Intentionally advance loop counter to skip the next arg (the pattern value)
                                }
                            }
                            "--install" { $bindInstall = $true }
                            default {
                                if ($ExtraArgs[$i] -match "^--pattern=(.+)$") {
                                    $bindPattern = $Matches[1]
                                }
                            }
                        }
                    }

                    # If --install, download pack first
                    if ($bindInstall) {
                        # Download the pack using the installer's pack download logic
                        $regUrl = "https://peonping.github.io/registry/index.json"
                        try {
                            $regResp = Invoke-WebRequest -Uri $regUrl -UseBasicParsing -ErrorAction Stop
                            $reg = $regResp.Content | ConvertFrom-Json
                            $packInfo = $reg.packs | Where-Object { $_.name -eq $packName }
                            if ($packInfo) {
                                $srcRepo = $packInfo.source_repo
                                $srcRef = $packInfo.source_ref
                                $srcPath = $packInfo.source_path
                                $packBase = "https://raw.githubusercontent.com/$srcRepo/$srcRef/$srcPath"
                                $pDir = Join-Path $packsDir $packName
                                $sDir = Join-Path $pDir "sounds"
                                New-Item -ItemType Directory -Path $sDir -Force | Out-Null
                                Invoke-WebRequest -Uri "$packBase/openpeon.json" -OutFile (Join-Path $pDir "openpeon.json") -UseBasicParsing -ErrorAction Stop
                                $mf = Get-Content (Join-Path $pDir "openpeon.json") -Raw | ConvertFrom-Json
                                $total = 0
                                $downloaded = 0
                                foreach ($catN in $mf.categories.PSObject.Properties.Name) {
                                    $total += $mf.categories.$catN.sounds.Count
                                }
                                foreach ($catN in $mf.categories.PSObject.Properties.Name) {
                                    foreach ($snd in $mf.categories.$catN.sounds) {
                                        $sf = Split-Path $snd.file -Leaf
                                        $sp = Join-Path $sDir $sf
                                        $downloaded++
                                        if (-not (Test-Path $sp)) {
                                            Write-Host "`r[$packName] $downloaded/$total downloading..." -NoNewline
                                            Invoke-WebRequest -Uri "$packBase/sounds/$sf" -OutFile $sp -UseBasicParsing -ErrorAction SilentlyContinue
                                        }
                                    }
                                }
                                Write-Host "`r[$packName] $total/$total done.          "
                                # Refresh available list
                                $available = Get-ChildItem -Path $packsDir -Directory | Where-Object {
                                    (Get-ChildItem -Path (Join-Path $_.FullName "sounds") -File -ErrorAction SilentlyContinue | Measure-Object).Count -gt 0
                                } | ForEach-Object { $_.Name } | Sort-Object
                            }
                        } catch {
                            Write-Host "Warning: could not download pack '$packName'" -ForegroundColor Yellow
                        }
                    }

                    # Validate pack exists
                    if ($packName -notin $available) {
                        Write-Host "Error: pack `"$packName`" not found." -ForegroundColor Red
                        Write-Host "Available packs: $($available -join ', ')" -ForegroundColor Red
                        exit 1
                    }

                    # Default pattern is current directory
                    if (-not $bindPattern) {
                        $bindPattern = $PWD.Path
                    }

                    # Load config as object for manipulation
                    $cfgObj = Get-Content $ConfigPath -Raw | ConvertFrom-Json
                    $pathRules = @()
                    if ($cfgObj.path_rules) {
                        $pathRules = @($cfgObj.path_rules)
                    }

                    # Update existing rule or append new one
                    $found = $false
                    for ($i = 0; $i -lt $pathRules.Count; $i++) {
                        if ($pathRules[$i].pattern -eq $bindPattern) {
                            $pathRules[$i] = [PSCustomObject]@{ pattern = $bindPattern; pack = $packName }
                            $found = $true
                            break
                        }
                    }
                    if (-not $found) {
                        $pathRules += [PSCustomObject]@{ pattern = $bindPattern; pack = $packName }
                    }

                    if ($cfgObj.PSObject.Properties['path_rules']) {
                        $cfgObj.path_rules = $pathRules
                    } else {
                        $cfgObj | Add-Member -NotePropertyName 'path_rules' -NotePropertyValue $pathRules
                    }
                    $cfgObj | ConvertTo-Json -Depth 5 | Set-Content $ConfigPath -Encoding UTF8
                    Write-Host "peon-ping: bound $packName to $bindPattern"
                    if (-not ($ExtraArgs -contains "--pattern") -and -not ($ExtraArgs -match "^--pattern=")) {
                        $dirName = Split-Path $PWD.Path -Leaf
                        Write-Host "Tip: use --pattern `"*/$dirName`" to match any directory named $dirName"
                    }
                    return
                }
                "unbind" {
                    $unbindPattern = ""
                    # Arg2 could be --pattern or empty. Also check ExtraArgs.
                    if ($Arg2 -eq "--pattern") {
                        if ($ExtraArgs.Count -gt 0) {
                            $unbindPattern = $ExtraArgs[0]
                        }
                    } elseif ($Arg2 -match "^--pattern=(.+)$") {
                        $unbindPattern = $Matches[1]
                    } else {
                        # Check ExtraArgs for --pattern
                        for ($i = 0; $i -lt $ExtraArgs.Count; $i++) {
                            if ($ExtraArgs[$i] -eq "--pattern" -and ($i + 1) -lt $ExtraArgs.Count) {
                                $unbindPattern = $ExtraArgs[$i + 1]
                                break
                            } elseif ($ExtraArgs[$i] -match "^--pattern=(.+)$") {
                                $unbindPattern = $Matches[1]
                                break
                            }
                        }
                    }

                    # Load config
                    $cfgObj = Get-Content $ConfigPath -Raw | ConvertFrom-Json
                    $pathRules = @()
                    if ($cfgObj.path_rules) {
                        $pathRules = @($cfgObj.path_rules)
                    }

                    if ($pathRules.Count -eq 0) {
                        Write-Host "No pack bindings configured."
                        return
                    }

                    # Determine target pattern
                    $target = if ($unbindPattern) { $unbindPattern } else { $PWD.Path }

                    # Try exact match
                    $newRules = @($pathRules | Where-Object { $_.pattern -ne $target })
                    if ($newRules.Count -lt $pathRules.Count) {
                        if ($cfgObj.PSObject.Properties['path_rules']) {
                            $cfgObj.path_rules = $newRules
                        } else {
                            $cfgObj | Add-Member -NotePropertyName 'path_rules' -NotePropertyValue $newRules
                        }
                        $cfgObj | ConvertTo-Json -Depth 5 | Set-Content $ConfigPath -Encoding UTF8
                        Write-Host "peon-ping: unbound $target"
                        return
                    }

                    # No exact match â€” check if any rules match cwd via -like
                    if (-not $unbindPattern) {
                        $matching = @($pathRules | Where-Object { $PWD.Path -like $_.pattern })
                        if ($matching.Count -gt 0) {
                            Write-Host "No binding for `"$target`", but found rules matching this directory:" -ForegroundColor Red
                            foreach ($r in $matching) {
                                Write-Host "  $($r.pattern) -> $($r.pack)" -ForegroundColor Red
                            }
                            Write-Host "Use --pattern to remove a specific rule." -ForegroundColor Red
                            exit 1
                        }
                    }

                    Write-Host "No binding found for `"$target`"."
                    return
                }
                "bindings" {
                    $cfgObj = Get-Content $ConfigPath -Raw | ConvertFrom-Json
                    $pathRules = @()
                    if ($cfgObj.path_rules) {
                        $pathRules = @($cfgObj.path_rules)
                    }

                    if ($pathRules.Count -eq 0) {
                        Write-Host "No pack bindings configured."
                        return
                    }

                    foreach ($rule in $pathRules) {
                        $marker = if ($PWD.Path -like $rule.pattern) { " *" } else { "" }
                        Write-Host "  $($rule.pattern) -> $($rule.pack)$marker"
                    }
                    return
                }
                default {
                    # "list" or no subcommand - show available packs
                    Write-Host "Available packs:" -ForegroundColor Cyan
                    $currentPack = Get-ActivePack $cfg
                    foreach ($packName in $available) {
                        $soundCount = (Get-ChildItem -Path (Join-Path $packsDir "$packName\sounds") -File -ErrorAction SilentlyContinue | Measure-Object).Count
                        $marker = if ($packName -eq $currentPack) { " <-- active" } else { "" }
                        Write-Host "  $packName ($soundCount sounds)$marker"
                    }
                    return
                }
            }
        }
        "^--pack$" {
            $cfg = Get-PeonConfigRaw $ConfigPath | ConvertFrom-Json
            $packsDir = Join-Path $InstallDir "packs"
            $available = Get-ChildItem -Path $packsDir -Directory | Where-Object {
                (Get-ChildItem -Path (Join-Path $_.FullName "sounds") -File -ErrorAction SilentlyContinue | Measure-Object).Count -gt 0
            } | ForEach-Object { $_.Name } | Sort-Object

            $currentPack = Get-ActivePack $cfg
            if ($Arg1 -eq "use") {
                # "peon pack use <name>" - treat Arg2 as the pack name
                if (-not $Arg2) {
                    Write-Host "Usage: peon pack use <pack-name>" -ForegroundColor Yellow
                    return
                }
                $newPack = $Arg2
            } elseif ($Arg1 -eq "next") {
                # "peon pack next" - cycle to next
                $idx = [array]::IndexOf($available, $currentPack)
                $newPack = $available[($idx + 1) % $available.Count]
            } elseif ($Arg1) {
                $newPack = $Arg1
            } else {
                $idx = [array]::IndexOf($available, $currentPack)
                $newPack = $available[($idx + 1) % $available.Count]
            }

            if ($newPack -notin $available) {
                Write-Host "Pack '$newPack' not found. Available: $($available -join ', ')" -ForegroundColor Red
                return
            }

            $raw = Get-Content $ConfigPath -Raw
            $updated = $raw -replace '"default_pack"\s*:\s*"[^"]*"', "`"default_pack`": `"$newPack`""
            $updated = $updated -replace '"active_pack"\s*:\s*"[^"]*"', "`"active_pack`": `"$newPack`""
            if ($updated -ne $raw) { Set-Content $ConfigPath -Value $updated -Encoding UTF8 }
            Write-Host "peon-ping: switched to '$newPack'" -ForegroundColor Green
            return
        }
        "^--volume$" {
            if ($Arg1) {
                $vol = [math]::Round([math]::Max(0.0, [math]::Min(1.0, [double]::Parse($Arg1.Trim(), [System.Globalization.CultureInfo]::InvariantCulture))), 2)
                $volStr = $vol.ToString([System.Globalization.CultureInfo]::InvariantCulture)
                $raw = Get-Content $ConfigPath -Raw
                $updated = $raw -replace '"volume"\s*:\s*[\d.]+,', "`"volume`": $volStr,"
                if ($updated -ne $raw) { Set-Content $ConfigPath -Value $updated -Encoding UTF8 }
                Write-Host "peon-ping: volume set to $vol" -ForegroundColor Green
            } else {
                Write-Host "Usage: peon --volume 0.5" -ForegroundColor Yellow
            }
            return
        }
        "^--help$" {
            Write-Host "peon-ping commands:" -ForegroundColor Cyan
            Write-Host "  --toggle          Toggle enabled/paused"
            Write-Host "  --pause           Pause sounds"
            Write-Host "  --resume          Resume sounds"
            Write-Host "  --mute            Alias for --pause"
            Write-Host "  --unmute          Alias for --resume"
            Write-Host "  --status          Show current status"
            Write-Host "  --volume N        Set volume (0.0-1.0)"
            Write-Host "  --help            Show this help"
            Write-Host ""
            Write-Host "Pack management:" -ForegroundColor Cyan
            Write-Host "  --packs           List available sound packs"
            Write-Host "  --packs use <n>   Switch to a specific pack"
            Write-Host "  --packs next      Cycle to the next pack"
            Write-Host "  --packs bind      Bind a pack to current directory"
            Write-Host "  --packs unbind    Remove a pack binding"
            Write-Host "  --packs bindings  List all pack bindings"
            Write-Host "  --pack [name]     Switch pack (or cycle)"
            return
        }
    }
    return
}

# --- Hook mode (called by Claude Code via stdin JSON) ---
$InstallDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ConfigPath = Join-Path $InstallDir "config.json"
$StatePath = Join-Path $InstallDir ".state.json"

# Read config
try {
    $config = Get-PeonConfigRaw $ConfigPath | ConvertFrom-Json
} catch {
    exit 0
}

if (-not $config.enabled) { exit 0 }

# Read hook input from stdin (StreamReader with UTF-8 auto-strips BOM on Windows)
$hookInput = ""
try {
    if (-not [Console]::IsInputRedirected) { exit 0 }
    $stream = [Console]::OpenStandardInput()
    $reader = New-Object System.IO.StreamReader($stream, [System.Text.Encoding]::UTF8)
    $hookInput = $reader.ReadToEnd()
    $reader.Close()
} catch {
    exit 0
}

if (-not $hookInput) { exit 0 }

try {
    $event = $hookInput | ConvertFrom-Json
} catch {
    exit 0
}

$rawEvent = $event.hook_event_name
if (-not $rawEvent) { exit 0 }

# Cursor IDE sends camelCase via Third-party skills; Claude Code sends PascalCase.
# Map to PascalCase so the switch below matches.
$cursorMap = @{
    "sessionStart" = "SessionStart"
    "sessionEnd" = "SessionEnd"
    "beforeSubmitPrompt" = "UserPromptSubmit"
    "stop" = "Stop"
    "preToolUse" = "UserPromptSubmit"
    "postToolUse" = "Stop"
    "subagentStop" = "Stop"
    "subagentStart" = "SubagentStart"
    "preCompact" = "PreCompact"
}
$hookEvent = if ($cursorMap.ContainsKey($rawEvent)) { $cursorMap[$rawEvent] } else { $rawEvent }

# Extract session ID (Claude Code: session_id, Cursor: conversation_id)
$sessionId = if ($event.session_id) { $event.session_id } elseif ($event.conversation_id) { $event.conversation_id } else { "default" }

# Extract cwd from event (used by path_rules for directory-based pack selection)
$cwd = if ($event.cwd) { $event.cwd } else { "" }

# Helper function to convert PSCustomObject to hashtable (PS 5.1 compat)
function ConvertTo-Hashtable {
    param([Parameter(ValueFromPipeline)]$obj)
    if ($null -eq $obj) { return $obj }
    if ($obj -is [hashtable]) { return $obj }
    # Check value types before PSCustomObject â€” PS 5.1 pipeline wraps primitives
    # in PSObject, making them match [PSCustomObject] when received via ValueFromPipeline.
    if ($obj -is [System.ValueType] -or $obj -is [string]) { return $obj }
    if ($obj -is [System.Collections.IEnumerable]) {
        return ,@($obj | ForEach-Object { ConvertTo-Hashtable $_ })
    }
    if ($obj -is [PSCustomObject]) {
        $ht = @{}
        foreach ($prop in $obj.PSObject.Properties) {
            $ht[$prop.Name] = ConvertTo-Hashtable $prop.Value
        }
        return $ht
    }
    return $obj
}

# --- Atomic state I/O helpers ---
function Write-StateAtomic {
    param([hashtable]$State, [string]$Path)
    $dir = Split-Path $Path -Parent
    if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    $tmp = "$Path.$PID.tmp"
    $prevCulture = [System.Threading.Thread]::CurrentThread.CurrentCulture
    try {
        [System.Threading.Thread]::CurrentThread.CurrentCulture = [System.Globalization.CultureInfo]::InvariantCulture
        $State | ConvertTo-Json -Depth 3 | Set-Content $tmp -Encoding UTF8
        if ($PSVersionTable.PSVersion.Major -ge 7) {
            # PS 7+ / .NET Core: Move-Item -Force performs atomic overwrite (no delete gap).
            Move-Item -Path $tmp -Destination $Path -Force
        } else {
            # PS 5.1: delete target then move (atomic on NTFS same-volume, sub-ms gap).
            if (Test-Path $Path) { [System.IO.File]::Delete($Path) }
            [System.IO.File]::Move($tmp, $Path)
        }
    } catch {
        Remove-Item $tmp -ErrorAction SilentlyContinue
    } finally {
        [System.Threading.Thread]::CurrentThread.CurrentCulture = $prevCulture
    }
}

function Read-StateWithRetry {
    param([string]$Path)
    # Clean up orphaned .tmp files left by safety timer [Environment]::Exit(1),
    # which skips finally blocks and may leave partial writes behind.
    $dir = Split-Path $Path -Parent
    if ($dir -and (Test-Path $dir)) {
        $base = Split-Path $Path -Leaf
        Get-ChildItem -Path $dir -Filter "$base.*.tmp" -ErrorAction SilentlyContinue |
            ForEach-Object { Remove-Item $_.FullName -Force -ErrorAction SilentlyContinue }
    }
    $delays = @(50, 100, 200)
    for ($i = 0; $i -le $delays.Count; $i++) {
        try {
            if (Test-Path $Path) {
                $raw = Get-Content $Path -Raw
                if ($raw -and $raw.Trim().Length -gt 0) {
                    $stateObj = $raw | ConvertFrom-Json
                    $converted = ConvertTo-Hashtable $stateObj
                    if ($converted -is [hashtable]) { return $converted }
                }
            }
            return @{}
        } catch {
            if ($i -lt $delays.Count) {
                Start-Sleep -Milliseconds $delays[$i]
            }
        }
    }
    return @{}
}

# Read state
$state = Read-StateWithRetry -Path $StatePath

# --- Session cleanup: expire old sessions ---
$now = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
$ttlDays = if ($config.session_ttl_days) { $config.session_ttl_days } else { 7 }
$cutoff = $now - ($ttlDays * 86400)
$sessionPacks = if ($state.ContainsKey("session_packs")) { $state["session_packs"] } else { @{} }
$sessionPacksClean = @{}
foreach ($sid in $sessionPacks.Keys) {
    $packData = $sessionPacks[$sid]
    if ($packData -is [hashtable]) {
        # New format with timestamp
        $lastUsed = if ($packData.ContainsKey("last_used")) { $packData["last_used"] } else { 0 }
        if ($lastUsed -gt $cutoff) {
            if ($sid -eq $sessionId) {
                $packData["last_used"] = $now
            }
            $sessionPacksClean[$sid] = $packData
        }
    } elseif ($sid -eq $sessionId) {
        # Old format, upgrade active session
        $sessionPacksClean[$sid] = @{ pack = $packData; last_used = $now }
    } elseif ($packData -is [string]) {
        # Old format for inactive sessions - keep for now (migration path)
        $sessionPacksClean[$sid] = $packData
    }
}
$state["session_packs"] = $sessionPacksClean
$stateDirty = $false
if ($sessionPacksClean.Count -ne $sessionPacks.Count) {
    $stateDirty = $true
}

# --- Map Claude Code hook event -> CESP manifest category ---
$category = $null
$ntype = $event.notification_type

switch ($hookEvent) {
    "SessionStart" {
        $category = "session.start"
    }
    "Stop" {
        $category = "task.complete"
        # Debounce rapid Stop events (5s cooldown)
        $now = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
        $lastStop = if ($state.ContainsKey("last_stop_time")) { $state["last_stop_time"] } else { 0 }
        if (($now - $lastStop) -lt 5) {
            $category = $null
        }
        $state["last_stop_time"] = $now
    }
    "Notification" {
        if ($ntype -eq "permission_prompt") {
            # PermissionRequest event handles the sound, skip here
            $category = $null
        } elseif ($ntype -eq "idle_prompt") {
            # Stop event already played the sound
            $category = $null
        } else {
            # Other notification types (e.g., tool results) map to task.complete
            $category = "task.complete"
        }
    }
    "PermissionRequest" {
        $category = "input.required"
    }
    "UserPromptSubmit" {
        # Detect rapid prompts for "annoyed" easter egg
        $now = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
        $annoyedThreshold = if ($config.annoyed_threshold) { $config.annoyed_threshold } else { 3 }
        $annoyedWindow = if ($config.annoyed_window_seconds) { $config.annoyed_window_seconds } else { 10 }

        $allPrompts = if ($state.ContainsKey("prompt_timestamps")) { $state["prompt_timestamps"] } else { @{} }
        $recentPrompts = @()
        if ($allPrompts.ContainsKey($sessionId)) {
            $recentPrompts = @($allPrompts[$sessionId] | Where-Object { ($now - $_) -lt $annoyedWindow })
        }
        $recentPrompts += $now
        $allPrompts[$sessionId] = $recentPrompts
        $state["prompt_timestamps"] = $allPrompts

        if ($recentPrompts.Count -ge $annoyedThreshold) {
            $category = "user.spam"
        }
    }
    "PostToolUseFailure" {
        $category = "task.error"
    }
    "SubagentStart" {
        $category = "task.acknowledge"
    }
}

# Save state
try {
    Write-StateAtomic -State $state -Path $StatePath
} catch {
    if ($peonDebug) { Write-Warning "peon-ping: state write failed: $_" }
}

if (-not $category) { exit 0 }

# Check if category is enabled
try {
    $catEnabled = $config.categories.$category
    if ($catEnabled -eq $false) { exit 0 }
} catch {
    if ($peonDebug) { Write-Warning "peon-ping: category check failed for '$category': $_" }
}

# --- Pick a sound ---
$activePack = Get-ActivePack $config

# Support pack rotation
$rotationMode = $config.pack_rotation_mode
if (-not $rotationMode) { $rotationMode = "random" }

# --- Path rules: first glob match wins (layer 3 in override hierarchy) ---
# Beats rotation and default_pack; loses to session_override and local config.
$pathRulePack = $null
$pathRules = $config.path_rules
if ($cwd -and $pathRules) {
    foreach ($rule in $pathRules) {
        $pattern = $rule.pattern
        $candidate = $rule.pack
        if ($pattern -and $candidate -and ($cwd -like $pattern)) {
            $candidateDir = Join-Path $InstallDir "packs\$candidate"
            if (Test-Path $candidateDir -PathType Container) {
                $pathRulePack = $candidate
                break
            }
        }
    }
}
$defaultPack = Get-ActivePack $config

if ($rotationMode -eq "agentskill" -or $rotationMode -eq "session_override") {
    # Explicit per-session assignments (from skill)
    $sessionPacks = $state.session_packs
    if (-not $sessionPacks) { $sessionPacks = @{} }
    if ($sessionPacks.ContainsKey($sessionId) -and $sessionPacks[$sessionId]) {
        $packData = $sessionPacks[$sessionId]
        # Handle both old string format and new dict format
        if ($packData -is [hashtable]) {
            $candidate = $packData.pack
        } else {
            $candidate = $packData
        }
        $candidateDir = Join-Path $InstallDir "packs\$candidate"
        if ($candidate -and (Test-Path $candidateDir -PathType Container)) {
            $activePack = $candidate
            # Update timestamp
            $sessionPacks[$sessionId] = @{ pack = $candidate; last_used = [int][double]::Parse((Get-Date -UFormat %s)) }
            $state.session_packs = $sessionPacks
            $stateDirty = $true
        } else {
            # Pack missing, fall through hierarchy: path_rules > default_pack
            $activePack = if ($pathRulePack) { $pathRulePack } else { $defaultPack }
            $sessionPacks.Remove($sessionId)
            $state.session_packs = $sessionPacks
            $stateDirty = $true
        }
    } else {
        # No assignment: check session_packs["default"] (Cursor users without conversation_id)
        $defaultData = $sessionPacks.default
        if ($defaultData) {
            $candidate = if ($defaultData -is [hashtable]) { $defaultData.pack } else { $defaultData }
            $candidateDir = Join-Path $InstallDir "packs\$candidate"
            if ($candidate -and (Test-Path $candidateDir -PathType Container)) {
                $activePack = $candidate
            } else {
                $activePack = if ($pathRulePack) { $pathRulePack } else { $defaultPack }
            }
        } else {
            $activePack = if ($pathRulePack) { $pathRulePack } else { $defaultPack }
        }
    }
} elseif ($pathRulePack) {
    # Path rule wins over rotation and default
    $activePack = $pathRulePack
} elseif ($config.pack_rotation -and $config.pack_rotation.Count -gt 0) {
    if ($pathRulePack) {
        # Path rule beats rotation
        $activePack = $pathRulePack
    } else {
        # Automatic rotation
        $activePack = $config.pack_rotation | Get-Random
    }
} elseif ($pathRulePack) {
    # Path rule beats default_pack
    $activePack = $pathRulePack
}

$packDir = Join-Path $InstallDir "packs\$activePack"
$manifestPath = Join-Path $packDir "openpeon.json"
if (-not (Test-Path $manifestPath)) { exit 0 }

try {
    $manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json
} catch { exit 0 }

# Get sounds for this category
$catSounds = $null
try {
    $catSounds = $manifest.categories.$category.sounds
} catch {
    if ($peonDebug) { Write-Warning "peon-ping: sound lookup failed for category '$category': $_" }
}
if (-not $catSounds -or $catSounds.Count -eq 0) { exit 0 }

# Anti-repeat: avoid last played sound
$lastKey = "last_$category"
$lastPlayed = ""
if ($state.ContainsKey($lastKey)) {
    $lastPlayed = $state[$lastKey]
}

$candidates = @($catSounds | Where-Object { (Split-Path $_.file -Leaf) -ne $lastPlayed })
if ($candidates.Count -eq 0) { $candidates = @($catSounds) }

$chosen = $candidates | Get-Random
$soundFile = Split-Path $chosen.file -Leaf
$soundPath = Join-Path $packDir "sounds\$soundFile"

if (-not (Test-Path $soundPath)) { exit 0 }

# Icon resolution chain (CESP Â§5.5)
$iconPath = ""
$iconCandidate = ""
if ($chosen.icon) { $iconCandidate = $chosen.icon }
elseif ($manifest.categories.$category.icon) { $iconCandidate = $manifest.categories.$category.icon }
elseif ($manifest.icon) { $iconCandidate = $manifest.icon }
elseif (Test-Path (Join-Path $packDir "icon.png")) { $iconCandidate = "icon.png" }
if ($iconCandidate) {
    $resolved = [System.IO.Path]::GetFullPath((Join-Path $packDir $iconCandidate))
    $packRoot = [System.IO.Path]::GetFullPath($packDir) + [System.IO.Path]::DirectorySeparatorChar
    if ($resolved.StartsWith($packRoot) -and (Test-Path $resolved -PathType Leaf)) {
        $iconPath = $resolved
    }
}

# Save last played
$state[$lastKey] = $soundFile
try {
    Write-StateAtomic -State $state -Path $StatePath
} catch {
    if ($peonDebug) { Write-Warning "peon-ping: state write failed (last played): $_" }
}

# --- Delegate audio to win-play.ps1 in a detached process ---
$volume = $config.volume
if (-not $volume) { $volume = 0.5 }

$winPlayScript = Join-Path $InstallDir "scripts\win-play.ps1"
if (Test-Path $winPlayScript) {
    Start-Process -FilePath "powershell.exe" -ArgumentList "-NoProfile", "-NonInteractive", "-File", $winPlayScript, "-path", $soundPath, "-vol", $volume -WindowStyle Hidden
} else {
    if ($peonDebug) { Write-Warning "peon-ping: win-play.ps1 not found at '$winPlayScript' - audio skipped" }
}

exit 0
