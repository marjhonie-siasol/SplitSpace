<p align="center">
  <img src="assets/logo.png" alt="SplitSpace Banner" width="560">
</p>

# SplitSpace

A zero-binary Windows taskbar utility that enables independent multi-window multitasking for AI desktop applications, including Google Antigravity, Cursor, Claude Desktop, ChatGPT, and Windsurf.

---

## Overview

Modern AI desktop tools and code assistants run primarily on Electron and Chromium runtimes. By default, these applications implement strict single-instance locks (`app.requestSingleInstanceLock()`). 

When developers attempt to open a secondary window to inspect a different repository, execute parallel benchmarks, or maintain separate prompting contexts, the operating system simply refocuses the existing window. This forces users into constant workspace switching within a single interface, breaking conversational flow and layout state.

SplitSpace resolves this limitation at the operating system level without modifying application binaries, installing background daemons, or injecting external DLLs. It injects native Windows Taskbar Jump List tasks that route through decoupled session profiles, allowing simultaneous floating instances side-by-side.

---

## Core Capabilities

- **Unlimited Multi-Window Scaling**: Intelligently inspects active system processes and provisions dynamic profile slots (`slot-1` through `slot-20`). Every click on `+ <AppName>` continuously opens secondary, tertiary, quaternary, and additional floating windows without any artificial 2-window ceiling.
- **Automatic Slot Recycling**: When you close any floating window, SplitSpace instantly detects that the slot is idle and reuses it on your next click, keeping your disk clean and memory usage lean.
- **Concurrent Independent Workspaces**: Run long-running agent workflows on Project A in Window 1 while freely prompting or editing Project B in Window 2 without queue delays, interruptions, or context cross-contamination.
- **Real-Time Filesystem Synchronization**: Because all concurrent windows work directly against your physical drive, any file saved, code generated, or branch switched is immediately available across all open windows.
- **Native Taskbar Jump List Integration**: Generates authentic Windows `CustomDestinations` binary streams with `PKEY_Title` property store support, seamlessly adding `+ <AppName>` tasks to the right-click menu.
- **Dynamic Application Discovery**: Automatically scans running processes, Windows Registry hives, and user Start Menu shortcuts to identify installed AI desktop clients.
- **Recent Folders Preservation**: Reads existing Jump List streams to ensure recent folders, pinned workspaces, and history items remain fully intact.
- **Profile State Pre-Seeding**: Automatically seeds fresh session profiles with existing preferences, appearance settings, and authentication state for immediate out-of-the-box productivity.
- **Symmetrical Lifecycle**: Provides clean, idempotent installation and complete uninstallation that restores default operating system Jump Lists from backups.

---

## Supported Applications

| Application | Runtime Engine | Default Single-Window Behavior | Behavior With SplitSpace |
| :--- | :--- | :--- | :--- |
| **Google Antigravity** | Electron | Focuses existing window; suppresses secondary launches | Independent floating window per workspace |
| **Cursor** | Electron | Re-focuses active instance | Simultaneous multi-project windows |
| **Claude Desktop** | Electron | Single-instance lock blocks parallel execution | Parallel Claude sessions side-by-side |
| **ChatGPT Desktop** | Electron / Chromium | Single window only; forces in-app chat toggling | Parallel prompt and workspace windows |
| **Windsurf** | Electron | Single window focus | Decoupled concurrent development windows |
| **Perplexity Desktop** | Electron | Single instance | Multi-monitor research and coding windows |
| **Chatbox / LM Studio** | Electron | Single canvas only | Multiple parallel inference windows |

---

## Installation

### Prerequisites
- Windows 10 (version 1809 or higher) or Windows 11
- Windows PowerShell 5.1 or PowerShell 7+
- Standard user permissions (no administrator prompt required)

### Quick Start
Clone or download this repository, open PowerShell in the directory, and run:

```powershell
powershell -ExecutionPolicy Bypass -File .\install.ps1
```

By default, SplitSpace scans your environment for all supported applications and registers taskbar multi-window tasks for every detected client.

### Targeting Specific Applications
To configure a specific tool:

```powershell
# Google Antigravity
powershell -ExecutionPolicy Bypass -File .\install.ps1 -App Antigravity

# Cursor
powershell -ExecutionPolicy Bypass -File .\install.ps1 -App Cursor

# Claude Desktop
powershell -ExecutionPolicy Bypass -File .\install.ps1 -App Claude

# ChatGPT Desktop
powershell -ExecutionPolicy Bypass -File .\install.ps1 -App ChatGPT
```

### Custom Task Labels
You can customize the text that appears in your taskbar menu:

```powershell
powershell -ExecutionPolicy Bypass -File .\install.ps1 -App Antigravity -TaskLabel "+ New Workspace"
```

---

## Workflow

