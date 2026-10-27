#!/usr/bin/env bash
# Niri 25.05 compatibility fixes for BlazeOS SolarUI config
set -euo pipefail

CONFIG="${1:?Usage: fix-niri-config.sh <config.kdl>}"

if [ ! -f "$CONFIG" ]; then
    echo "ERR: config not found: $CONFIG" >&2
    exit 1
fi

# 1. Remove background-effect blocks (not supported in Niri 25.05)
perl -0777 -i -pe 's/\n[ \t]*background-effect\s*\{[^{}]*(?:\{[^{}]*\}[^{}]*)*\}//gs' "$CONFIG"

# 2. Convert spawn-sh "X" to spawn "sh" "-c" "X"
sed -i -E 's/spawn-sh[[:space:]]+"([^"]*)"/spawn "sh" "-c" "\1"/g' "$CONFIG"

# 3. Comment out all solar-shell lines
awk '/solar-shell/ && !/^[[:space:]]*\/\// { print "// " $0; next } { print }' "$CONFIG" > "$CONFIG.tmp"
mv "$CONFIG.tmp" "$CONFIG"

# 4. Comment out BlazeOS-specific spawn lines
sed -i 's|^spawn-at-startup "/usr/libexec/blazeos-wayland-session-ready"|// spawn-at-startup "/usr/libexec/blazeos-wayland-session-ready"|' "$CONFIG"
sed -i 's|^spawn-at-startup "solar-shell" "autostart"|// spawn-at-startup "solar-shell" "autostart"|' "$CONFIG"

# 5. Remove all existing noctalia/welcome/dbus spawn lines
sed -i '/spawn-at-startup.*noctalia/d' "$CONFIG"
sed -i '/spawn-at-startup.*dbus-update-activation-environment/d' "$CONFIG"

# 6. Add clean startup lines
TMPFILE=$(mktemp)
awk '
/^\/\/ spawn-at-startup "solar-shell" "autostart"/ {
    print
    print "spawn-at-startup \"dbus-update-activation-environment\" \"--systemd\" \"--all\""
    print "spawn-at-startup \"sh\" \"-c\" \"sleep 5 && noctalia --daemon\""
    next
}
{ print }
' "$CONFIG" > "$TMPFILE"
mv "$TMPFILE" "$CONFIG"

# 7. Add XDG_CURRENT_DESKTOP environment block if missing
if ! grep -q 'XDG_CURRENT_DESKTOP "SolarUI"' "$CONFIG"; then
    TMPFILE=$(mktemp)
    {
        echo 'environment {'
        echo '    XDG_CURRENT_DESKTOP "SolarUI"'
        echo '}'
        echo ''
        cat "$CONFIG"
    } > "$TMPFILE"
    mv "$TMPFILE" "$CONFIG"
fi

# 8. Force Mod key to Super
if ! grep -q 'mod-key "Super"' "$CONFIG"; then
    if ! grep -q '^input {' "$CONFIG"; then
        TMPFILE=$(mktemp)
        {
            echo 'input {'
            echo '    mod-key "Super"'
            echo '}'
            echo ''
            cat "$CONFIG"
        } > "$TMPFILE"
        mv "$TMPFILE" "$CONFIG"
    else
        sed -i '/^input {/a\    mod-key "Super"' "$CONFIG"
    fi
fi

# 9. Add consume/expel keybinds for vertical window management
if ! grep -q 'consume-window-into-column' "$CONFIG"; then
    TMPFILE=$(mktemp)
    awk '
    /Mod\+Ctrl\+Up    \{ move-window-up; \}/ {
        print
        print "    Mod+Ctrl+J     { move-window-down; }"
        print "    Mod+Ctrl+K     { move-window-up; }"
        print "    Mod+Ctrl+H     { consume-window-into-column; }"
        print "    Mod+Ctrl+L     { expel-window-from-column; }"
        next
    }
    { print }
    ' "$CONFIG" > "$TMPFILE"
    mv "$TMPFILE" "$CONFIG"
fi

# 10. Validate
if ! niri validate -c "$CONFIG" >/dev/null 2>&1; then
    echo "ERR: config validation failed after fixes" >&2
    niri validate -c "$CONFIG"
    exit 1
fi

echo "OK: config fixed and valid: $CONFIG"

