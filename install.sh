#!/usr/bin/env bash
# ============================================================
# SolarUI 5.05 on Jubatus (Debian 13 Trixie) - Installer
# ============================================================
set -euo pipefail

SOLARUI_VERSION="5.05"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
info()  { echo -e "${BLUE}[INFO]${NC} $*"; }
ok()    { echo -e "${GREEN}[OK]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
err()   { echo -e "${RED}[ERR]${NC} $*" >&2; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

if ! grep -q 'VERSION_ID="13"' /etc/os-release 2>/dev/null; then
    warn "This script is designed for Debian 13 (Trixie)."
    read -rp "Continue anyway? [y/N] " ans
    [[ "$ans" =~ ^[Yy]$ ]] || exit 1
fi

if [[ $EUID -eq 0 ]]; then
    err "Do not run as root. 'sudo' will be requested where needed."
    exit 1
fi

# --- Dependencies ---
info "Checking system dependencies..."
sudo apt update
sudo apt install -y \
    build-essential pkg-config libudev-dev libseat-dev \
    libinput-dev libgbm-dev libxkbcommon-dev libpango1.0-dev \
    libgdk-pixbuf-2.0-dev libwayland-dev libegl1-mesa-dev \
    libfontconfig-dev libsystemd-dev libdbus-1-dev libpipewire-0.3-dev \
    libdisplay-info-dev libclang-dev rustc cargo git wget yad \
    alacritty fuzzel xwayland xdg-desktop-portal-gtk \
    pipewire wireplumber polkitd swaybg xwayland-satellite xwayland-satellite
ok "Dependencies ready."
# --- xwayland-satellite (not in Debian repos) ---
if ! command -v xwayland-satellite >/dev/null 2>&1; then
    info "Installing xwayland-satellite from TileOS repo..."
    wget -O /tmp/xwayland-satellite.deb https://repo.tile-os.com/testing/pool/main/x/xwayland-satellite/xwayland-satellite_0.7-1_amd64.deb
    sudo apt install -y /tmp/xwayland-satellite.deb
    ok "xwayland-satellite installed."
else
    ok "xwayland-satellite already installed."
fi

# --- Noctalia APT repo ---
if ! command -v noctalia >/dev/null 2>&1; then
    info "Adding Noctalia APT repository..."
    wget -O /tmp/nickh-archive-keyring.deb https://pkg.noctalia.dev/deb/nickh-archive-keyring.deb
    sudo apt install -y /tmp/nickh-archive-keyring.deb
    sudo wget -O /etc/apt/sources.list.d/noctalia-trixie.sources \
        https://pkg.noctalia.dev/deb/noctalia-trixie.sources
    sudo apt update
    sudo apt install -y noctalia
    ok "Noctalia installed."
else
    ok "Noctalia already installed: $(noctalia --version 2>/dev/null || echo 'version unknown')"
# Fix Noctalia welcome message for SolarUI branding
if [ -f /usr/share/noctalia/assets/translations/tr.json ]; then
    sudo sed -i "s/SolarUI.a Hoş Geldiniz/SolarUI'ye Hoş Geldiniz/g" /usr/share/noctalia/assets/translations/tr.json 2>/dev/null || true
    sudo sed -i "s/Noctalia'ya Hoş Geldiniz/SolarUI'ye Hoş Geldiniz/g" /usr/share/noctalia/assets/translations/tr.json 2>/dev/null || true
fi
if [ -f /usr/share/noctalia/assets/translations/en.json ]; then
    sudo sed -i 's/"Welcome to Noctalia"/"Welcome to SolarUI"/g' /usr/share/noctalia/assets/translations/en.json 2>/dev/null || true
fi
fi

# --- Niri binary ---
if [[ ! -x build/bin/niri ]]; then
    info "Niri binary not found, building..."
    if [[ ! -d build/niri-src ]]; then
        git clone https://github.com/YaLTeR/niri.git build/niri-src
        git -C build/niri-src checkout v25.05
    fi
    ( cd build/niri-src && cargo build --release )
    mkdir -p build/bin
    cp build/niri-src/target/release/niri build/bin/niri
fi
info "Installing Niri..."
sudo install -Dm755 build/bin/niri /usr/local/bin/niri

# --- Wayland session file ---
sudo tee /usr/share/wayland-sessions/niri-solarui.desktop > /dev/null <<DESKTOP
[Desktop Entry]
Name=SolarUI (Niri)
Comment=SolarUI 5.05 on Jubatus - Niri + Noctalia
Exec=niri --session
Type=Application
DesktopNames=niri
DESKTOP
ok "Wayland session file added: niri-solarui.desktop"

# --- Configs ---
info "Copying Niri and Noctalia configurations..."
mkdir -p "$HOME/.config/niri" "$HOME/.config/noctalia"
[[ -f "$HOME/.config/niri/config.kdl" ]] && \
    cp "$HOME/.config/niri/config.kdl" "$HOME/.config/niri/config.kdl.bak.$(date +%s)"
cp configs/niri/config.kdl "$HOME/.config/niri/config.kdl"
cp configs/noctalia/settings.toml "$HOME/.config/noctalia/settings.toml"
# Ensure wallpaper path is correct
sed -i 's|^path = .*|path = "/usr/share/solarui/wallpapers/wallpapergreen.jpeg"|' "$HOME/.config/noctalia/settings.toml"

# Apply Niri 25.05 compatibility fixes
bash ./fix-niri-config.sh "$HOME/.config/niri/config.kdl"
ok "Configs copied and fixed."

# --- Assets ---
info "Copying SolarUI assets to /usr/share/solarui..."
sudo mkdir -p /usr/share/solarui
sudo cp -r assets/usr-share-solarui/* /usr/share/solarui/
ok "Assets installed: /usr/share/solarui"

# --- Welcome wizard ---
info "Installing BlazeOS Welcome wizard..."
sudo install -Dm755 welcome/blazeos-welcome-helper /usr/libexec/blazeos-welcome-helper
sudo install -Dm755 welcome/blazeos-welcome /usr/local/bin/blazeos-welcome

sudo tee /usr/share/applications/blazeos-welcome.desktop > /dev/null <<'DESKTOP_APP'
[Desktop Entry]
Type=Application
Name=SolarUI Welcome
Comment=First-boot setup wizard for SolarUI 5.05
Exec=/usr/local/bin/blazeos-welcome
Icon=/usr/share/solarui/icons/solarui-logo.png
Terminal=false
Categories=System;Settings;
DESKTOP_APP

mkdir -p "$HOME/.config/autostart"
cat > "$HOME/.config/autostart/blazeos-welcome.desktop" <<'AUTOSTART'
[Desktop Entry]
Type=Application
Name=SolarUI Welcome
Comment=First-boot setup wizard for SolarUI
Exec=/usr/local/bin/blazeos-welcome
Icon=/usr/share/solarui/icons/solarui-logo.png
Terminal=false
X-GNOME-Autostart-enabled=true
X-GNOME-Autostart-Delay=8
StartupNotify=false
AUTOSTART
ok "BlazeOS Welcome wizard installed."

# --- Verification ---
info "Verifying installation..."
niri validate -c "$HOME/.config/niri/config.kdl" && ok "Niri config is valid." || err "Config validation failed!"
command -v noctalia >/dev/null && ok "Noctalia available." || err "Noctalia not found!"
[[ -f /usr/share/wayland-sessions/niri-solarui.desktop ]] && ok "Session file exists." || warn "Session file missing."

if [[ ! -f /usr/share/solarui/wallpapers/wallpapergreen.jpeg ]]; then
    warn "Wallpaper not found: /usr/share/solarui/wallpapers/wallpapergreen.jpeg"
fi

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN} SolarUI ${SOLARUI_VERSION} on Jubatus installation done! ${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "Next steps:"
echo "  1) Log out (or reboot)"
echo "  2) Select \"SolarUI\" at the login screen"
echo "  3) Log in - Noctalia will start automatically"
echo ""
