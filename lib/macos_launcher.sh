#!/usr/bin/env bash
# SplitSpace - macOS Launch Wrapper and Bundle Generator
# Uses native macOS 'open -n' instance isolation

SPLITSPACE_MACOS_DATA="$HOME/Library/Application Support/SplitSpace"
SPLITSPACE_APPS_DIR="$HOME/Applications/SplitSpace"
SPLITSPACE_BIN_DIR="$HOME/.local/bin"

# Initialize directories
init_macos_dirs() {
    mkdir -p "$SPLITSPACE_MACOS_DATA"
    mkdir -p "$SPLITSPACE_APPS_DIR"
    mkdir -p "$SPLITSPACE_BIN_DIR"
}

# Install macOS Launcher
install_macos_launcher() {
    local app_name="$1"
    local app_bundle_path="$2"
    local task_label="$3"

    init_macos_dirs

    local profile_dir="$SPLITSPACE_MACOS_DATA/$app_name/slot_1"
    mkdir -p "$profile_dir"

    local app_clean_name
    app_clean_name="$(basename "$app_bundle_path" .app)"

    # 1. Generate CLI script in ~/.local/bin
    local app_key
    app_key="$(to_lower "$app_name")"
    local cli_script="$SPLITSPACE_BIN_DIR/splitspace-$app_key"
    cat <<EOF > "$cli_script"
#!/usr/bin/env bash
# SplitSpace secondary window launcher for $app_name
open -n -a "$app_bundle_path" --args --user-data-dir="$profile_dir" "\$@"
EOF
    chmod +x "$cli_script"

    # 2. Generate minimal macOS .app bundle for Dock placement
    local wrapper_app_dir="$SPLITSPACE_APPS_DIR/+ $app_name.app"
    local contents_dir="$wrapper_app_dir/Contents"
    local macos_dir="$contents_dir/MacOS"
    mkdir -p "$macos_dir"

    # Info.plist
    cat <<EOF > "$contents_dir/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>launcher</string>
    <key>CFBundleIdentifier</key>
    <string>com.splitspace.$app_name</string>
    <key>CFBundleName</key>
    <string>+ $app_name</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>LSUIElement</key>
    <true/>
</dict>
</plist>
EOF

    # Launcher executable
    cat <<EOF > "$macos_dir/launcher"
#!/usr/bin/env bash
open -n -a "$app_bundle_path" --args --user-data-dir="$profile_dir"
EOF
    chmod +x "$macos_dir/launcher"

    echo "[SplitSpace] Generated macOS launcher: $wrapper_app_dir"
    echo "[SplitSpace] Generated CLI tool: $cli_script"
    return 0
}

# Remove macOS Launcher
remove_macos_launcher() {
    local app_name="$1"

    local app_key
    app_key="$(to_lower "$app_name")"
    local wrapper_app_dir="$SPLITSPACE_APPS_DIR/+ $app_name.app"
    local cli_script="$SPLITSPACE_BIN_DIR/splitspace-$app_key"

    if [ -d "$wrapper_app_dir" ]; then
        rm -rf "$wrapper_app_dir"
        echo "[SplitSpace] Removed macOS app wrapper for $app_name"
    fi

    if [ -f "$cli_script" ]; then
        rm -f "$cli_script"
        echo "[SplitSpace] Removed CLI tool for $app_name"
    fi

    local profile_dir="$SPLITSPACE_MACOS_DATA/$app_name"
    if [ -d "$profile_dir" ]; then
        rm -rf "$profile_dir"
        echo "[SplitSpace] Cleaned up profile slot for $app_name"
    fi

    return 0
}
