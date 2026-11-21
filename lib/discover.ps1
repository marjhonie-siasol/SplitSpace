<#
.SYNOPSIS
    SplitSpace Application Discovery Engine
.DESCRIPTION
    Dynamically scans running processes, WindowsApp Execution Aliases, Appx packages,
    pinned taskbar shortcuts, start menu entries, standard directories, and the Windows Registry
    to discover installed AI desktop applications (such as Google Antigravity, Anthropic Claude Desktop,
    OpenAI ChatGPT Desktop, Windsurf, Perplexity, LM Studio, Chatbox).
    Note: Cursor is intentionally excluded because it provides native multi-window support via Ctrl+Shift+N
    and uses an internal SQLite state database that invalidates sessions under isolated user-data-dir switches.
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
            CandidateHashes = @("7ac06f21f51c55e5", "58aa7a7fc099eefc", "5f7b5f1e01b83767", "1af8d2aae9c8f3b3")
            DaemonDir       = "$env:USERPROFILE\.gemini\antigravity\daemon"
            PackageFamily   = ""
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
            DefaultUserData = "$env:LOCALAPPDATA\Claude-Data\claude_pzs8sxrjxfjjc"
            Aumid           = "Claude_pzs8sxrjxfjjc!Claude"
            CandidateHashes = @("5b74df9d69366704")
            DaemonDir       = ""
            PackageFamily   = "Claude_pzs8sxrjxfjjc"
            KnownPaths      = @(
                "$env:LOCALAPPDATA\Microsoft\WindowsApps\Claude_pzs8sxrjxfjjc\claude-desktop.exe",
                "$env:LOCALAPPDATA\Microsoft\WindowsApps\claude-desktop.exe",
                "$env:LOCALAPPDATA\Programs\Claude\Claude.exe",
                "$env:LOCALAPPDATA\AnthropicClaude\Claude.exe",
                "$env:ProgramFiles\Claude\Claude.exe"
            )
        }
        "ChatGPT" = @{
            AppName         = "ChatGPT"
            DisplayName     = "OpenAI ChatGPT Desktop"
            ProcessName     = "ChatGPT"
            DefaultUserData = "$env:LOCALAPPDATA\Packages\OpenAI.Codex_2p2nqsd0c76g0\LocalCache\Roaming\Codex"
            Aumid           = "OpenAI.Codex_2p2nqsd0c76g0!App"
            CandidateHashes = @("3c6e5c18e9f546e6")
            DaemonDir       = ""
            PackageFamily   = "OpenAI.Codex_2p2nqsd0c76g0"
            KnownPaths      = @(
                "$env:LOCALAPPDATA\Microsoft\WindowsApps\OpenAI.Codex_2p2nqsd0c76g0\chatgpt-desktop.exe",
                "$env:LOCALAPPDATA\Microsoft\WindowsApps\chatgpt-desktop.exe",
                "$env:LOCALAPPDATA\Programs\ChatGPT\ChatGPT.exe",
                "$env:ProgramFiles\ChatGPT\ChatGPT.exe"
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
            PackageFamily   = ""
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
            PackageFamily   = ""
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
            PackageFamily   = ""
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
            PackageFamily   = ""
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
    $aliasExe = $null
    $iconPath = $null
    $discoverySource = ""

    # Strategy 1: Check AppExecutionAlias in WindowsApps
    foreach ($kp in $AppDef.KnownPaths) {
        if ($kp -match "WindowsApps" -and (Test-Path $kp)) {
            $aliasExe = (Resolve-Path $kp).Path
            $foundExe = $aliasExe
            $discoverySource = "WindowsApp Execution Alias"
            break
        }
    }

    # Strategy 2: Check AppX package installation
    if (-not $foundExe -and $AppDef.PackageFamily) {
        try {
            $pkg = Get-AppxPackage | Where-Object { $_.PackageFamilyName -eq $AppDef.PackageFamily -or $_.Name -like "*$($AppDef.AppName)*" } | Select-Object -First 1
            if ($pkg -and $pkg.InstallLocation -and (Test-Path $pkg.InstallLocation)) {
                $candidate = Join-Path $pkg.InstallLocation "app\$($AppDef.ProcessName).exe"
                if (-not (Test-Path $candidate)) {
                    $candidate = Join-Path $pkg.InstallLocation "$($AppDef.ProcessName).exe"
                }
                if (Test-Path $candidate) {
                    $foundExe = $candidate
                    $discoverySource = "Windows Store Package ($($pkg.Name))"
                }
            }
        } catch {}
    }

    # Strategy 3: Check running process
    if (-not $foundExe) {
        try {
            $runningProc = Get-CimInstance Win32_Process -Filter "Name = '$($AppDef.ProcessName).exe'" -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($runningProc -and $runningProc.ExecutablePath -and (Test-Path $runningProc.ExecutablePath)) {
                $foundExe = $runningProc.ExecutablePath
                $discoverySource = "Running Process (PID $($runningProc.ProcessId))"
            }
        } catch {}
    }

    # Strategy 4: Check pinned taskbar shortcut
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

    # Strategy 5: Check known installation paths
    if (-not $foundExe) {
        foreach ($kp in $AppDef.KnownPaths) {
            if (Test-Path $kp) {
                $foundExe = (Resolve-Path $kp).Path
                $discoverySource = "Standard Install Path"
                break
            }
        }
    }

    # Strategy 6: Check Start Menu shortcuts
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

    # Strategy 7: Check Windows Registry Uninstall entries
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

    # Resolve authentic high-resolution icon
    $splitSpaceBase = Join-Path $env:LOCALAPPDATA "SplitSpace"
    $iconsDir = Join-Path $splitSpaceBase "icons"
    if (-not (Test-Path $iconsDir)) {
        New-Item -ItemType Directory -Path $iconsDir -Force | Out-Null
    }

    if ($AppDef.AppName -eq "ChatGPT") {
        try {
            $gptPkg = Get-AppxPackage | Where-Object { $_.PackageFamilyName -eq "OpenAI.Codex_2p2nqsd0c76g0" } | Select-Object -First 1
            if ($gptPkg -and $gptPkg.InstallLocation) {
                $darkIco = Join-Path $gptPkg.InstallLocation "app\resources\chatgpt-app-dark.ico"
                $stagedIco = Join-Path $iconsDir "ChatGPT.ico"
                if (Test-Path $darkIco) {
                    Copy-Item -Path $darkIco -Destination $stagedIco -Force -ErrorAction SilentlyContinue
                    $iconPath = $stagedIco
                } else {
                    $genIco = Join-Path $gptPkg.InstallLocation "app\resources\icon-chatgpt.ico"
                    if (Test-Path $genIco) {
                        Copy-Item -Path $genIco -Destination $stagedIco -Force -ErrorAction SilentlyContinue
                        $iconPath = $stagedIco
                    }
                }
            }
        } catch {}
    } elseif ($AppDef.AppName -eq "Claude") {
        try {
            $cPkg = Get-AppxPackage | Where-Object { $_.PackageFamilyName -eq "Claude_pzs8sxrjxfjjc" } | Select-Object -First 1
            if ($cPkg -and $cPkg.InstallLocation) {
                $cExe = Join-Path $cPkg.InstallLocation "app\Claude.exe"
                if (Test-Path $cExe) {
                    $iconPath = "$cExe,0"
                }
            }
            # Remove legacy monochrome tray icon if previously cached
            $stagedIco = Join-Path $iconsDir "Claude.ico"
            if (Test-Path $stagedIco) {
                Remove-Item -Path $stagedIco -Force -ErrorAction SilentlyContinue
            }
        } catch {}
    }

    if (-not $iconPath) {
        $iconPath = "$foundExe,0"
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
        ExecutionAlias   = $aliasExe
        IconPath         = $iconPath
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
