<#
.SYNOPSIS
    SplitSpace Process Decoupler and Multi-Window Launcher
.DESCRIPTION
    Dynamically launches an independent floating window for any supported AI desktop application
    (such as Google Antigravity, Claude Desktop, ChatGPT Desktop, Cursor, Windsurf, Perplexity, LM Studio, Chatbox).
    Resolves all runtime paths dynamically without any hardcoded user directories.
#>

[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$AppName = "auto",

    [Parameter()]
    [int]$Slot = 0,

    [Parameter()]
    [switch]$Isolated,

    [Parameter()]
    [switch]$Reset
)

$scriptDir = $PSScriptRoot
if (-not $scriptDir) {
    $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
}
if (-not $scriptDir) {
    $scriptDir = (Get-Location).Path
}
$projectRoot = Split-Path -Parent $scriptDir
$libDir = Join-Path $projectRoot "lib"
$discoverScript = Join-Path $libDir "discover.ps1"

if (-not (Test-Path $discoverScript)) {
    Write-Error "Discovery engine not found at $discoverScript"
    exit 1
}
. $discoverScript

# Resolve target app dynamically
$targetApp = $null
if ($AppName -and $AppName -ne "auto") {
    $targetApp = Get-SplitSpaceTargetApp -AppName $AppName
} else {
    # Auto-detect: first check which supported AI app is currently running
    $installed = Get-SplitSpaceTargetApp -AppName "auto"
    foreach ($cand in $installed) {
        if ($cand.IsRunning) {
            $targetApp = $cand
            break
        }
    }
    # If none is currently running, default to the first installed app
    if (-not $targetApp -and $installed.Count -gt 0) {
        $targetApp = $installed[0]
    }
}

if (-not $targetApp -or -not (Test-Path $targetApp.ExecutablePath)) {
    Write-Error "Could not locate application executable for '$AppName'."
    exit 1
}

