#!/usr/bin/env bash
# ============================================================
# SolarUI on Jubatus - Uninstaller
# Removes Niri + Noctalia configs and SolarUI assets
# ============================================================
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
info()  { echo -e "${BLUE}[INFO]${NC} $*"; }
ok()    { echo -e "${GREEN}[OK]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }

echo -e "${YELLOW}This script will remove:${NC}"
echo "  - /usr/local/bin/niri (Niri binary)"
echo "  - /usr/share/wayland-sessions/niri-solarui.desktop (session file)"
echo "  - /usr/share/solarui (assets)"
echo "  - ~/.config/niri/config.kdl (backed up)"
echo "  - ~/.config/noctalia/settings.toml (backed up)"
echo ""
echo "The Noctalia APT package will NOT be removed (manual: sudo apt remove noctalia)"
echo ""
read -rp "Continue? [y/N] " ans
[[ "$ans" =~ ^[Yy]$ ]] || { info "Cancelled."; exit 0; }

# Niri binary
if [[ -f /usr/local/bin/niri ]]; then
    sudo rm -f /usr/local/bin/niri
    ok "Niri binary removed."
fi

# Session file
if [[ -f /usr/share/wayland-sessions/niri-solarui.desktop ]]; then
    sudo rm -f /usr/share/wayland-sessions/niri-solarui.desktop
    ok "Session file removed."
fi

# Assets
if [[ -d /usr/share/solarui ]]; then
    sudo rm -rf /usr/share/solarui
    ok "Assets removed: /usr/share/solarui"
fi

# Backup and remove configs
TS=$(date +%s)
if [[ -f "$HOME/.config/niri/config.kdl" ]]; then
    cp "$HOME/.config/niri/config.kdl" "$HOME/.config/niri/config.kdl.uninstalled.$TS"
    rm -f "$HOME/.config/niri/config.kdl"
# Clean Noctalia and Niri caches/state
rm -rf "$HOME/.cache/noctalia"
rm -rf "$HOME/.local/state/noctalia"
rm -rf "$HOME/.local/share/noctalia"
rm -rf "$HOME/.config/noctalia"
# Remove welcome marker (so wizard runs on next install)
rm -f "$HOME/.config/blazeos/.welcome-completed"
ok "Noctalia caches and state cleared."
    ok "Niri config backed up and removed."
fi

if [[ -f "$HOME/.config/noctalia/settings.toml" ]]; then
    cp "$HOME/.config/noctalia/settings.toml" "$HOME/.config/noctalia/settings.toml.uninstalled.$TS"
    rm -f "$HOME/.config/noctalia/settings.toml"
    ok "Noctalia settings backed up and removed."
fi

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN} SolarUI on Jubatus uninstalled.      ${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "Note: Noctalia is still installed on the system. To remove it:"
echo "  sudo apt remove --purge noctalia noctalia-data"
echo ""
