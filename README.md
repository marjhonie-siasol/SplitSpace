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

- **Dynamic Multi-Slot Scaling**: Intelligently identifies active instances and allocates dynamic profile slots (`slot-1` through `slot-20`). Clicking `+ <AppName>` continuously opens secondary, tertiary, and additional concurrent floating windows.
- **Native Taskbar Jump List Integration**: Generates authentic Windows `CustomDestinations` binary streams with `PKEY_Title` property store support, seamlessly adding `+ <AppName>` tasks to the right-click menu.
- **Dynamic Application Discovery**: Automatically scans running processes, Windows Registry hives, and user Start Menu shortcuts to identify installed AI desktop clients.
- **Recent Folders Preservation**: Reads existing Jump List streams to ensure recent folders, pinned workspaces, and history items remain fully intact.
- **Profile State Seeding**: Automatically seeds isolated session profiles with existing preferences, appearance settings, and authentication state for immediate productivity.
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

### Process Decoupling Mechanism
SplitSpace bypasses this restriction by assigning secondary instances an isolated profile slot:

```text
--user-data-dir="%LOCALAPPDATA%\SplitSpace\profiles\<AppName>\slot-1"
```

By executing with a distinct profile path, Chromium and Electron isolate the single-instance lock to that slot. The operating system treats the secondary process as a distinct instance with its own window handle, event loop, and render pipeline.

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