# 20. Ensure environment block has DISPLAY and GDK_BACKEND
if ! grep -q 'GDK_BACKEND "x11"' "$CONFIG"; then
    if grep -q '^environment {' "$CONFIG"; then
        sed -i '/^environment {/a\    GDK_BACKEND "x11"' "$CONFIG"
    else
        TMPFILE=$(mktemp)
        {
            echo 'environment {'
            echo '    GDK_BACKEND "x11"'
            echo '}'
            echo ''
            cat "$CONFIG"
        } > "$TMPFILE"
        mv "$TMPFILE" "$CONFIG"
    fi
fi

# 21. Add welcome spawn-at-startup (remove autostart dependency)
if ! grep -q 'spawn-at-startup.*blazeos-welcome' "$CONFIG"; then
    TMPFILE=$(mktemp)
    awk '
    /spawn-at-startup "sh" "-c" "sleep 5 && noctalia --daemon"/ {
        print
        print "spawn-at-startup \"sh\" \"-c\" \"sleep 8 && /usr/local/bin/blazeos-welcome\""
        next
    }
    { print }
    ' "$CONFIG" > "$TMPFILE"
    mv "$TMPFILE" "$CONFIG"
fi

# 22. Remove welcome from autostart (avoid conflict)
if [ -f "$HOME/.config/autostart/blazeos-welcome.desktop" ]; then
    rm -f "$HOME/.config/autostart/blazeos-welcome.desktop"
fi

# 23. Re-validate
if ! niri validate -c "$CONFIG" >/dev/null 2>&1; then
    echo "ERR: config validation failed after welcome spawn fix" >&2
    niri validate -c "$CONFIG"
    exit 1
fi

# 24. Ensure xwayland-satellite starts (for YAD/X11 apps)
if ! grep -q 'xwayland-satellite' "$CONFIG"; then
    TMPFILE=$(mktemp)
    awk '
    /spawn-at-startup "sh" "-c" "sleep 5 && noctalia --daemon"/ {
        print
        print "spawn-at-startup \"xwayland-satellite\""
        next
    }
    { print }
    ' "$CONFIG" > "$TMPFILE"
    mv "$TMPFILE" "$CONFIG"
fi

# 25. Re-validate
if ! niri validate -c "$CONFIG" >/dev/null 2>&1; then
    echo "ERR: config validation failed after xwayland fix" >&2
    niri validate -c "$CONFIG"
    exit 1
fi

# 26. Force blazeos-welcome to open on workspace 1
if ! grep -q 'blazeos-welcome.*workspace' "$CONFIG"; then
    TMPFILE=$(mktemp)
    {
        cat "$CONFIG"
        echo ''
        echo '// Force SolarUI Welcome to workspace 1'
        echo 'window-rule {'
        echo '    match app-id=r#"^(blazeos-welcome|yad)$"#'
        echo '    open-on-workspace "1"'
        echo '    open-focused true'
        echo '    open-floating true'
        echo '    default-column-width { fixed 600; }'
        echo '    default-window-height { fixed 500; }'
        echo '}'
    } > "$TMPFILE"
    mv "$TMPFILE" "$CONFIG"
fi

# 27. Re-validate
if ! niri validate -c "$CONFIG" >/dev/null 2>&1; then
    echo "ERR: config validation failed after welcome workspace rule" >&2
    niri validate -c "$CONFIG"
    exit 1
fi

# 28. Center blazeos-welcome window and limit its size
# Remove old welcome window-rule if exists
perl -0777 -i -pe 's/\n\/\/ Force SolarUI Welcome to workspace 1\nwindow-rule \{.*?\n\}\n//gs' "$CONFIG"

# Add new centered window-rule
TMPFILE=$(mktemp)
{
    cat "$CONFIG"
    echo ''
    echo '// SolarUI Welcome - centered, fixed size, workspace 1'
    echo 'window-rule {'
    echo '    match app-id=r#"^(blazeos-welcome|yad)$"#'
    echo '    open-on-workspace "1"'
    echo '    open-focused true'
    echo '    open-floating true'
    echo '    default-column-width { fixed 600; }'
    echo '    default-window-height { fixed 450; }'
    echo '    max-width 600'
    echo '    max-height 450'
    echo '}'
} > "$TMPFILE"
mv "$TMPFILE" "$CONFIG"

# 29. Re-validate
if ! niri validate -c "$CONFIG" >/dev/null 2>&1; then
    echo "ERR: config validation failed after welcome center rule" >&2
    niri validate -c "$CONFIG"
    exit 1
fi
