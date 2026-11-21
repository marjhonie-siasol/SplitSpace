<#
.SYNOPSIS
    SplitSpace Application Discovery Engine
.DESCRIPTION
    Dynamically scans running processes, pinned taskbar shortcuts, start menu entries,
    standard directories, and the Windows Registry to discover installed AI desktop applications
    (such as Google Antigravity, Claude Desktop, ChatGPT Desktop, Cursor, Windsurf, Perplexity, LM Studio, Chatbox).
#>

function Get-SplitSpaceSupportedApps {
    [CmdletBinding()]
    param()

    return @{
        "Antigravity" = @{
            AppName         = "Antigravity"
            DisplayName     = "Google Antigravity"
            ProcessName     = "Antigravity"
            DefaultUserData = "$env:APPDATA\Antigravity"
            Aumid           = "com.google.antigravity"
            CandidateHashes = @("58aa7a7fc099eefc", "5f7b5f1e01b83767", "1af8d2aae9c8f3b3")
            DaemonDir       = "$env:USERPROFILE\.gemini\antigravity\daemon"
            KnownPaths      = @(
                "$env:LOCALAPPDATA\Programs\antigravity\Antigravity.exe",
                "$env:ProgramFiles\Antigravity\Antigravity.exe",
                "$env:ProgramFiles(x86)\Antigravity\Antigravity.exe"
            )
        }
        "Claude" = @{
            AppName         = "Claude"
            DisplayName     = "Anthropic Claude Desktop"
            ProcessName     = "Claude"
            DefaultUserData = "$env:APPDATA\Claude"
            Aumid           = "Anthropic.Claude"
            CandidateHashes = @()
            DaemonDir       = ""
            KnownPaths      = @(
                "$env:LOCALAPPDATA\Programs\Claude\Claude.exe",
                "$env:LOCALAPPDATA\AnthropicClaude\Claude.exe",
                "$env:ProgramFiles\Claude\Claude.exe",
                "$env:ProgramFiles(x86)\Claude\Claude.exe"
            )
        }
        "ChatGPT" = @{
            AppName         = "ChatGPT"
            DisplayName     = "OpenAI ChatGPT Desktop"
            ProcessName     = "ChatGPT"
            DefaultUserData = "$env:APPDATA\ChatGPT"
            Aumid           = "OpenAI.ChatGPT"
            CandidateHashes = @()
            DaemonDir       = ""
            KnownPaths      = @(
                "$env:LOCALAPPDATA\Programs\ChatGPT\ChatGPT.exe",
                "$env:ProgramFiles\ChatGPT\ChatGPT.exe",
                "$env:ProgramFiles(x86)\ChatGPT\ChatGPT.exe"
            )
        }
        "Cursor" = @{
            AppName         = "Cursor"
            DisplayName     = "Cursor"
            ProcessName     = "Cursor"
            DefaultUserData = "$env:APPDATA\Cursor"
            Aumid           = "Cursor"
            CandidateHashes = @("8346f26264213ffa")
            DaemonDir       = ""
            KnownPaths      = @(
                "$env:LOCALAPPDATA\Programs\cursor\Cursor.exe",
                "$env:ProgramFiles\Cursor\Cursor.exe",
                "$env:ProgramFiles(x86)\Cursor\Cursor.exe"
            )
        }
        "Windsurf" = @{
            AppName         = "Windsurf"
            DisplayName     = "Codeium Windsurf"
            ProcessName     = "Windsurf"
            DefaultUserData = "$env:APPDATA\Windsurf"
            Aumid           = "Windsurf"
            CandidateHashes = @()
            DaemonDir       = ""
            KnownPaths      = @(
                "$env:LOCALAPPDATA\Programs\windsurf\Windsurf.exe",
                "$env:ProgramFiles\Windsurf\Windsurf.exe",
                "$env:ProgramFiles(x86)\Windsurf\Windsurf.exe"
            )
        }
        "Perplexity" = @{
            AppName         = "Perplexity"
            DisplayName     = "Perplexity Desktop"
            ProcessName     = "Perplexity"
            DefaultUserData = "$env:APPDATA\Perplexity"
            Aumid           = "Perplexity"
            CandidateHashes = @()
            DaemonDir       = ""
            KnownPaths      = @(
                "$env:LOCALAPPDATA\Programs\Perplexity\Perplexity.exe",
                "$env:ProgramFiles\Perplexity\Perplexity.exe",
                "$env:ProgramFiles(x86)\Perplexity\Perplexity.exe"
            )
        }
        "LMStudio" = @{
            AppName         = "LMStudio"
            DisplayName     = "LM Studio"
            ProcessName     = "LM Studio"
            DefaultUserData = "$env:APPDATA\LM Studio"
            Aumid           = "elementlabs.lmstudio"
            CandidateHashes = @()
            DaemonDir       = ""
            KnownPaths      = @(
                "$env:LOCALAPPDATA\Programs\LM Studio\LM Studio.exe",
                "$env:ProgramFiles\LM Studio\LM Studio.exe",
                "$env:ProgramFiles(x86)\LM Studio\LM Studio.exe"
            )
        }
        "Chatbox" = @{
            AppName         = "Chatbox"
            DisplayName     = "Chatbox"
            ProcessName     = "Chatbox"
            DefaultUserData = "$env:APPDATA\chatbox"
            Aumid           = "xyz.chatboxapp.app"
            CandidateHashes = @()
            DaemonDir       = ""
            KnownPaths      = @(
                "$env:LOCALAPPDATA\Programs\chatbox\Chatbox.exe",
                "$env:ProgramFiles\Chatbox\Chatbox.exe",
                "$env:ProgramFiles(x86)\Chatbox\Chatbox.exe"
            )
        }
    }
}

