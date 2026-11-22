#!/usr/bin/env bash
# SplitSpace - Linux and macOS Universal Uninstaller
# Cleans up all generated shortcuts, wrapper actions, and isolated profile directories.
# Standard user execution only. No sudo / root required.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$SCRIPT_DIR/lib"

# Load modules
source "$LIB_DIR/discover.sh"
source "$LIB_DIR/desktop_actions.sh"
source "$LIB_DIR/macos_launcher.sh"

TARGET_APP=""
MOCK_CLEANUP=0

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        -App|--app)
            TARGET_APP="$2"
            shift 2
            ;;
        --mock)
            MOCK_CLEANUP=1
            shift
            ;;
        -h|--help)
            echo "SplitSpace Uninstaller (Linux & macOS)"
            echo "Usage: ./uninstall.sh [options]"
            echo ""
            echo "Options:"
            echo "  -App, --app <AppName>         Uninstall for specific app (Antigravity, ChatGPT, Claude)"
            echo "  --mock                        Clean up CI mock test files"
            echo "  -h, --help                    Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

OS_TYPE="$(resolve_os)"
if [ "$OS_TYPE" != "linux" ] && [ "$OS_TYPE" != "macos" ]; then
    echo "[SplitSpace] Error: Unsupported operating system: $(uname -s)"
    exit 1
fi

echo "============================================================"
echo "SplitSpace Uninstaller ($OS_TYPE)"
echo "============================================================"

REMOVED_COUNT=0

for entry in "${SUPPORTED_APPS[@]}"; do
    IFS=":" read -r app_name proc_name linux_file macos_file <<< "$entry"

    if [ -n "$TARGET_APP" ] && [ "${TARGET_APP,,}" != "${app_name,,}" ]; then
        continue
    fi

    if [ "$OS_TYPE" == "linux" ]; then
        user_desktop="$HOME/.local/share/applications/$linux_file"
        remove_linux_action "$app_name" "$user_desktop"
        REMOVED_COUNT=$((REMOVED_COUNT + 1))
    elif [ "$OS_TYPE" == "macos" ]; then
        remove_macos_launcher "$app_name"
        REMOVED_COUNT=$((REMOVED_COUNT + 1))
    fi
done

# Clean up top-level data directories if no apps specified (full uninstall)
if [ -z "$TARGET_APP" ]; then
    if [ "$OS_TYPE" == "linux" ]; then
        if [ -d "$SPLITSPACE_DATA_DIR" ]; then
            rm -rf "$SPLITSPACE_DATA_DIR"
            echo "[SplitSpace] Removed directory: $SPLITSPACE_DATA_DIR"
        fi
    elif [ "$OS_TYPE" == "macos" ]; then
        if [ -d "$SPLITSPACE_MACOS_DATA" ]; then
            rm -rf "$SPLITSPACE_MACOS_DATA"
            echo "[SplitSpace] Removed directory: $SPLITSPACE_MACOS_DATA"
        fi
        if [ -d "$SPLITSPACE_APPS_DIR" ]; then
            rm -rf "$SPLITSPACE_APPS_DIR"
            echo "[SplitSpace] Removed directory: $SPLITSPACE_APPS_DIR"
        fi
    fi
fi

# Clean up mock files if requested
if [ "$MOCK_CLEANUP" -eq 1 ]; then
    if [ "$OS_TYPE" == "linux" ]; then
        rm -f "$HOME/.local/share/applications/antigravity.desktop"
        rm -f "$HOME/.local/share/applications/chatgpt.desktop"
        rm -f "$HOME/.local/share/applications/claude.desktop"
    elif [ "$OS_TYPE" == "macos" ]; then
        rm -rf "$HOME/Applications/Google Antigravity.app"
        rm -rf "$HOME/Applications/ChatGPT.app"
        rm -rf "$HOME/Applications/Claude.app"
    fi
    echo "[SplitSpace] Cleaned up CI mock fixtures."
fi

echo "============================================================"
echo "[SplitSpace] Uninstallation complete. Cleaned up $REMOVED_COUNT application(s)."
echo "============================================================"
exit 0
