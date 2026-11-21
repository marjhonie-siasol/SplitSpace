# SplitSpace Technical Architecture

This document outlines the system architecture, Windows process management, and session isolation mechanics implemented by SplitSpace.

---

## 1. The Single-Instance Mechanism in Electron & Chromium

Desktop applications like Antigravity, Claude Desktop, and ChatGPT Desktop use Electron's `app.requestSingleInstanceLock()` API:

```javascript
// Typical Electron single-instance enforcement
const gotTheLock = app.requestSingleInstanceLock();
if (!gotTheLock) {
  app.quit();
} else {
  app.on('second-instance', (event, commandLine, workingDirectory) => {
    if (mainWindow) {
      if (mainWindow.isMinimized()) mainWindow.restore();
      mainWindow.focus();
    }
  });
}
```

### How the Lock is Enforced on Windows
1. When the first instance launches, it binds to a Windows named pipe or local socket derived from its `userData` directory hash:
   `\\.\pipe\<user-data-hash>-lock`
2. It creates a filesystem lockfile at:
   `%APPDATA%\<AppName>\SingletonLock`
3. When a second process starts, it queries the named pipe.
4. If the pipe is active, it forwards its command-line arguments to the primary instance and terminates immediately.
5. If the application does not have multi-window handlers implemented in its `second-instance` listener, the primary instance simply focuses the existing window.

---

## 2. Decoupling Instances via Dynamic Multi-Slot Allocation

SplitSpace bypasses the singleton barrier by isolating the `--user-data-dir` argument across dynamic profile slots:

```text
Primary Instance:
  UserData: %APPDATA%\Antigravity
  Lockfile: %APPDATA%\Antigravity\lockfile
  Scope:    Primary Default Session

Secondary Instance 1 (Slot 1):
  UserData: %LOCALAPPDATA%\SplitSpace\profiles\Antigravity\slot-1
  Lockfile: %LOCALAPPDATA%\SplitSpace\profiles\Antigravity\slot-1\lockfile
  Scope:    Independent Floating Window 1

Secondary Instance 2 (Slot 2):
  UserData: %LOCALAPPDATA%\SplitSpace\profiles\Antigravity\slot-2
  Lockfile: %LOCALAPPDATA%\SplitSpace\profiles\Antigravity\slot-2\lockfile
  Scope:    Independent Floating Window 2
```

Because each user data directory path is unique, Chromium generates a distinct named pipe and process boundary. Both processes run concurrently without colliding on singleton lockfiles or IPC channels.

### Dynamic Slot Allocation Algorithm
When the taskbar item is clicked, `splitspace.exe` executes:
1. Queries active process command lines via Win32 process APIs to identify currently occupied slots (`slot-1` through `slot-20`).
2. Identifies the lowest available slot number (reusing slots when earlier windows are closed).
3. Verifies slot hydration; copies configuration and session files if the directory is newly initialized.
4. Spawns the target application with `--user-data-dir="%LOCALAPPDATA%\SplitSpace\profiles\<AppName>\slot-<N>"`.

---

## 3. Credential & State Synchronization

To ensure that opening a new window does not force the user to re-authenticate or log in again, SplitSpace uses a profile hydration strategy:

1. When a secondary profile is created under `%LOCALAPPDATA%\SplitSpace\profiles\<AppName>\slot-N`:
2. The launcher synchronizes essential configuration and local store files from the primary profile:
   - `Local State` (Application preferences and encryption keys)
   - `Preferences` (Interface themes, window configurations)
   - `app_storage.json` (Conversation stores and account identifiers)
3. Volatile locks and process-specific temporary files are excluded:
   - `lockfile` / `SingletonLock`
   - `SingletonCookie`
   - `SingletonSocket`
   - `Crashpad\`
4. The secondary window launches immediately authenticated, ready for independent work.

---

## 4. Windows Jump List Integration

Windows Taskbar Jump Lists are managed by the Windows Shell API. Custom actions appear in the **Tasks** category of the right-click menu:

```text
+------------------------------------+
| Recent Folders                     |
|   cityamor-v2                      |
|   data_collection                  |
|   smart-ledger-demo                |
+------------------------------------+
| Recent                             |
|   Recent Files & Documents         |
+------------------------------------+
| Tasks                              |
|   + Antigravity                    | <-- Injected by SplitSpace
|   Antigravity                      |
|   Unpin from taskbar               |
|   Close window                     |
+------------------------------------+
```

### Registration Flow
1. `lib/jumplist.ps1` extracts existing authentic Jump List streams (`*.customDestinations-ms.bak`).
2. Generates an authentic Windows ShellLink (`.lnk`) targeting `splitspace.exe` with `PKEY_Title` set to `+ <AppName>`.
3. Assembles the binary stream, preserving all Category 2 recent folders and terminal records.
4. Notifies Windows Explorer via `SHChangeNotify(SHCNE_ASSOCCHANGED)` to reload the taskbar menu cache immediately.

---

## 5. Discovery Fallback Matrix

When `lib/discover.ps1` runs, it traverses the system in order of fastest resolution:

| Priority | Target Source | Detection Mechanism |
| :--- | :--- | :--- |
| 1 | Active Process | `Get-Process Antigravity -ErrorAction SilentlyContinue` |
| 2 | Current User AppData | `Test-Path "$env:LOCALAPPDATA\Programs\antigravity\Antigravity.exe"` |
| 3 | Windows User Registry | `HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*` |
| 4 | Windows Machine Registry | `HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*` |
| 5 | Start Menu Shortcuts | `$env:APPDATA\Microsoft\Windows\Start Menu\Programs\*.lnk` |

If all priority checks fail, the installer exits cleanly with an actionable error message rather than creating broken shortcuts.

---

## 6. Symmetrical Lifecycle Specification

```mermaid
sequenceDiagram
    participant User
    participant Installer as install.ps1
    participant System as Windows Shell
    participant Launcher as splitspace.cmd
    participant Uninstaller as uninstall.ps1

    Note over User, Installer: Installation Flow
    User->>Installer: Runs irm .../install.ps1 | iex
    Installer->>System: Discovers app path & shortcut
    Installer->>System: Injects '+ SplitSpace' Jump List task
    Installer-->>User: [SUCCESS] Multi-window enabled

    Note over User, Launcher: Everyday Multitasking
    User->>System: Right-click taskbar -> Click '+ SplitSpace'
    System->>Launcher: Executes splitspace.cmd
    Launcher->>System: Spawns independent Antigravity window

    Note over User, Uninstaller: Removal Flow
    User->>Uninstaller: Runs irm .../uninstall.ps1 | iex
    Uninstaller->>System: Removes Jump List task & restores shortcut
    Uninstaller->>System: Cleans up SplitSpace profile folders
    Uninstaller-->>User: [SUCCESS] System restored to default
```
