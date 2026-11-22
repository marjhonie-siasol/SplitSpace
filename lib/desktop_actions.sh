#!/usr/bin/env bash
# SplitSpace - Linux FreeDesktop .desktop Action Injector and Cleaner
# Complies with FreeDesktop.org Desktop Entry Specification

ACTION_ID="SplitSpaceNewWindow"
SPLITSPACE_DATA_DIR="$HOME/.local/share/splitspace"
STATE_FILE="$SPLITSPACE_DATA_DIR/state_linux.json"

# Initialize state directory
init_state_dir() {
    mkdir -p "$SPLITSPACE_DATA_DIR"
    if [ ! -f "$STATE_FILE" ]; then
        echo "{}" > "$STATE_FILE"
    fi
}

# Install FreeDesktop Action on Linux
install_linux_action() {
    local app_name="$1"
    local source_desktop="$2"
    local task_label="$3"

    init_state_dir

    local user_apps_dir="$HOME/.local/share/applications"
    mkdir -p "$user_apps_dir"

    local desktop_filename
    desktop_filename="$(basename "$source_desktop")"
    local target_desktop="$user_apps_dir/$desktop_filename"

    # If user doesn't already have a local override, copy system .desktop file
    if [ ! -f "$target_desktop" ]; then
        cp "$source_desktop" "$target_desktop"
        chmod u+w "$target_desktop"
    fi

    # Read base Exec command from desktop entry
    local base_exec
    base_exec="$(grep -E "^Exec=" "$target_desktop" | head -n 1 | cut -d'=' -f2-)"
    # Strip field codes like %u, %U, %f, %F
    base_exec="$(echo "$base_exec" | sed -E 's/%[uUfFkKdDnNicvm]//g' | sed -E 's/^[[:space:]]+|[[:space:]]+$//g')"

    if [ -z "$base_exec" ]; then
        echo "[SplitSpace] Error: Could not determine Exec command from $target_desktop"
        return 1
    fi

    # Profile isolation directory for secondary instances
    local app_key
    app_key="$(to_lower "$app_name")"
    local profile_dir="$SPLITSPACE_DATA_DIR/$app_key/slot_1"
    mkdir -p "$profile_dir"

    # Remove existing SplitSpace action if re-installing
    remove_linux_action "$app_name" "$target_desktop" "silent"

    # Ensure Actions list contains our ACTION_ID
    if grep -q "^Actions=" "$target_desktop"; then
        if ! grep "^Actions=" "$target_desktop" | grep -q "$ACTION_ID"; then
            sed -i "/^Actions=/ s/$/;$ACTION_ID;/" "$target_desktop"
            # Normalize consecutive semicolons
            sed -i "s/;;/;/g" "$target_desktop"
        fi
    else
        # Append Actions= right under [Desktop Entry]
        sed -i "/^\[Desktop Entry\]/a Actions=$ACTION_ID;" "$target_desktop"
    fi

    # Append the Desktop Action definition
    cat <<EOF >> "$target_desktop"

[Desktop Action $ACTION_ID]
Name=$task_label
Exec=$base_exec --user-data-dir=$profile_dir
EOF

    # Update desktop database if available
    if command -v update-desktop-database >/dev/null 2>&1; then
        update-desktop-database "$user_apps_dir" >/dev/null 2>&1 || true
    fi

    echo "[SplitSpace] Registered Desktop Action for $app_name in $target_desktop"
    return 0
}

# Remove FreeDesktop Action on Linux
remove_linux_action() {
    local app_name="$1"
    local target_desktop="$2"
    local silent_mode="$3"

    if [ ! -f "$target_desktop" ]; then
        local user_apps_dir="$HOME/.local/share/applications"
        local match
        match="$(find "$user_apps_dir" -maxdepth 1 -iname "*$app_name*.desktop" 2>/dev/null | head -n 1)"
        if [ -n "$match" ] && [ -f "$match" ]; then
            target_desktop="$match"
        else
            if [ "$silent_mode" != "silent" ]; then
                echo "[SplitSpace] No user-level .desktop override found for $app_name"
            fi
            return 0
        fi
    fi

    # Remove ACTION_ID from Actions line
    if grep -q "^Actions=" "$target_desktop"; then
        sed -i "s/$ACTION_ID;//g" "$target_desktop"
        sed -i "s/$ACTION_ID//g" "$target_desktop"
        # Clean trailing or duplicate semicolons
        sed -i "s/;;/;/g" "$target_desktop"
        sed -i "s/Actions=;/Actions=/g" "$target_desktop"
    fi

    # Remove [Desktop Action SplitSpaceNewWindow] and its sub-keys
    sed -i "/\[Desktop Action $ACTION_ID\]/,/^$/d" "$target_desktop"

    # Update desktop database if available
    if command -v update-desktop-database >/dev/null 2>&1; then
        update-desktop-database "$(dirname "$target_desktop")" >/dev/null 2>&1 || true
    fi

    if [ "$silent_mode" != "silent" ]; then
        echo "[SplitSpace] Removed Desktop Action for $app_name from $target_desktop"
    fi

    return 0
}
