#!/usr/bin/env bash
# SplitSpace - Linux and macOS Universal Installer
# Enables multi-window multitasking for AI desktop applications.
# Standard user execution only. No sudo / root required.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$SCRIPT_DIR/lib"

# Load modules
source "$LIB_DIR/discover.sh"
source "$LIB_DIR/desktop_actions.sh"
source "$LIB_DIR/macos_launcher.sh"

TARGET_APP=""
CUSTOM_LABEL=""
MOCK_MODE=0

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        -App|--app)
            TARGET_APP="$2"
            shift 2
            ;;
        -TaskLabel|--task-label)
            CUSTOM_LABEL="$2"
            shift 2
            ;;
        --mock)
            MOCK_MODE=1
            shift
            ;;
        -h|--help)
            echo "SplitSpace Installer (Linux & macOS)"
            echo "Usage: ./install.sh [options]"
            echo ""
            echo "Options:"
            echo "  -App, --app <AppName>         Install for specific app (Antigravity, ChatGPT, Claude)"
            echo "  -TaskLabel, --task-label <L>  Custom label for secondary launch task"
            echo "  --mock                        Enable mock mode for CI testing"
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
echo "SplitSpace Installer ($OS_TYPE)"
echo "============================================================"

# Handle CI Mock Mode
if [ "$MOCK_MODE" -eq 1 ]; then
    echo "[SplitSpace] Mock mode enabled: generating test application stubs..."
    if [ "$OS_TYPE" == "linux" ]; then
        MOCK_APPS_DIR="$HOME/.local/share/applications"
        mkdir -p "$MOCK_APPS_DIR"
        cat <<EOF > "$MOCK_APPS_DIR/antigravity.desktop"
[Desktop Entry]
Name=Google Antigravity
Exec=/usr/bin/true
Type=Application
Terminal=false
Categories=Utility;
EOF
        cat <<EOF > "$MOCK_APPS_DIR/chatgpt.desktop"
[Desktop Entry]
Name=ChatGPT
Exec=/usr/bin/true
Type=Application
Terminal=false
Categories=Utility;
EOF
        cat <<EOF > "$MOCK_APPS_DIR/claude.desktop"
[Desktop Entry]
Name=Claude
Exec=/usr/bin/true
Type=Application
Terminal=false
Categories=Utility;
EOF
    elif [ "$OS_TYPE" == "macos" ]; then
        MOCK_APPS_DIR="$HOME/Applications"
        mkdir -p "$MOCK_APPS_DIR/Google Antigravity.app/Contents/MacOS"
        mkdir -p "$MOCK_APPS_DIR/ChatGPT.app/Contents/MacOS"
        mkdir -p "$MOCK_APPS_DIR/Claude.app/Contents/MacOS"
        touch "$MOCK_APPS_DIR/Google Antigravity.app/Contents/MacOS/Antigravity"
        touch "$MOCK_APPS_DIR/ChatGPT.app/Contents/MacOS/ChatGPT"
        touch "$MOCK_APPS_DIR/Claude.app/Contents/MacOS/Claude"
    fi
fi

INSTALLED_COUNT=0

for entry in "${SUPPORTED_APPS[@]}"; do
    IFS=":" read -r app_name proc_name linux_file macos_file <<< "$entry"

    # Filter by specific app if requested
    if [ -n "$TARGET_APP" ] && [ "$(to_lower "$TARGET_APP")" != "$(to_lower "$app_name")" ]; then
        continue
    fi

    task_label="${CUSTOM_LABEL:-+ $app_name}"

    if [ "$OS_TYPE" == "linux" ]; then
        found_target="$(discover_linux_app "$app_name" "$linux_file")"
        if [ -n "$found_target" ]; then
            echo "[SplitSpace] Discovered $app_name at: $found_target"
            install_linux_action "$app_name" "$found_target" "$task_label"
            INSTALLED_COUNT=$((INSTALLED_COUNT + 1))
        else
            echo "[SplitSpace] $app_name: Not detected on system."
        fi
    elif [ "$OS_TYPE" == "macos" ]; then
        found_target="$(discover_macos_app "$app_name" "$macos_file")"
        if [ -n "$found_target" ]; then
            echo "[SplitSpace] Discovered $app_name at: $found_target"
            install_macos_launcher "$app_name" "$found_target" "$task_label"
            INSTALLED_COUNT=$((INSTALLED_COUNT + 1))
        else
            echo "[SplitSpace] $app_name: Not detected on system."
        fi
    fi
done

echo "============================================================"
echo "[SplitSpace] Installation complete. Integrated $INSTALLED_COUNT application(s)."
echo "============================================================"
exit 0
