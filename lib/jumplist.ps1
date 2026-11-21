<#
.SYNOPSIS
    SplitSpace Windows Taskbar Jump List Manager
.DESCRIPTION
    Injects and manages native Windows Taskbar right-click Jump List tasks (+ SplitSpace / + <AppName>)
    using dynamic path resolution, binary stream assembly, Windows Shell PropertyStore,
    and Explorer notifications for any supported AI desktop application.
#>

$propertyStoreSource = @'
using System;
using System.Runtime.InteropServices;

namespace SplitSpaceShell {
    [StructLayout(LayoutKind.Sequential, Pack = 4)]
    public struct PROPERTYKEY {
        public Guid fmtid;
        public uint pid;
        public PROPERTYKEY(Guid g, uint p) { fmtid = g; pid = p; }
    }

    [StructLayout(LayoutKind.Explicit)]
    public struct PROPVARIANT {
        [FieldOffset(0)] public ushort vt;
        [FieldOffset(8)] public IntPtr pwszVal;
    }

    [ComImport]
    [Guid("886d8eeb-8cf2-4446-8d02-cdba1dbdcf99")]
    [InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    public interface IPropertyStore {
        [PreserveSig] int GetCount(out uint cProps);
        [PreserveSig] int GetAt(uint iProp, out PROPERTYKEY pkey);
        [PreserveSig] int GetValue(ref PROPERTYKEY key, out PROPVARIANT pv);
        [PreserveSig] int SetValue(ref PROPERTYKEY key, ref PROPVARIANT propvar);
        [PreserveSig] int Commit();
    }

    public class JumpListHelper {
        [DllImport("propsys.dll", SetLastError = true, CharSet = CharSet.Unicode)]
        public static extern int PSGetPropertyKeyFromName(string pszName, out PROPERTYKEY pkey);

        [DllImport("shell32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
        public static extern int SHGetPropertyStoreFromParsingName(
            string pszPath,
            IntPtr zero,
            int flags, // GPS_READWRITE = 2
            ref Guid riid,
            [MarshalAs(UnmanagedType.Interface)] out IPropertyStore ppv);

        [DllImport("shell32.dll")]
        public static extern void SHChangeNotify(int wEventId, int uFlags, IntPtr dwItem1, IntPtr dwItem2);

        public static int SetShortcutProperties(string lnkPath, string title, string aumid) {
            Guid iid = new Guid("886d8eeb-8cf2-4446-8d02-cdba1dbdcf99");
            IPropertyStore store = null;
            int hr = SHGetPropertyStoreFromParsingName(lnkPath, IntPtr.Zero, 2, ref iid, out store);
            if (hr != 0) return hr;

            try {
                if (!string.IsNullOrEmpty(title)) {
                    PROPERTYKEY pkeyTitle;
                    if (PSGetPropertyKeyFromName("System.Title", out pkeyTitle) != 0) {
                        // Official System.Title PKEY GUID: {F29F85E0-4FF9-1068-AB91-08002B27B3D9}, PID: 2
                        pkeyTitle = new PROPERTYKEY(new Guid("f29f85e0-4ff9-1068-ab91-08002b27b3d9"), 2);
                    }
                    PROPVARIANT pvTitle = new PROPVARIANT();
                    pvTitle.vt = 31; // VT_LPWSTR
                    pvTitle.pwszVal = Marshal.StringToCoTaskMemUni(title);
                    store.SetValue(ref pkeyTitle, ref pvTitle);
                    Marshal.FreeCoTaskMem(pvTitle.pwszVal);
                }

                if (!string.IsNullOrEmpty(aumid)) {
                    PROPERTYKEY pkeyAumid;
                    if (PSGetPropertyKeyFromName("System.AppUserModel.ID", out pkeyAumid) != 0) {
                        // Official System.AppUserModel.ID PKEY GUID: {9F4C2855-9F79-4B39-A8D0-E1D42DE1D5F3}, PID: 5
                        pkeyAumid = new PROPERTYKEY(new Guid("9f4c2855-9f79-4b39-a8d0-e1d42de1d5f3"), 5);
                    }
                    PROPVARIANT pvAumid = new PROPVARIANT();
                    pvAumid.vt = 31; // VT_LPWSTR
                    pvAumid.pwszVal = Marshal.StringToCoTaskMemUni(aumid);
                    store.SetValue(ref pkeyAumid, ref pvAumid);
                    Marshal.FreeCoTaskMem(pvAumid.pwszVal);
                }

                hr = store.Commit();
            } finally {
                if (store != null) {
                    Marshal.ReleaseComObject(store);
                }
            }
            return hr;
        }

        public static void NotifyShell() {
            // SHCNE_ASSOCCHANGED = 0x08000000, SHCNF_IDLIST = 0x0000
            SHChangeNotify(0x08000000, 0x0000, IntPtr.Zero, IntPtr.Zero);
        }
    }
}
'@

if (-not ([System.Management.Automation.PSTypeName]'SplitSpaceShell.JumpListHelper').Type) {
    Add-Type -TypeDefinition $propertyStoreSource -ErrorAction SilentlyContinue
}

function Set-SplitSpaceJumpList {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$TargetApp,

        [Parameter()]
        [string]$TaskLabel = "+ SplitSpace"
    )

    $libPath = $PSScriptRoot
    if (-not $libPath) {
        $libPath = Split-Path -Parent $MyInvocation.MyCommand.Path
    }
    if (-not $libPath) {
        $libPath = (Get-Location).Path
    }
    $projectRoot = Split-Path -Parent $libPath

    $splitSpaceBase = Join-Path $env:LOCALAPPDATA "SplitSpace"
    if (-not (Test-Path $splitSpaceBase)) {
        New-Item -ItemType Directory -Path $splitSpaceBase -Force | Out-Null
    }

    # Step 1: Gather all candidate CustomDestinations hashes for this application
    $targetHashes = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    if ($TargetApp.AumidHashes) {
        foreach ($h in $TargetApp.AumidHashes) {
            if ($h -and $h.Length -eq 16) { [void]$targetHashes.Add($h) }
        }
    }
    if ($TargetApp.AumidHash -and $TargetApp.AumidHash.Length -eq 16) {
        [void]$targetHashes.Add($TargetApp.AumidHash)
    }

    if ($targetHashes.Count -eq 0) {
        Write-Warning "No Jump List destination hash resolved for $($TargetApp.DisplayName)."
        return $false
    }

    $customDestDir = Join-Path $env:APPDATA "Microsoft\Windows\Recent\CustomDestinations"
    if (-not (Test-Path $customDestDir)) {
        New-Item -ItemType Directory -Path $customDestDir -Force | Out-Null
    }

    # Step 2: Ensure SplitSpace dynamic multi-slot launcher is prepared
    $binDir = Join-Path $splitSpaceBase "bin"
    if (-not (Test-Path $binDir)) {
        New-Item -ItemType Directory -Path $binDir -Force | Out-Null
    }
    $launcherExe = Join-Path $binDir "splitspace.exe"
    $repoLauncher = Join-Path $projectRoot "bin\splitspace.exe"
    $repoLauncherSource = Join-Path $projectRoot "bin\Launcher.cs"

    if (Test-Path $repoLauncher) {
        Copy-Item -Path $repoLauncher -Destination $launcherExe -Force -ErrorAction SilentlyContinue
    } elseif (Test-Path $repoLauncherSource) {
        $csc = "C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe"
        if (Test-Path $csc) {
            & $csc /target:winexe /r:System.Management.dll /out:$launcherExe $repoLauncherSource | Out-Null
        }
    }

    # Step 3: Check if any authentic backup or template exists for this application
    $templateBytes = $null
    foreach ($h in $targetHashes) {
        $bakCandidate = Join-Path $customDestDir "$h.customDestinations-ms.bak"
        if (Test-Path $bakCandidate) {
            try {
                $candidateBytes = [System.IO.File]::ReadAllBytes($bakCandidate)
                $txt = [System.Text.Encoding]::Unicode.GetString($candidateBytes)
                if ($candidateBytes.Length -gt 1000 -and ($txt -notmatch "splitspace")) {
                    $templateBytes = $candidateBytes
                    break
                }
            } catch {}
        }
        $destCandidate = Join-Path $customDestDir "$h.customDestinations-ms"
        if (-not $templateBytes -and (Test-Path $destCandidate)) {
            try {
                $candidateBytes = [System.IO.File]::ReadAllBytes($destCandidate)
                $txt = [System.Text.Encoding]::Unicode.GetString($candidateBytes)
                if ($candidateBytes.Length -gt 1000 -and ($txt -notmatch "splitspace")) {
                    $templateBytes = $candidateBytes
                    break
                }
            } catch {}
        }
    }

    # Step 4: Build authentic Windows ShellLink for the multi-window task
    $tempLnkPath = Join-Path $splitSpaceBase "task_$($TargetApp.AppName).lnk"
    if (Test-Path $tempLnkPath) {
        Remove-Item -Path $tempLnkPath -Force -ErrorAction SilentlyContinue
    }

    $targetExePath = if (Test-Path $launcherExe) { $launcherExe } else { $TargetApp.ExecutablePath }
    $targetArgs = if (Test-Path $launcherExe) { "$($TargetApp.AppName) `"$($TargetApp.ExecutablePath)`"" } else { "--user-data-dir=`"$splitSpaceBase\profiles\$($TargetApp.AppName)\slot-1`"" }

    $iconPathToUse = if ($TargetApp.IconPath) { $TargetApp.IconPath } else { "$($TargetApp.ExecutablePath),0" }

    $wsh = New-Object -ComObject WScript.Shell
    $sc = $wsh.CreateShortcut($tempLnkPath)
    $sc.TargetPath = $targetExePath
    $sc.Arguments = $targetArgs
    $workingDir = Split-Path -Parent $TargetApp.ExecutablePath
    if (Test-Path $workingDir) {
        $sc.WorkingDirectory = $workingDir
    }
    $sc.Description = "Launch an independent $($TargetApp.DisplayName) workspace window"
    $sc.IconLocation = $iconPathToUse
    $sc.Save()

    [System.Runtime.InteropServices.Marshal]::ReleaseComObject($sc) | Out-Null
    [System.Runtime.InteropServices.Marshal]::ReleaseComObject($wsh) | Out-Null
    [System.GC]::Collect()

    try {
        [SplitSpaceShell.JumpListHelper]::SetShortcutProperties($tempLnkPath, $TaskLabel, $TargetApp.AppUserModelId) | Out-Null
    } catch {}

    [System.GC]::Collect()

    $taskLnkBytes = $null
    for ($attempt = 0; $attempt -lt 5; $attempt++) {
        try {
            $taskLnkBytes = [System.IO.File]::ReadAllBytes($tempLnkPath)
            break
        } catch {
            Start-Sleep -Milliseconds 100
        }
    }

    if (-not $taskLnkBytes -or $taskLnkBytes.Length -eq 0) {
        Write-Error "Failed to generate task shortcut."
        return $false
    }

    $delim = [byte[]]@(0xAB, 0xFB, 0xBF, 0xBA)
    $shellLinkGuid = [byte[]]@(0x01, 0x14, 0x02, 0x00, 0x00, 0x00, 0x00, 0x00, 0xC0, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x46)
    $finalBytes = $null

    # Strategy A: Multi-task injection into authentic template (preserving existing tasks like Claude New Chat/Session and Antigravity Recent)
    if ($templateBytes -and $templateBytes.Length -gt 24) {
        $d1 = -1
        for ($i = 20; $i -le $templateBytes.Length - 4; $i++) {
            if ($templateBytes[$i] -eq 0xAB -and $templateBytes[$i+1] -eq 0xFB -and $templateBytes[$i+2] -eq 0xBF -and $templateBytes[$i+3] -eq 0xBA) {
                $d1 = $i
                break
            }
        }

        if ($d1 -ge 20) {
            $catType = [BitConverter]::ToInt32($templateBytes, 12)
            $existingItemCount = [BitConverter]::ToInt32($templateBytes, 16)

            $ms = New-Object System.IO.MemoryStream
            $bw = New-Object System.IO.BinaryWriter($ms)

            # Write File Header (0..11)
            $bw.Write($templateBytes, 0, 12)

            # Write Category 1 Header: CatType + (existingItemCount + 1)
            $bw.Write([int32]$catType)
            $bw.Write([int32]($existingItemCount + 1))

            # Write New Task as Item 1 at the top of the tasks list: GUID + LNK bytes
            $bw.Write($shellLinkGuid, 0, 16)
            $bw.Write($taskLnkBytes, 0, $taskLnkBytes.Length)

            # Preserve all existing tasks from offset 20 up to delimiter $d1
            if ($d1 -gt 20) {
                $bw.Write($templateBytes, 20, ($d1 - 20))
            }

            # Write delimiter
            $bw.Write($delim, 0, 4)

            # Preserve remainder of template (Category 2 Recent Folders, terminal record)
            $remStart = $d1 + 4
            if ($remStart -lt $templateBytes.Length) {
                $bw.Write($templateBytes, $remStart, ($templateBytes.Length - $remStart))
            }

            $finalBytes = $ms.ToArray()
            $bw.Close()
            $ms.Close()
        }
    }

    # Strategy B: Clean single-category stream assembly (if no template available)
    if (-not $finalBytes) {
        $ms = New-Object System.IO.MemoryStream
        $bw = New-Object System.IO.BinaryWriter($ms)

        # Header: Version=2, CategoryCount=1, Reserved=0
        $bw.Write([int32]2)
        $bw.Write([int32]1)
        $bw.Write([int32]0)

        # Category 1: Tasks (Category Type = 2, Item Count = 1)
        $bw.Write([int32]2)
        $bw.Write([int32]1)
        $bw.Write($shellLinkGuid, 0, 16)
        $bw.Write($taskLnkBytes, 0, $taskLnkBytes.Length)
        $bw.Write($delim, 0, 4)

        # Terminal record: 12 bytes
        $bw.Write([byte[]]@(0xFF, 0xFF, 0xFF, 0xFF, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00))

        $finalBytes = $ms.ToArray()
        $bw.Close()
        $ms.Close()
    }

    if (-not $finalBytes) {
        Write-Error "Failed to generate Jump List binary stream."
        return $false
    }

    # Step 5: Write destination files for all target hashes
    foreach ($h in $targetHashes) {
        $destFile = Join-Path $customDestDir "$h.customDestinations-ms"
        $backupFile = "$destFile.bak"

        # Backup existing file only if valid, authentic, and not containing SplitSpace
        if ((Test-Path $destFile) -and (-not (Test-Path $backupFile))) {
            try {
                $existing = [System.IO.File]::ReadAllBytes($destFile)
                $existingTxt = [System.Text.Encoding]::Unicode.GetString($existing)
                if ($existing.Length -gt 1000 -and ($existingTxt -notmatch "splitspace")) {
                    Copy-Item -Path $destFile -Destination $backupFile -Force
                }
            } catch {}
        }

        [System.IO.File]::WriteAllBytes($destFile, $finalBytes)
    }

    # Step 6: Create Start Menu shortcut
    $startMenuDir = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs"
    if (Test-Path $startMenuDir) {
        $wsh2 = New-Object -ComObject WScript.Shell
        $startMenuLnk = Join-Path $startMenuDir "SplitSpace ($($TargetApp.DisplayName)).lnk"
        $scSm = $wsh2.CreateShortcut($startMenuLnk)
        $scSm.TargetPath = $targetExePath
        $scSm.Arguments = $targetArgs
        if (Test-Path $workingDir) {
            $scSm.WorkingDirectory = $workingDir
        }
        $scSm.Description = "Launch an independent floating $($TargetApp.DisplayName) window"
        $scSm.IconLocation = $iconPathToUse
        $scSm.Save()
        [System.Runtime.InteropServices.Marshal]::ReleaseComObject($scSm) | Out-Null
        [System.Runtime.InteropServices.Marshal]::ReleaseComObject($wsh2) | Out-Null

        try {
            [SplitSpaceShell.JumpListHelper]::SetShortcutProperties($startMenuLnk, "SplitSpace ($($TargetApp.DisplayName))", $TargetApp.AppUserModelId) | Out-Null
        } catch {}
    }

    # Step 7: Touch pinned taskbar shortcut to trigger Jump List cache refresh
    $taskbarPath = "$env:APPDATA\Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar"
    if (Test-Path $taskbarPath) {
        Get-ChildItem -Path $taskbarPath -Filter "*$($TargetApp.ProcessName)*.lnk" -ErrorAction SilentlyContinue | ForEach-Object {
            $_.LastWriteTime = Get-Date
        }
    }

    # Step 8: Notify Windows Shell to refresh taskbar
    try {
        [SplitSpaceShell.JumpListHelper]::NotifyShell()
    } catch {}

    return $true
}

function Remove-SplitSpaceJumpList {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$TargetApp
    )

    $targetHashes = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    if ($TargetApp.AumidHashes) {
        foreach ($h in $TargetApp.AumidHashes) {
            if ($h -and $h.Length -eq 16) { [void]$targetHashes.Add($h) }
        }
    }
    if ($TargetApp.AumidHash -and $TargetApp.AumidHash.Length -eq 16) {
        [void]$targetHashes.Add($TargetApp.AumidHash)
    }

    $customDestDir = Join-Path $env:APPDATA "Microsoft\Windows\Recent\CustomDestinations"
    foreach ($h in $targetHashes) {
        $destFile = Join-Path $customDestDir "$h.customDestinations-ms"
        $backupFile = "$destFile.bak"

        if (Test-Path $backupFile) {
            $isContaminatedBackup = $false
            try {
                $bakBytes = [System.IO.File]::ReadAllBytes($backupFile)
                $bakTxt = [System.Text.Encoding]::Unicode.GetString($bakBytes)
                if ($bakTxt -match "splitspace") {
                    $isContaminatedBackup = $true
                }
            } catch {}

            if ($isContaminatedBackup) {
                Remove-Item -Path $destFile -Force -ErrorAction SilentlyContinue
                Remove-Item -Path $backupFile -Force -ErrorAction SilentlyContinue
            } else {
                Copy-Item -Path $backupFile -Destination $destFile -Force
                Remove-Item -Path $backupFile -Force -ErrorAction SilentlyContinue
            }
        } else {
            if (Test-Path $destFile) {
                Remove-Item -Path $destFile -Force -ErrorAction SilentlyContinue
            }
        }
    }

    # Remove Start Menu shortcut
    $startMenuDir = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs"
    if (Test-Path $startMenuDir) {
        $startMenuLnk = Join-Path $startMenuDir "SplitSpace ($($TargetApp.DisplayName)).lnk"
        if (Test-Path $startMenuLnk) {
            Remove-Item -Path $startMenuLnk -Force -ErrorAction SilentlyContinue
        }
    }

    # Remove temp link in LocalAppData
    $tempLnkPath = "$env:LOCALAPPDATA\SplitSpace\task_$($TargetApp.AppName).lnk"
    if (Test-Path $tempLnkPath) {
        Remove-Item -Path $tempLnkPath -Force -ErrorAction SilentlyContinue
    }

    # Touch pinned taskbar shortcut to trigger refresh
    $taskbarPath = "$env:APPDATA\Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar"
    if (Test-Path $taskbarPath) {
        Get-ChildItem -Path $taskbarPath -Filter "*$($TargetApp.ProcessName)*.lnk" -ErrorAction SilentlyContinue | ForEach-Object {
            $_.LastWriteTime = Get-Date
        }
    }

    # Notify Windows Shell
    try {
        [SplitSpaceShell.JumpListHelper]::NotifyShell()
    } catch {}

    return $true
}
