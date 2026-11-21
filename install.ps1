<#
.SYNOPSIS
    SplitSpace Installer
.DESCRIPTION
    Dynamically discovers installed AI desktop applications (Google Antigravity,
    Claude Desktop, ChatGPT Desktop, Cursor, Windsurf, Perplexity, LM Studio, Chatbox)
    and registers native Windows Taskbar right-click Jump List tasks (+ <AppName> / + SplitSpace).
#>

[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$App = "auto",

    [Parameter()]
    [string]$TaskLabel = "",

    [Parameter()]
    [switch]$Force
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
    Write-Host "[ERROR] SplitSpace library files are missing from $libDir." -ForegroundColor Red
    exit 1
}

. $discoverScript
. $jumpListScript

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "  SplitSpace - AI Desktop Multi-Window Taskbar Utility     " -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""

$targetsToInstall = @()

if ($App -and $App -ne "auto" -and $App -ne "all") {
    Write-Host "[*] Searching for requested application '$App'..." -ForegroundColor Gray
    $resolved = Get-SplitSpaceTargetApp -AppName $App
    if ($resolved) {
        $targetsToInstall += $resolved
    } else {
        Write-Host ""
        Write-Host "[ERROR] Requested application '$App' was not found on this computer." -ForegroundColor Red
        Write-Host "Supported applications: Antigravity, Claude, ChatGPT, Cursor, Windsurf, Perplexity, LMStudio, Chatbox." -ForegroundColor Yellow
        exit 1
    }
} else {
    Write-Host "[*] Scanning system for installed AI desktop applications..." -ForegroundColor Gray
    $installed = Get-SplitSpaceTargetApp -AppName "auto"
    if ($installed -and $installed.Count -gt 0) {
        $targetsToInstall = $installed
    } else {
        Write-Host ""
        Write-Host "[NOTICE] No supported AI desktop applications were detected on this computer." -ForegroundColor Yellow
        Write-Host "Supported applications: Antigravity, Claude, ChatGPT, Cursor, Windsurf, Perplexity, LMStudio, Chatbox." -ForegroundColor Gray
        exit 1
    }
}

Write-Host "[OK] Detected $($targetsToInstall.Count) application(s) ready for SplitSpace:" -ForegroundColor Green
foreach ($t in $targetsToInstall) {
    Write-Host "     - $($t.DisplayName)" -ForegroundColor White
    Write-Host "       Executable: $($t.ExecutablePath)" -ForegroundColor Gray
    Write-Host "       Source:     $($t.DiscoverySource)" -ForegroundColor Gray
    if ($t.AumidHashes -and $t.AumidHashes.Count -gt 0) {
        Write-Host "       Hashes:     $($t.AumidHashes -join ', ')" -ForegroundColor DarkGray
    }
}
Write-Host ""

# Ensure dynamic multi-slot launcher is compiled and ready
$launcherSrc = Join-Path $scriptDir "bin\Launcher.cs"
$launcherDst = Join-Path $scriptDir "bin\splitspace.exe"
if (-not (Test-Path $launcherDst) -and (Test-Path $launcherSrc)) {
    $csc = "C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe"
    if (Test-Path $csc) {
        Write-Host "[*] Compiling dynamic multi-slot launcher..." -ForegroundColor Gray
        & $csc /target:winexe /r:System.Management.dll /out:$launcherDst $launcherSrc | Out-Null
    }
}

$successCount = 0
foreach ($t in $targetsToInstall) {
    $actualLabel = if ($TaskLabel) { $TaskLabel } else { "+ $($t.AppName)" }
    Write-Host "[*] Configuring taskbar integration for $($t.DisplayName)..." -ForegroundColor Gray
    $jumpRes = Set-SplitSpaceJumpList -TargetApp $t -TaskLabel $actualLabel
    if ($jumpRes) {
        Write-Host "[OK] Injected '$actualLabel' task for $($t.DisplayName)." -ForegroundColor Green
        $successCount++
    } else {
        Write-Host "[WARN] Could not register Jump List task for $($t.DisplayName)." -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
if ($successCount -gt 0) {
    Write-Host "Installation Complete! ($successCount application(s) configured)" -ForegroundColor Green
    Write-Host "How to use:" -ForegroundColor White
    Write-Host "  1. Right-click the app icon on your Windows Taskbar." -ForegroundColor Gray
    Write-Host "  2. Click the '+' task (e.g. '+ Antigravity', '+ Cursor') to open an independent floating window." -ForegroundColor Gray
    Write-Host "  3. Work on multiple project folders or prompts simultaneously." -ForegroundColor Gray
} else {
    Write-Host "Installation completed with warnings." -ForegroundColor Yellow
}
Write-Host "============================================================" -ForegroundColor Cyan
