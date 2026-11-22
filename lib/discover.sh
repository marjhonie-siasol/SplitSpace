#!/usr/bin/env bash
# SplitSpace - Cross-Platform Application Discovery Engine (Linux & macOS)
# Zero telemetry, zero administrative elevation required.

# Portable lowercase conversion (Compatible with macOS Bash 3.2 and modern Bash)
to_lower() {
    echo "$1" | tr '[:upper:]' '[:lower:]'
}

# Resolve operating system
resolve_os() {
    local os_name
    os_name="$(uname -s)"
    case "$os_name" in
        Linux*)   echo "linux" ;;
        Darwin*)  echo "macos" ;;
        *)        echo "unknown" ;;
    esac
}

# Supported application identifiers
# Format: AppName:ProcessName:LinuxDesktopName:MacOSAppName
SUPPORTED_APPS=(
    "Antigravity:antigravity:antigravity.desktop:Google Antigravity.app"
    "ChatGPT:chatgpt:chatgpt.desktop:ChatGPT.app"
    "Claude:claude:claude.desktop:Claude.app"
)

# Discover target application on Linux
discover_linux_app() {
    local target_app="$1"
    local search_desktop="$2"
    local found_file=""

    # Search directories in order of priority (User local first, then system)
    local search_dirs=(
        "$HOME/.local/share/applications"
        "/usr/local/share/applications"
        "/usr/share/applications"
        "/var/lib/flatpak/exports/share/applications"
        "$HOME/.local/share/flatpak/exports/share/applications"
        "/var/lib/snapd/desktop/applications"
    )

    for dir in "${search_dirs[@]}"; do
        if [ -d "$dir" ]; then
            if [ -f "$dir/$search_desktop" ]; then
                found_file="$dir/$search_desktop"
                break
            fi
            # Case-insensitive / wildcard search
            local match
            match="$(find "$dir" -maxdepth 1 -iname "*$target_app*.desktop" 2>/dev/null | head -n 1)"
            if [ -n "$match" ] && [ -f "$match" ]; then
                # Exclude IDE variants for Antigravity
                if [[ "$target_app" == "Antigravity" ]] && [[ "$match" =~ (IDE|ide) ]]; then
                    continue
                fi
                found_file="$match"
                break
            fi
        fi
    done

    echo "$found_file"
}

# Discover target application on macOS
discover_macos_app() {
    local target_app="$1"
    local app_bundle_name="$2"
    local found_bundle=""

    local search_dirs=(
        "$HOME/Applications"
        "/Applications"
        "/System/Applications"
    )

    for dir in "${search_dirs[@]}"; do
        if [ -d "$dir/$app_bundle_name" ]; then
            found_bundle="$dir/$app_bundle_name"
            break
        fi
        # Wildcard fallback
        local match
        match="$(find "$dir" -maxdepth 2 -iname "*$target_app*.app" 2>/dev/null | head -n 1)"
        if [ -n "$match" ] && [ -d "$match" ]; then
            if [[ "$target_app" == "Antigravity" ]] && [[ "$match" =~ (IDE|ide) ]]; then
                continue
            fi
            found_bundle="$match"
            break
        fi
    done

    echo "$found_bundle"
}
