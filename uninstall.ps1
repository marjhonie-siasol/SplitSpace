<#
.SYNOPSIS
    SplitSpace Uninstaller
.DESCRIPTION
    Restores default Windows Jump List configuration, removes '+ SplitSpace' / '+ <AppName>' taskbar tasks,
    cleans up shortcuts, and optionally clears secondary session caches.
#>

[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$App = "all",

    [Parameter()]
    [switch]$KeepProfiles
)

$scriptDir = $PSScriptRoot
if (-not $scriptDir) {
    $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
}
if (-not $scriptDir) {
    $scriptDir = (Get-Location).Path
}

$libDir = Join-Path $scriptDir "lib"
$discoverScript = Join-Path $libDir "discover.ps1"
$jumpListScript = Join-Path $libDir "jumplist.ps1"

if (-not (Test-Path $discoverScript) -or -not (Test-Path $jumpListScript)) {
    Write-Host "[ERROR] SplitSpace library files missing from $libDir." -ForegroundColor Red
    exit 1
}

. $discoverScript
. $jumpListScript

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "  SplitSpace - Removal & Uninstallation                    " -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""

$targetsToUninstall = @()

if ($App -and $App -ne "all" -and $App -ne "auto") {
    $resolved = Get-SplitSpaceTargetApp -AppName $App
    if ($resolved) {
        $targetsToUninstall += $resolved
    }
} else {
    $targetsToUninstall = @(Get-SplitSpaceTargetApp -AppName "auto")
}

if ($targetsToUninstall.Count -gt 0) {
    foreach ($t in $targetsToUninstall) {
        Write-Host "[*] Restoring taskbar Jump List for $($t.DisplayName)..." -ForegroundColor Gray
        Remove-SplitSpaceJumpList -TargetApp $t | Out-Null
        Write-Host "[OK] Cleaned taskbar tasks for $($t.DisplayName)." -ForegroundColor Green
    }
} else {
    Write-Host "[*] Performing generic cleanup of CustomDestinations..." -ForegroundColor Gray
    $customDestDir = Join-Path $env:APPDATA "Microsoft\Windows\Recent\CustomDestinations"
    if (Test-Path $customDestDir) {
        Get-ChildItem -Path $customDestDir -Filter "*.customDestinations-ms.bak" -ErrorAction SilentlyContinue | ForEach-Object {
            $dest = $_.FullName.Substring(0, $_.FullName.Length - 4)
            Copy-Item -Path $_.FullName -Destination $dest -Force
            Remove-Item -Path $_.FullName -Force -ErrorAction SilentlyContinue
        }
    }
}

# Explicit cleanup for Cursor if previously modified
$customDestDir = Join-Path $env:APPDATA "Microsoft\Windows\Recent\CustomDestinations"
$cursorHash = "8346f26264213ffa"
$cursorDest = Join-Path $customDestDir "$cursorHash.customDestinations-ms"
$cursorBak = "$cursorDest.bak"
if (Test-Path $cursorBak) {
    Copy-Item -Path $cursorBak -Destination $cursorDest -Force -ErrorAction SilentlyContinue
    Remove-Item -Path $cursorBak -Force -ErrorAction SilentlyContinue
}

# Clean Start Menu shortcuts
$startMenuDir = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs"
if (Test-Path $startMenuDir) {
    Get-ChildItem -Path $startMenuDir -Filter "SplitSpace*.lnk" -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
}

# Clean session profiles if not flagged to keep
$splitSpaceBase = Join-Path $env:LOCALAPPDATA "SplitSpace"
if (-not $KeepProfiles -and (Test-Path $splitSpaceBase)) {
    Write-Host "[*] Cleaning session cache and profile storage..." -ForegroundColor Gray
    Remove-Item -Path $splitSpaceBase -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "[OK] Cleaned session profiles at $splitSpaceBase." -ForegroundColor Green
}

# Notify Windows Shell
try {
    [SplitSpaceShell.JumpListHelper]::NotifyShell()
} catch {}

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "SplitSpace Uninstalled Successfully!" -ForegroundColor Green
Write-Host "The '+ SplitSpace' task has been removed from your taskbar." -ForegroundColor White
Write-Host "Windows has returned to its default single-window behavior." -ForegroundColor Gray
Write-Host "============================================================" -ForegroundColor Cyan
