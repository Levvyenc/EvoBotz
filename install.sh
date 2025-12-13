#!/bin/bash

display_welcome() {
  echo ""
  echo "Auto Installer Theme"
  echo "Dilarang share bebas."
  sleep 2
  clear
}

install_jq() {
  sudo apt update && sudo apt install -y jq || exit 1
  clear
}

check_token() {
  echo "Masukkan akses token:"
  read -r USER_TOKEN

  if [ "$USER_TOKEN" = "levicode" ]; then
    echo "Akses berhasil"
  else
    echo "Token salah!"
    exit 1
  fi
  clear
}

install_theme() {
  clear
  echo "Pilih theme:"
  echo "1. Stellar"
  echo "2. Billing"
  echo "3. Enigma"
  echo "x. Kembali"
  read -r SELECT_THEME

  case "$SELECT_THEME" in
    1) THEME_NAME="stellar" ;;
    2) THEME_NAME="billing" ;;
    3) THEME_NAME="enigma" ;;
    x) return ;;
    *) echo "Pilihan tidak valid."; sleep 1; install_theme; return ;;
  esac

  THEME_URL="https://github.com/SkyzoOffc/Pterodactyl-Theme-Autoinstaller/raw/main/${THEME_NAME}.zip"
  wget -q -O "/root/${THEME_NAME}.zip" "$THEME_URL" || { echo "Gagal mengunduh theme."; return; }

  unzip -oq "/root/${THEME_NAME}.zip" -d /root/pterodactyl

  if [ "$THEME_NAME" == "enigma" ]; then
    read -p "Link WhatsApp: " LINK_WA
    read -p "Link Group: " LINK_GROUP
    read -p "Link Channel: " LINK_CHNL

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

  echo "Install theme selesai."
  sleep 1
  clear
}

uninstall_theme() {
  bash <(curl -s https://raw.githubusercontent.com/Levvyenc/EvoBotz/refs/heads/main/repair.sh)
  echo "Theme berhasil dihapus."
  sleep 1
  clear
}

install_themeSteeler() {
  wget -O /root/stellar.zip https://github.com/SkyzoOffc/Pterodactyl-Theme-Autoinstaller/raw/main/stellar.zip
  unzip /root/stellar.zip -d /root/pterodactyl
  sudo cp -rfT /root/pterodactyl /var/www/pterodactyl

  curl -sL https://deb.nodesource.com/setup_16.x | sudo -E bash -
  sudo apt install -y nodejs
  sudo npm i -g yarn

  cd /var/www/pterodactyl
  yarn add react-feather
  php artisan migrate
  yarn build:production
  php artisan view:clear

  rm /root/stellar.zip
  rm -rf /root/pterodactyl

  echo "Install stellar selesai."
  sleep 1
  clear
}

create_node() {
  read -p "Nama lokasi: " location_name
  read -p "Deskripsi: " location_description
  read -p "Domain: " domain
  read -p "Nama node: " node_name
  read -p "RAM (MB): " ram
  read -p "Disk (MB): " disk_space
  read -p "Loc ID: " locid

  cd /var/www/pterodactyl || exit 1

  php artisan p:location:make <<EOF
$location_name
$location_description
EOF

  php artisan p:node:make <<EOF
$node_name
$location_description
$locid
https
$domain
yes
no
no
$ram
$ram
$disk_space
$disk_space
100
8080
2022
/var/lib/pterodactyl/volumes
EOF

  echo "Node & lokasi selesai dibuat."
  sleep 1
  clear
}

uninstall_panel() {
  bash <(curl -s https://pterodactyl-installer.se) <<EOF
y
y
y
y
EOF
  echo "Panel telah di uninstall."
  sleep 1
  clear
}

configure_wings() {
  read -p "Masukkan token configure wings: " wings
  eval "$wings"
  systemctl start wings
  echo "Wings berhasil dikonfigurasi."
  sleep 1
  clear
}

hackback_panel() {
  read -p "Username baru: " user
  read -p "Password login: " psswdhb

  cd /var/www/pterodactyl || exit 1

  php artisan p:user:make <<EOF
yes
hackback@gmail.com
$user
$user
$user
$psswdhb
EOF

  echo "Akun berhasil ditambahkan."
  sleep 1
}

ubahpw_vps() {
  read -p "Password baru: " pw

passwd <<EOF
$pw
$pw
EOF

  echo "Password VPS berhasil diganti."
  sleep 1
}

display_welcome
install_jq
check_token

while true; do
  clear
  echo "Menu:"
  echo "1. Install theme"
  echo "2. Uninstall theme"
  echo "3. Configure Wings"
  echo "4. Create Node"
  echo "5. Uninstall Panel"
  echo "6. Stellar Theme"
  echo "7. Hack Back Panel"
  echo "8. Ubah Password VPS"
  echo "x. Exit"

  read -r MENU_CHOICE
  clear

  case "$MENU_CHOICE" in
    1) install_theme ;;
    2) uninstall_theme ;;
    3) configure_wings ;;
    4) create_node ;;
    5) uninstall_panel ;;
    6) install_themeSteeler ;;
    7) hackback_panel ;;

    8) ubahpw_vps ;;
    x) exit 0 ;;
    *) echo "Pilihan tidak valid." ;;
  esac
done