# If application is already active on screen and user didn't explicitly request isolated sandbox,
# trigger native concurrent window
if ($targetApp.IsRunning -and (-not $Isolated)) {
    $csharpCode = @'
    using System;
    using System.Text;
    using System.Runtime.InteropServices;
    using System.Threading;

    public class SplitSpaceWindowTrigger {
        [StructLayout(LayoutKind.Sequential)]
        public struct RECT {
            public int Left, Top, Right, Bottom;
        }

        public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);
        [DllImport("user32.dll")] public static extern bool EnumWindows(EnumWindowsProc lpEnumFunc, IntPtr lParam);
        [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint lpdwProcessId);
        [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr hWnd);
        [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
        [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
        [DllImport("user32.dll")] public static extern void keybd_event(byte bVk, byte bScan, uint dwFlags, UIntPtr dwExtraInfo);
        [DllImport("user32.dll")] public static extern int GetClassName(IntPtr hWnd, StringBuilder lpClassName, int nMaxCount);
        [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect);

        const byte VK_CONTROL = 0x11;
        const byte VK_SHIFT = 0x10;
        const byte VK_N = 0x4E;
        const uint KEYEVENTF_KEYUP = 0x0002;

        public static bool SpawnFloatingWindow(string processName) {
            IntPtr targetHwnd = IntPtr.Zero;
            EnumWindows((hWnd, lParam) => {
                if (!IsWindowVisible(hWnd)) return true;

                uint pid;
                GetWindowThreadProcessId(hWnd, out pid);
                try {
                    var proc = System.Diagnostics.Process.GetProcessById((int)pid);
                    if (proc.ProcessName.Equals(processName, StringComparison.OrdinalIgnoreCase)) {
                        StringBuilder cls = new StringBuilder(256);
                        GetClassName(hWnd, cls, 256);
                        RECT r;
                        GetWindowRect(hWnd, out r);
                        int width = r.Right - r.Left;
                        int height = r.Bottom - r.Top;

                        // Target the main application container window (Chrome_WidgetWin_1 or main UI window)
                        if ((cls.ToString().Contains("Chrome_WidgetWin_1") || cls.ToString().Contains("Widget")) && width > 200 && height > 200) {
                            targetHwnd = hWnd;
                            return false;
                        } else if (targetHwnd == IntPtr.Zero && width > 200 && height > 200) {
                            targetHwnd = hWnd;
                        }
                    }
                } catch {}
                return true;
            }, IntPtr.Zero);

            if (targetHwnd == IntPtr.Zero) return false;

            ShowWindow(targetHwnd, 9); // SW_RESTORE
            SetForegroundWindow(targetHwnd);
            Thread.Sleep(120);

            // Send Ctrl+Shift+N (Standard Electron/Chromium accelerator for new window)
            keybd_event(VK_CONTROL, 0, 0, UIntPtr.Zero);
            keybd_event(VK_SHIFT, 0, 0, UIntPtr.Zero);
            keybd_event(VK_N, 0, 0, UIntPtr.Zero);
            Thread.Sleep(50);
            keybd_event(VK_N, 0, KEYEVENTF_KEYUP, UIntPtr.Zero);
            keybd_event(VK_SHIFT, 0, KEYEVENTF_KEYUP, UIntPtr.Zero);
            keybd_event(VK_CONTROL, 0, KEYEVENTF_KEYUP, UIntPtr.Zero);

            return true;
        }
    }
'@

    if (-not ([System.Management.Automation.PSTypeName]'SplitSpaceWindowTrigger').Type) {
        Add-Type -TypeDefinition $csharpCode -ErrorAction SilentlyContinue
    }

    try {
        $spawned = [SplitSpaceWindowTrigger]::SpawnFloatingWindow($targetApp.ProcessName)
        if ($spawned) {
            Write-Output "SplitSpace: Opened new concurrent floating window for $($targetApp.DisplayName)."
            exit 0
        }
    } catch {}
}

# If app is not running, or native trigger did not find HWND, launch via isolated profile slot
$splitBase = Join-Path $env:LOCALAPPDATA "SplitSpace"
$profilesDir = Join-Path (Join-Path $splitBase "profiles") $targetApp.AppName
if (-not (Test-Path $profilesDir)) {
    New-Item -ItemType Directory -Path $profilesDir -Force | Out-Null
}

$selectedSlot = $Slot
if ($selectedSlot -le 0) {
    # Scan running processes to find the first unused slot
    $runningSlotCmds = @()
    try {
        $procs = Get-CimInstance Win32_Process -Filter "Name = '$($targetApp.ProcessName).exe'" -ErrorAction SilentlyContinue
        foreach ($p in $procs) {
            if ($p.CommandLine -match "slot-(\d+)") {
                $runningSlotCmds += [int]$matches[1]
            }
        }
    } catch {}

    for ($i = 1; $i -le 10; $i++) {
        if ($runningSlotCmds -notcontains $i) {
            $selectedSlot = $i
            break
        }
    }
    if ($selectedSlot -le 0) { $selectedSlot = 1 }
}

$slotDir = Join-Path $profilesDir "slot-$selectedSlot"

if ($Reset -and (Test-Path $slotDir)) {
    Remove-Item -Path $slotDir -Recurse -Force -ErrorAction SilentlyContinue
}

if (-not (Test-Path $slotDir)) {
    New-Item -ItemType Directory -Path $slotDir -Force | Out-Null
}

# Seed slot directory with user appearance and state
$sourceUserData = $targetApp.DefaultUserData
if ($sourceUserData -and (Test-Path $sourceUserData)) {
    $filesToSeed = @("Local State", "Preferences", "app_storage.json", "Cookies")
    foreach ($f in $filesToSeed) {
        $srcFile = Join-Path $sourceUserData $f
        $dstFile = Join-Path $slotDir $f
        if ((Test-Path $srcFile) -and (-not (Test-Path $dstFile))) {
            Copy-Item -Path $srcFile -Destination $dstFile -Force -ErrorAction SilentlyContinue
        }
    }
}

# Connect to active hub if available
if ($targetApp.ActiveHubUrl) {
    $env:DEV_URL = $targetApp.ActiveHubUrl
} else {
    Remove-Item env:DEV_URL -ErrorAction SilentlyContinue
}

$argString = "--user-data-dir=`"$slotDir`" --ignore-certificate-errors"

try {
    $spawned = Start-Process -FilePath $targetApp.ExecutablePath -ArgumentList $argString -PassThru
    Write-Output "SplitSpace: Launched $($targetApp.DisplayName) (Slot $selectedSlot, PID $($spawned.Id))"
} catch {
    Write-Error "SplitSpace failed to launch: $($_.Exception.Message)"
    exit 1
}
