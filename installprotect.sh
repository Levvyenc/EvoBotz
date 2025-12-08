#!/bin/bash
# installprotect.sh
# FULL PROTECT MODE — PROTECT BY LEVVI CODE
# Owner = user dengan UID 1
# User lain tidak bisa lihat panel/session orang lain
# NGAPAIN YAPIT LIAT PANEL ORANG 😹

set -euo pipefail

# ============================
#  OWNER SETTING (UID 1)
# ============================
OWNER_SYSTEM_USER="$(getent passwd 1 | cut -d: -f1)"

if [ -z "$OWNER_SYSTEM_USER" ]; then
    echo "Gagal menemukan user dengan UID 1!"
    exit 1
fi

# Pterodactyl paths
PANEL_WEB_PATH="/var/www/pterodactyl"
PTERO_SESSION_PATH="/var/lib/pterodactyl/sessions"

echo "OWNER: $OWNER_SYSTEM_USER (UID 1)"
sleep 1

# ============================
#  CEK ROOT
# ============================
if [ "$(id -u)" -ne 0 ]; then
    echo "Script harus dijalankan sebagai root!"
    exit 1
fi

# ============================
#  PROTECT MESSAGE
# ============================
block_user_access() {
    local caller="${SUDO_USER:-$USER}"
    if [ "$caller" != "$OWNER_SYSTEM_USER" ] && [ "$caller" != "root" ]; then
        echo ""
        echo "NGAPAIN YAPIT LIAT PANEL ORANG 😹"
        echo "PROTECT BY LEVVI CODE"
        echo ""
        exit 1
    fi
}

# ============================
#  FILESYSTEM PROTECT
# ============================
apply_fs_protect() {
    echo "[*] Menerapkan proteksi panel & session..."

    mkdir -p "$PANEL_WEB_PATH"
    mkdir -p "$PTERO_SESSION_PATH"

    # Owner : owner_system_user
    # Webserver : www-data
    # User lain : tidak bisa baca
    chown -R root:www-data "$PANEL_WEB_PATH"
    chmod -R 750 "$PANEL_WEB_PATH"
    setfacl -R -m u:"$OWNER_SYSTEM_USER":rwx "$PANEL_WEB_PATH"
    setfacl -R -m o::--- "$PANEL_WEB_PATH"

    # Session super-protected
    chown -R root:www-data "$PTERO_SESSION_PATH"
    chmod -R 700 "$PTERO_SESSION_PATH"
    setfacl -R -m u:"$OWNER_SYSTEM_USER":rwx "$PTERO_SESSION_PATH"
    setfacl -R -m o::--- "$PTERO_SESSION_PATH"

    echo "[*] Proteksi filesystem selesai."
}

# ============================
#  MENU INSTALLER
# ============================
install_theme() {
    block_user_access

    echo "1. Stellar"
    echo "2. Billing"
    echo "3. Enigma"
    read -p "Pilih Theme: " th

    case $th in
        1) THEME="stellar" ;;
        2) THEME="billing" ;;
        3) THEME="enigma" ;;
        *) echo "Pilihan tidak valid."; return ;;
    esac

    URL="https://github.com/SkyzoOffc/Pterodactyl-Theme-Autoinstaller/raw/main/${THEME}.zip"
    wget -q -O /root/theme.zip "$URL"
    unzip -oq /root/theme.zip -d /root/theme

    cp -rfT /root/theme "$PANEL_WEB_PATH"

    cd "$PANEL_WEB_PATH"
    yarn install || true
    yarn build:production || true
    php artisan view:clear || true

    rm -rf /root/theme /root/theme.zip
    apply_fs_protect

    echo "Theme berhasil diinstall & diproteksi."
}

reset_session_protect() {
    block_user_access
    echo "[*] Memperbaiki proteksi session..."
    chmod -R 700 "$PTERO_SESSION_PATH"
    setfacl -R -m u:"$OWNER_SYSTEM_USER":rwx "$PTERO_SESSION_PATH"
    setfacl -R -m o::--- "$PTERO_SESSION_PATH"
    echo "[*] Done."
}

# ============================
#  MENU UTAMA
# ============================
while true; do
    echo "===== INSTALL PROTECT by LEVVI CODE ====="
    echo "OWNER: $OWNER_SYSTEM_USER (UID 1)"
    echo ""
    echo "1. Pasang Theme"
    echo "2. Perbaiki Proteksi Session"
    echo "3. Terapkan Ulang Proteksi"
    echo "x. Keluar"
    read -p "Pilih: " menu

    case $menu in
        1) install_theme ;;
        2) reset_session_protect ;;
        3) apply_fs_protect ;;
        x) exit 0 ;;
        *) echo "Pilihan tidak valid." ;;
    esac
done