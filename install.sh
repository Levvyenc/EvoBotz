#!/bin/bash

BLUE='\033[0;34m'
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

display_welcome() {
  echo -e "${BLUE}AUTO INSTALLER THEMA – © LEVICODE${NC}"
  sleep 1
  clear
}

install_jq() {
  sudo apt update && sudo apt install -y jq
  clear
}

check_token() {
  echo -e "${YELLOW}MASUKAN AKSES TOKEN :${NC}"
  read -r USER_TOKEN

  if [ "$USER_TOKEN" != "levicode" ]; then
    echo -e "${RED}TOKEN SALAH!${NC}"
    exit 1
  fi

  clear
}

install_theme() {
  clear
  echo -e "${YELLOW}Pilih theme:${NC}"
  echo "1. Stellar"
  echo "2. Billing"
  echo "3. Enigma"
  echo "x. Kembali"
  echo -ne "> "
  read -r SELECT_THEME

  case "$SELECT_THEME" in
    1) THEME_NAME="stellar" ;;
    2) THEME_NAME="billing" ;;
    3) THEME_NAME="enigma" ;;
    x) return ;;
    *) install_theme; return ;;
  esac

  THEME_URL="https://github.com/SkyzoOffc/Pterodactyl-Theme-Autoinstaller/raw/main/${THEME_NAME}.zip"

  wget -q -O "/root/${THEME_NAME}.zip" "$THEME_URL"
  if [ ! -f "/root/${THEME_NAME}.zip" ]; then
    echo -e "${RED}Gagal mengunduh file.${NC}"
    return
  fi

  unzip -oq "/root/${THEME_NAME}.zip" -d /root/pterodactyl

  if [ "$THEME_NAME" = "enigma" ]; then
    echo -ne "Link WhatsApp: "
    read LINK_WA
    echo -ne "Link Group: "
    read LINK_GROUP
    echo -ne "Link Channel: "
    read LINK_CHNL

    sed -i "s|LINK_WA|$LINK_WA|g" /root/pterodactyl/resources/scripts/components/dashboard/DashboardContainer.tsx
    sed -i "s|LINK_GROUP|$LINK_GROUP|g" /root/pterodactyl/resources/scripts/components/dashboard/DashboardContainer.tsx
    sed -i "s|LINK_CHNL|$LINK_CHNL|g" /root/pterodactyl/resources/scripts/components/dashboard/DashboardContainer.tsx
  fi

  sudo cp -rfT /root/pterodactyl /var/www/pterodactyl

  curl -sL https://deb.nodesource.com/setup_16.x | sudo -E bash -
  sudo apt install -y nodejs
  sudo npm install -g yarn

  cd /var/www/pterodactyl || return
  yarn add react-feather
  php artisan migrate
  yarn build:production
  php artisan view:clear

  rm -f "/root/${THEME_NAME}.zip"
  rm -rf /root/pterodactyl

  echo -e "${GREEN}Theme berhasil diinstall.${NC}"
  sleep 1
}

uninstall_theme() {
  bash <(curl -s https://raw.githubusercontent.com/Levvyenc/EvoBotz/refs/heads/main/repair.sh)
  echo -e "${GREEN}Theme berhasil dihapus.${NC}"
  sleep 1
}

display_welcome
install_jq
check_token

while true; do
  clear
  echo "1. Install Theme"
  echo "2. Uninstall Theme"
  echo "x. Exit"
  echo -ne "> "
  read -r MENU

  case "$MENU" in
    1) install_theme ;;
    2) uninstall_theme ;;
    x) exit 0 ;;
    *) ;;
  esac
done