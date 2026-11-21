# Contributing to SplitSpace

Thank you for your interest in improving SplitSpace. This document outlines the guidelines and workflow for contributing to the project.

## Guiding Principles

Contributions must align with the core architectural rules of SplitSpace:

1. Zero Administrative Privilege: All functionality must run entirely within standard user permissions without triggering UAC elevation.
2. Symmetrical Lifecycle: Any shortcut, taskbar pinned entry, task, or registry key registered in `install.ps1` must have an exact removal equivalent in `uninstall.ps1`.
3. Dynamic Path Resolution: Never hardcode absolute user directory paths. Always resolve directories dynamically using `$env:LOCALAPPDATA`, `$env:APPDATA`, `$env:USERPROFILE`, or standard shell API folders.
4. Minimal Dependencies: Keep the core utility lightweight. Leverage native PowerShell and standard Windows API / Shell interfaces without adding external runtime dependencies.
5. Zero Emojis: All code, comments, documentation, commit messages, and PR descriptions must maintain a clean, professional aesthetic without emojis.

## Development and Testing Workflow

### Prerequisites

- Windows 10 or Windows 11 (64-bit)
- Windows PowerShell 5.1 or PowerShell 7+
- One or more supported AI desktop applications installed locally

### Local Verification Steps

Before submitting changes, test the complete lifecycle locally:

1. Clone your fork:
   ```powershell
   git clone https://github.com/<your-username>/SplitSpace.git
   cd SplitSpace
   ```

2. Test installation:
   ```powershell
   .\install.ps1
   ```
   Verify that:
   - Target desktop apps are detected correctly.
   - Taskbar shortcuts and Jump List items are generated with proper icons.
   - Launching a secondary window creates an isolated instance without authentication loops.

3. Test uninstallation:
   ```powershell
   .\uninstall.ps1
   ```
   Verify that:
   - All generated Jump List tasks and wrapper shortcuts are removed.
   - Pinned taskbar items are cleaned up.
   - No orphaned files or registry entries remain.

## Submitting Pull Requests

1. Create a feature branch from `main`:
   ```powershell
   git checkout -b feature/your-feature-name
   ```
2. Commit your changes with clear, descriptive commit messages describing what and why.
3. Push to your fork and submit a Pull Request against the `main` branch.
4. Complete the PR template checklist to confirm that lifecycle symmetry, dynamic path handling, and test verification have been performed.