function Find-AllJumpListHashes {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ExecutablePath,

        [Parameter(Mandatory = $true)]
        [string]$AppName,

        [Parameter()]
        [string]$ProcessName = "",

        [Parameter()]
        [string[]]$CandidateHashes = @()
    )

    $hashes = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($ch in $CandidateHashes) {
        if ($ch -and $ch.Length -eq 16) { [void]$hashes.Add($ch.ToLowerInvariant()) }
    }

    $customDir = Join-Path $env:APPDATA "Microsoft\Windows\Recent\CustomDestinations"
    $autoDir = Join-Path $env:APPDATA "Microsoft\Windows\Recent\AutomaticDestinations"
    $targetExe = [System.IO.Path]::GetFileName($ExecutablePath)
    $searchTokens = @($targetExe, $AppName, $ProcessName) | Where-Object { $_ }

    foreach ($dir in @($customDir, $autoDir)) {
        if (-not (Test-Path $dir)) { continue }
        Get-ChildItem -Path $dir -Filter "*Destinations-ms" -ErrorAction SilentlyContinue | ForEach-Object {
            $base = $_.BaseName.ToLowerInvariant()
            if ($base.Length -eq 16) {
                try {
                    $bytes = [System.IO.File]::ReadAllBytes($_.FullName)
                    $ascii = [System.Text.Encoding]::ASCII.GetString($bytes)
                    $utf16 = [System.Text.Encoding]::Unicode.GetString($bytes)

                    # Do not associate VS Code / Antigravity IDE with main Antigravity app
                    if ($targetExe -eq "Antigravity.exe" -and ($utf16 -match "antigravity-ide" -or $utf16 -match "Antigravity IDE" -or $ascii -match "antigravity-ide" -or $ascii -match "Antigravity IDE")) {
                        return
                    }

                    foreach ($tok in $searchTokens) {
                        if ($ascii.IndexOf($tok, [System.StringComparison]::OrdinalIgnoreCase) -ge 0 -or
                            $utf16.IndexOf($tok, [System.StringComparison]::OrdinalIgnoreCase) -ge 0) {
                            [void]$hashes.Add($base)
                            break
                        }
                    }
                } catch {}
            }
        }
    }

    return @($hashes)
}

function Get-SplitSpaceTargetApp {
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)]
        [string]$AppName = "auto"
    )

    $supported = Get-SplitSpaceSupportedApps

    # If specific app requested
    if ($AppName -and $AppName -ne "auto" -and $AppName -ne "all") {
        # Search by key or DisplayName
        $matchedKey = $null
        foreach ($k in $supported.Keys) {
            if ($k.Equals($AppName, [System.StringComparison]::OrdinalIgnoreCase) -or
                $supported[$k].DisplayName.Equals($AppName, [System.StringComparison]::OrdinalIgnoreCase)) {
                $matchedKey = $k
                break
            }
        }

        if (-not $matchedKey) {
            Write-Error "Unsupported application '$AppName'. Supported: $($supported.Keys -join ', ')"
            return $null
        }

        return Resolve-SingleAppDetails -AppDef $supported[$matchedKey]
    }

    # Auto mode: Scan all supported apps and return all installed ones
    $installed = @()
    foreach ($k in $supported.Keys) {
        $resolved = Resolve-SingleAppDetails -AppDef $supported[$k]
        if ($resolved) {
            $installed += $resolved
        }
    }

    return $installed
}

