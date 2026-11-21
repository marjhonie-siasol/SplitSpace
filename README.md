<p align="center">
  <img src="assets/logo.png" alt="SplitSpace Banner" width="560">
</p>

# SplitSpace

A zero-binary Windows taskbar utility that enables independent multi-window multitasking for AI desktop applications, including Google Antigravity, Anthropic Claude Desktop, OpenAI ChatGPT Desktop, and Windsurf.

---

## Overview

Modern AI desktop tools and code assistants run primarily on Electron and Chromium runtimes. By default, these applications implement strict single-instance locks (`app.requestSingleInstanceLock()`). 

When developers attempt to open a secondary window to inspect a different repository, execute parallel benchmarks, or maintain separate prompting contexts, the operating system simply refocuses the existing window. This forces users into constant workspace switching within a single interface, breaking conversational flow and layout state.

SplitSpace resolves this limitation at the operating system level without modifying application binaries, installing background daemons, or injecting external DLLs. It injects native Windows Taskbar Jump List tasks that route through decoupled session profiles, allowing simultaneous floating instances side-by-side grouped neatly under their pinned taskbar icons.

---

## Core Capabilities

- **Unlimited Multi-Window Scaling**: Intelligently inspects active system processes and provisions dynamic profile slots (`slot-1` through `slot-20`). Every click on `+ <AppName>` continuously opens secondary, tertiary, quaternary, and additional floating windows without any artificial 2-window ceiling.
- **Automatic Slot Recycling**: When you close any floating window, SplitSpace instantly detects that the slot is idle and reuses it on your next click, keeping your disk clean and memory usage lean.
- **Unified Taskbar Grouping**: Leverages Windows Shell AppUserModelID properties (`PKEY_AppUserModel_ID`) and package execution aliases so secondary windows stack cleanly under the authentic pinned taskbar icon with dual preview thumbnails, rather than spawning ungrouped buttons on the far right.
- **Authentic High-Resolution Logos**: Preserves and binds the official vector/application store icons (e.g. OpenAI dark vector emblem and Anthropic Claude branding) rather than fallback binary icons.
- **Native Task Preservation**: Injects the `+ <AppName>` task while strictly preserving existing native application tasks (such as Claude's `New Chat` and `New Code Session`) and Recent Folders.
- **Concurrent Independent Workspaces**: Run long-running agent workflows on Project A in Window 1 while freely prompting or editing Project B in Window 2 without queue delays, interruptions, or context cross-contamination.
- **Real-Time Filesystem Synchronization**: Because all concurrent windows work directly against your physical drive, any file saved, code generated, or branch switched is immediately available across all open windows.
- **Profile State Pre-Seeding**: Automatically seeds fresh session profiles with existing preferences, appearance settings, and authentication state for immediate out-of-the-box productivity.
- **Symmetrical Lifecycle**: Provides clean, idempotent installation and complete uninstallation that restores default operating system Jump Lists from backups.

---

## Supported Applications

| Application | Runtime Engine | Default Single-Window Behavior | Behavior With SplitSpace |
| :--- | :--- | :--- | :--- |
| **Google Antigravity** | Electron | Focuses existing window; suppresses secondary launches | Independent floating window per workspace; stacked dual thumbnails |
| **Anthropic Claude Desktop** | Electron (MSIX) | Single-instance lock blocks parallel execution | Independent parallel Claude sessions side-by-side; preserves New Chat / Code Session |
| **OpenAI ChatGPT Desktop** | Chromium / Owl (MSIX) | Single window only; forces in-app chat toggling | Parallel prompt and workspace windows grouped under authentic OpenAI icon |
| **Windsurf** | Electron | Single window focus | Decoupled concurrent development windows |
| **Perplexity Desktop** | Electron | Single instance | Multi-monitor research and coding windows |
| **Chatbox / LM Studio** | Electron | Single canvas only | Multiple parallel inference windows |

> [!NOTE]
> **Why Cursor is Excluded from SplitSpace**:  
> Cursor is a customized fork of VS Code that already includes native multi-window workspace capabilities (`Ctrl+Shift+N` or File > New Window). Launching Cursor with isolated profile directories isolates its DPAPI/SQLite credentials database (`state.vscdb`), causing session logouts. Furthermore, Cursor's internal C++ workbench actively rewrites its own Jump List on workspace change. For Cursor, simply use its built-in `Ctrl+Shift+N` shortcut.

---

## Quick Start

Open Windows PowerShell (no administrator prompt required) and use the commands below.

### 1. Install
```powershell
powershell -ExecutionPolicy Bypass -File .\install.ps1
```
Automatically scans your system, detects all installed AI desktop applications (Google Antigravity, Claude, ChatGPT, etc.), and injects the `+ <AppName>` taskbar button.

### 2. How to Use
1. Right-click the app icon on your Windows Taskbar (e.g. Google Antigravity, Claude, or ChatGPT).
2. Click **`+ Antigravity`**, **`+ Claude`**, or **`+ ChatGPT`**.
3. An independent floating window opens immediately, grouped under the pinned taskbar icon with side-by-side hover previews. Click it again anytime to open Window 3, Window 4, and beyond.

### 3. Uninstall
```powershell
powershell -ExecutionPolicy Bypass -File .\uninstall.ps1
```
Removes the `+ <AppName>` taskbar buttons, restores authentic native tasks, and returns Windows to its default single-window behavior.

---

## Command Reference

| Action | PowerShell Command |
| :--- | :--- |
| **Install for All Apps** | `powershell -ExecutionPolicy Bypass -File .\install.ps1` |
| **Install Antigravity Only** | `powershell -ExecutionPolicy Bypass -File .\install.ps1 -App Antigravity` |
| **Install Claude Only** | `powershell -ExecutionPolicy Bypass -File .\install.ps1 -App Claude` |
| **Install ChatGPT Only** | `powershell -ExecutionPolicy Bypass -File .\install.ps1 -App ChatGPT` |
| **Custom Taskbar Title** | `powershell -ExecutionPolicy Bypass -File .\install.ps1 -App Antigravity -TaskLabel "+ New Workspace"` |
| **Uninstall All Apps** | `powershell -ExecutionPolicy Bypass -File .\uninstall.ps1` |
| **Uninstall Single App** | `powershell -ExecutionPolicy Bypass -File .\uninstall.ps1 -App Claude` |

> [!NOTE]
> If your PowerShell terminal is in a different folder (like `system32`), run with the full path:  
> `powershell -ExecutionPolicy Bypass -File "$env:USERPROFILE\OneDrive\Desktop\SplitSpace\install.ps1"`  
> `powershell -ExecutionPolicy Bypass -File "$env:USERPROFILE\OneDrive\Desktop\SplitSpace\uninstall.ps1"`

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

1. **Active Slot Detection**: When `+ <AppName>` is clicked on your taskbar, the launcher scans running instances of the target application (`ChatGPT.exe`, `Claude.exe`, `Antigravity.exe`) to identify which slots (`slot-1` through `slot-20`) are actively occupied.
2. **Dynamic Slot Provisioning**: It automatically selects the lowest unoccupied slot number and launches:
   ```text
   <App>.exe --user-data-dir="%LOCALAPPDATA%\SplitSpace\profiles\<AppName>\slot-<N>"
   ```
3. **AppUserModelID Stacking**: For MSIX Store applications (like Claude Desktop and OpenAI ChatGPT), the launcher routes launches through package execution aliases and binds the window's `System.AppUserModel.ID` property using `SHGetPropertyStoreForWindow`. This instructs the Windows Taskband to stack all secondary windows into the primary pinned taskbar icon with dual thumbnail previews.
4. **Automatic Slot Recycling**: When you close any window, its lockfile and process handle are released. The next time you click the taskbar button, that freed slot is immediately reused without disk clutter.
5. **Pre-Seeded State & Authentication**: Newly generated slot directories automatically inherit your primary `Local State`, `Preferences`, `config.json`, and app state files, ensuring every window opens logged in with your custom themes and preferences intact.

### Multi-Task Jump List Stream Preservation
SplitSpace directly parses and generates Windows `CustomDestinations` streams located at `%APPDATA%\Microsoft\Windows\Recent\CustomDestinations\<AppUserModelIdHash>.customDestinations-ms`:
1. **Multi-Task Category 1 Injection**: Reads existing category item counts and injects the `+ <AppName>` task while preserving native tasks (such as Claude Desktop's `New Chat` and `New Code Session`).
2. **Category 2 Recent Folders Preservation**: Retains Category 2 Recent Folders, pinned repositories, and history entries.
3. **PropertyStore Metadata**: Sets `PKEY_Title` and `PKEY_AppUserModel_ID` on task shortcuts for authentic taskbar presentation.
4. **Shell Change Notification**: Triggers `SHChangeNotify(SHCNE_ASSOCCHANGED)` so the Windows Taskbar reflects changes instantly without requiring an Explorer restart.

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
