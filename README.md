# SolarUI 5.05 on Jubatus

> **Based on:** BlazeOS SolarEvolution 5.05 (Niri + Noctalia)
> **Noctalia version:** 5.4.0
> **Niri version:** 25.05

**BlazeOS'un SolarUI masaüstünü Debian 13 (Trixie) / Jubatus üzerinde çalıştırma projesi.**

SolarUI; Niri (Wayland compositor) + Noctalia (masaüstü kabuğu) + BlazeOS'un
BCDL Kinetic Glass tasarım dilinin birleşimidir. Bu proje, o deneyimi
Debian tabanlı sistemlerde yeniden üretir.

## Gereksinimler

- Debian 13 (Trixie) - amd64
- sudo yetkili kullanıcı
- İnternet bağlantısı (APT depoları + Noctalia deposu)
- ~2 GB disk (Rust derlemesi için)

## Kurulum

    git clone <bu-depo-url> SolarUI-Jubatus-Build
    cd SolarUI-Jubatus-Build
    ./install.sh

Kurulum sonrası:

1. Oturumu kapat (veya reboot)
2. Giriş ekranında "Niri (SolarUI)" seç
3. Giriş yap - Noctalia otomatik başlar

## Kaldırma

    ./uninstall.sh

Noctalia'yı da tamamen kaldırmak istersen:

    sudo apt remove --purge noctalia noctalia-data fonts-noctalia-tabler

## Ne kurulur?

| Bileşen | Konum | Kaynak |
|---|---|---|
| Niri 25.05 | /usr/local/bin/niri | Kaynak koddan derlenir (build/niri-src) |
| Noctalia 5.4.0 | APT (noctalia) | pkg.noctalia.dev |
| Niri config | ~/.config/niri/config.kdl | configs/niri/config.kdl |
| Noctalia settings | ~/.config/noctalia/settings.toml | configs/noctalia/settings.toml |
| SolarUI assets | /usr/share/solarui/ | assets/usr-share-solarui/ |
| Wayland oturumu | /usr/share/wayland-sessions/niri-solarui.desktop | Üretilir |

## Sorun giderme

**Niri giriş ekranında görünmüyor:**

    ls /usr/share/wayland-sessions/
    command -v niri

**Noctalia açılmıyor:**

    noctalia
    tail -n 100 ~/.cache/noctalia/noctalia.log

**Siyah ekran:**

    # Ctrl+Alt+F3 ile TTY'ye geç, sonra:
    journalctl --user -b --no-pager -n 100

## Kaynaklar

- SolarUI - BlazeOS: https://blazeos.com.tr/solarui/
- Niri belgeleri: https://niri-wm.github.io/niri/
- Noctalia belgeleri: https://docs.noctalia.dev/
- BlazeOS kaynak kodu: https://github.com/DarkMorpheus-pc/Blaze-Galaxy