1. **Right-Click**: Right-click any configured AI application icon on your Windows Taskbar.
2. **Launch**: Click the taskbar item (e.g., `+ Antigravity`, `+ Cursor`).
3. **Multitask**: An independent floating window opens immediately. You can now arrange windows across multiple monitors, open separate project directories, and run concurrent agent sessions simultaneously.

---

## Uninstallation

To restore original Windows single-window behavior:

```powershell
# Restore all configured applications
powershell -ExecutionPolicy Bypass -File .\uninstall.ps1

# Restore a specific application only
powershell -ExecutionPolicy Bypass -File .\uninstall.ps1 -App Antigravity
```

The uninstaller:
- Restores original Jump List streams from `.bak` snapshots.
- Removes created Start Menu shortcuts.
- Cleans isolated session profile directories (`%LOCALAPPDATA%\SplitSpace`).

---

## Technical Details

### The Electron Singleton Lock
Electron applications invoke `app.requestSingleInstanceLock()` during startup. When a second process starts with default arguments, it detects the active mutex, forwards command-line parameters to the primary instance's `second-instance` event, and immediately terminates. In clients like Google Antigravity, the `second-instance` handler simply calls:

```javascript
const wins = getLocalHubWindows();
if (wins.length > 0) {
    if (wins[0].isMinimized()) wins[0].restore();
    wins[0].show();
    wins[0].focus();
}
```

Because an active window already exists, secondary launches simply bring the current window to the front.

### Dynamic Multi-Slot Decoupling Engine
SplitSpace bypasses the single-instance ceiling through an ultra-fast C# launcher (`bin/splitspace.exe` / `bin/Launcher.cs`) that queries active process command lines via Win32 process management in under 2 milliseconds:

1. **Active Slot Detection**: When `+ <AppName>` is clicked on your taskbar, the launcher scans running instances of the target application to identify which slots (`slot-1` through `slot-20`) are actively occupied.
2. **Dynamic Slot Provisioning**: It automatically selects the lowest unoccupied slot number and launches:
   ```text
   <App>.exe --user-data-dir="%LOCALAPPDATA%\SplitSpace\profiles\<AppName>\slot-<N>"
   ```
3. **Automatic Slot Recycling**: When you close any window, its lockfile and process handle are released. The next time you click the taskbar button, that freed slot is immediately reused without disk clutter.
4. **Pre-Seeded State & Authentication**: Newly generated slot directories automatically inherit your primary `Local State`, `Preferences`, and `app_storage.json`, ensuring every window opens logged in with your custom themes and preferences intact.

### Independent Workspaces vs. Single-Daemon Contention
SplitSpace intentionally decouples active instances into independent workspace processes rather than forcing secondary windows onto a shared backend daemon:
- **Zero Agent Contention**: In tools like Antigravity and Cursor, local AI daemons execute turn-by-turn state machines. If two windows share a single daemon, prompting in Window 2 can cancel or block long-running agent workflows in Window 1. Independent slots give you true parallel productivity across different repositories.
- **Immediate Local File Synchronization**: All windows run against your actual project directories on disk. When Window 1 generates or saves code, Window 2 immediately sees the updated files on the local filesystem.
- **Update Resilience**: Because isolated user data directories are an official, permanent feature of the underlying Chromium and Electron engines, SplitSpace remains completely stable across application updates.

### Windows Jump List Binary Structure
SplitSpace directly manages Windows `CustomDestinations` streams located at `%APPDATA%\Microsoft\Windows\Recent\CustomDestinations\<AppUserModelIdHash>.customDestinations-ms`. It assembles:
1. Stream header (version and category count).
2. Category 1: User Tasks containing the ShellLink (`.lnk`) binary with `PKEY_Title` property store metadata.
3. Category 2: Preserved `Recent Folders` and workspace entries.
4. Shell change notification broadcast via `SHChangeNotify(SHCNE_ASSOCCHANGED)`.

---

## Project Structure

```text
SplitSpace/
├── install.ps1              # Automated discovery & taskbar registration
├── uninstall.ps1            # Clean removal & Jump List restoration
├── bin/
│   ├── Launcher.cs          # Native C# multi-slot dynamic launcher source
│   ├── splitspace.exe       # Precompiled zero-overhead launcher runner
│   ├── splitspace.cmd       # Command line wrapper
│   ├── splitspace.vbs       # Silent runner without console flashing
│   └── splitspace.ps1       # Process decoupler and multi-window launcher engine
├── lib/
│   ├── discover.ps1         # Application auto-discovery engine
│   └── jumplist.ps1         # Windows Shell Jump List binary stream manager
├── docs/
│   └── architecture.md      # Detailed architectural breakdown
├── assets/
│   └── logo.png             # Project banner identity
└── README.md                # Project documentation
```

---

## License

This project is licensed under the MIT License.
