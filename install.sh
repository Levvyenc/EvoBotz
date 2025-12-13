#!/bin/bash

set -e
PANEL_PATH="/var/www/pterodactyl"

# ===============================
# AUTO MODE (KHUSUS BOT)
# ===============================
if [[ "$1" == "auto" ]]; then
  DOMAIN_NODE="$2"
  RAM="$3"

  cd $PANEL_PATH || exit 1

  echo "STEP|CREATE_LOCATION"
  php artisan p:location:make --no-interaction <<EOF
Singapore
Auto Node
EOF

  LOCID=$(php artisan p:location:list | awk 'NR>2 {print $1}' | tail -n 1)
  NODE_NAME="Node-$(date +%s)"

  echo "STEP|CREATE_NODE"
  php artisan p:node:make --no-interaction <<EOF
$NODE_NAME
Auto Node
$LOCID
$DOMAIN_NODE
https
no
no
no
$RAM
0
$RAM
0
100
8080
2022
/var/lib/pterodactyl/volumes
EOF

  systemctl enable --now wings || true

  echo "NODE_OK|$NODE_NAME|$DOMAIN_NODE|$RAM"
  exit 0
fi

# ===============================
# MODE MANUAL 
# ===============================

display_welcome() {
  echo ""
  echo "Auto Installer Theme"
  echo "Dilarang share bebas."
  sleep 2
  clear
}

install_jq() {
  apt update && apt install -y jq unzip curl
  clear
}

check_token() {
  read -p "Masukkan akses token: " USER_TOKEN
  [[ "$USER_TOKEN" != "levicode" ]] && exit 1
  clear
}

install_theme() {
  clear
  echo "1. Stellar"
  echo "2. Billing"
  echo "3. Enigma"
  read -p "Pilih: " SELECT_THEME

  case "$SELECT_THEME" in
    1) THEME_NAME="stellar" ;;
    2) THEME_NAME="billing" ;;
    3) THEME_NAME="enigma" ;;
    *) return ;;
  esac

  wget -O /root/theme.zip \
  https://github.com/SkyzoOffc/Pterodactyl-Theme-Autoinstaller/raw/main/${THEME_NAME}.zip

  unzip -oq /root/theme.zip -d /root/pterodactyl
  cp -rfT /root/pterodactyl $PANEL_PATH

  curl -sL https://deb.nodesource.com/setup_16.x | bash -
  apt install -y nodejs
  npm i -g yarn

  cd $PANEL_PATH
  yarn add react-feather
  yarn build:production
  php artisan view:clear

  rm -rf /root/theme.zip /root/pterodactyl
}

create_node() {
  read -p "Domain node: " DOMAIN
  read -p "RAM (MB): " RAM
  bash $0 auto "$DOMAIN" "$RAM"
}

configure_wings() {
  read -p "Paste command configure wings: " CMD
  bash -c "$CMD"
  systemctl enable --now wings
}

hackback_panel() {
  read -p "Username baru: " USER
  read -p "Password: " PASS

  EMAIL="hb_$(date +%s)@gmail.com"

  cd $PANEL_PATH
  php artisan p:user:make <<EOF
yes
$EMAIL
$USER
$USER
$USER
$PASS
EOF
}

ubahpw_vps() {
  read -p "Password baru: " PW
  passwd <<EOF
$PW
$PW
EOF
}

uninstall_panel() {
  bash <(curl -s https://pterodactyl-installer.se)
}

display_welcome
install_jq
check_token

while true; do
  clear
  echo "1. Install Theme"
  echo "2. Create Node"
  echo "3. Configure Wings"
  echo "4. Hack Back Panel"
  echo "5. Ubah Password VPS"
  echo "6. Uninstall Panel"
  echo "x. Exit"
  read -p "Pilih: " MENU

  case "$MENU" in
    1) install_theme ;;
    2) create_node ;;
    3) configure_wings ;;
    4) hackback_panel ;;
    5) ubahpw_vps ;;
    6) uninstall_panel ;;
    x) exit ;;
  esac
done