function Resolve-SingleAppDetails {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$AppDef
    )

    $foundExe = $null
    $discoverySource = ""

    # Strategy 1: Check running process
    try {
        $runningProc = Get-CimInstance Win32_Process -Filter "Name = '$($AppDef.ProcessName).exe'" -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($runningProc -and $runningProc.ExecutablePath -and (Test-Path $runningProc.ExecutablePath)) {
            $foundExe = $runningProc.ExecutablePath
            $discoverySource = "Running Process (PID $($runningProc.ProcessId))"
        }
    } catch {}

    # Strategy 2: Check pinned taskbar shortcut
    if (-not $foundExe) {
        $taskbarPath = "$env:APPDATA\Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar"
        if (Test-Path $taskbarPath) {
            $sh = New-Object -ComObject WScript.Shell
            Get-ChildItem -Path $taskbarPath -Filter "*$($AppDef.ProcessName)*.lnk" -ErrorAction SilentlyContinue | ForEach-Object {
                if (-not $foundExe) {
                    try {
                        $sc = $sh.CreateShortcut($_.FullName)
                        if ($sc.TargetPath -and (Test-Path $sc.TargetPath)) {
                            $foundExe = $sc.TargetPath
                            $discoverySource = "Taskbar Shortcut ($($_.Name))"
                        }
                    } catch {}
                }
            }
        }
    }

    # Strategy 3: Check known installation paths
    if (-not $foundExe) {
        foreach ($kp in $AppDef.KnownPaths) {
            if (Test-Path $kp) {
                $foundExe = (Resolve-Path $kp).Path
                $discoverySource = "Standard Install Path"
                break
            }
        }
    }

    # Strategy 4: Check Start Menu shortcuts
    if (-not $foundExe) {
        $startMenuFolders = @(
            "$env:APPDATA\Microsoft\Windows\Start Menu\Programs",
            "$env:ProgramData\Microsoft\Windows\Start Menu\Programs"
        )
        $sh = New-Object -ComObject WScript.Shell
        foreach ($sm in $startMenuFolders) {
            if (Test-Path $sm) {
                Get-ChildItem -Path $sm -Filter "*$($AppDef.ProcessName)*.lnk" -Recurse -ErrorAction SilentlyContinue | ForEach-Object {
                    if (-not $foundExe) {
                        try {
                            $sc = $sh.CreateShortcut($_.FullName)
                            if ($sc.TargetPath -and (Test-Path $sc.TargetPath)) {
                                $foundExe = $sc.TargetPath
                                $discoverySource = "Start Menu ($($_.Name))"
                            }
                        } catch {}
                    }
                }
            }
        }
    }

    # Strategy 5: Check Windows Registry Uninstall entries
    if (-not $foundExe) {
        $regKeys = @(
            "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall",
            "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall"
        )
        foreach ($rk in $regKeys) {
            if (Test-Path $rk) {
                Get-ChildItem $rk -ErrorAction SilentlyContinue | ForEach-Object {
                    if (-not $foundExe) {
                        $disp = $_.GetValue("DisplayName")
                        $loc = $_.GetValue("InstallLocation")
                        if ($disp -and ($disp -like "*$($AppDef.ProcessName)*") -and $loc) {
                            $candidate = Join-Path $loc "$($AppDef.ProcessName).exe"
                            if (Test-Path $candidate) {
                                $foundExe = $candidate
                                $discoverySource = "Windows Registry ($disp)"
                            }
                        }
                    }
                }
            }
        }
    }

    if (-not $foundExe) {
        return $null
    }

    # Resolve all CustomDestinations AUMID hashes dynamically
    $candidateList = if ($AppDef.CandidateHashes) { $AppDef.CandidateHashes } else { @() }
    $allHashes = Find-AllJumpListHashes -ExecutablePath $foundExe -AppName $AppDef.AppName -ProcessName $AppDef.ProcessName -CandidateHashes $candidateList
    $primaryHash = if ($allHashes -and $allHashes.Count -gt 0) { $allHashes[0] } else { "" }

    # Resolve active language server daemon port if applicable (Antigravity)
    $activeHubUrl = $null
    $activeHubPid = $null
    if ($AppDef.DaemonDir -and (Test-Path $AppDef.DaemonDir)) {
        Get-ChildItem -Path $AppDef.DaemonDir -Filter "hub_*.json" -ErrorAction SilentlyContinue | ForEach-Object {
            try {
                $info = Get-Content $_.FullName -Raw | ConvertFrom-Json
                if ($info -and $info.pid) {
                    $lsProc = Get-Process -Id $info.pid -ErrorAction SilentlyContinue
                    if ($lsProc -and $lsProc.ProcessName -eq "language_server" -and $info.httpsPort) {
                        $activeHubUrl = "https://127.0.0.1:$($info.httpsPort)/"
                        $activeHubPid = $info.pid
                    }
                }
            } catch {}
        }
    }

    return [PSCustomObject]@{
        AppName          = $AppDef.AppName
        DisplayName      = $AppDef.DisplayName
        ProcessName      = $AppDef.ProcessName
        ExecutablePath   = $foundExe
        DiscoverySource  = $discoverySource
        AppUserModelId   = $AppDef.Aumid
        AumidHash        = $primaryHash
        AumidHashes      = $allHashes
        DefaultUserData  = $AppDef.DefaultUserData
        ActiveHubUrl     = $activeHubUrl
        ActiveHubPid     = $activeHubPid
        IsRunning        = [bool](Get-Process -Name $AppDef.ProcessName -ErrorAction SilentlyContinue)
    }
}
