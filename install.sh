#!/bin/bash

installpanel_auto() {
  PANEL_DOMAIN="$1"
  NODE_DOMAIN="$2"
  RAM="$3"

  bash <(curl -s https://pterodactyl-installer.se) <<EOF
y
y
y
y
$PANEL_DOMAIN
admin
admin@$PANEL_DOMAIN
admin
admin
y
EOF

  cd /var/www/pterodactyl || exit 1

  php artisan p:location:make <<EOF
Singapore
Auto Location
EOF

  LOCID=$(php artisan p:location:list | awk 'NR>2 {print $1}' | tail -n1)

  php artisan p:node:make <<EOF
AutoNode
AutoNode
$LOCID
https
$NODE_DOMAIN
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

  NODEID=$(php artisan p:node:list | awk 'NR>2 {print $1}' | tail -n1)

  php artisan p:node:configuration $NODEID > /root/wings.sh
  chmod +x /root/wings.sh
  bash /root/wings.sh

  systemctl enable wings
  systemctl restart wings
}

display_welcome() {
  echo ""
  echo "Auto Installer Theme"
  echo "Dilarang share bebas."
  sleep 2
  clear
}

install_jq() {
  sudo apt update && sudo apt install -y jq curl unzip || exit 1
  clear
}

check_token() {
  echo "Masukkan akses token:"
  read -r USER_TOKEN
  if [ "$USER_TOKEN" != "levicode" ]; then exit 1; fi
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
    *) return ;;
  esac

  wget -q -O "/root/${THEME_NAME}.zip" "https://github.com/SkyzoOffc/Pterodactyl-Theme-Autoinstaller/raw/main/${THEME_NAME}.zip"
  unzip -oq "/root/${THEME_NAME}.zip" -d /root/pterodactyl

  sudo cp -rfT /root/pterodactyl /var/www/pterodactyl

  curl -sL https://deb.nodesource.com/setup_16.x | sudo -E bash -
  sudo apt install -y nodejs
  sudo npm install -g yarn

  cd /var/www/pterodactyl || exit
  yarn add react-feather
  php artisan migrate
  yarn build:production
  php artisan view:clear

  rm -rf /root/pterodactyl /root/${THEME_NAME}.zip
}

uninstall_theme() {
  bash <(curl -s https://raw.githubusercontent.com/Levvyenc/EvoBotz/main/repair.sh)
}

install_themeSteeler() {
  wget -O /root/stellar.zip https://github.com/SkyzoOffc/Pterodactyl-Theme-Autoinstaller/raw/main/stellar.zip
  unzip /root/stellar.zip -d /root/pterodactyl
  sudo cp -rfT /root/pterodactyl /var/www/pterodactyl
}

create_node() {
  read -p "Nama lokasi: " location_name
  read -p "Deskripsi: " location_description
  read -p "Domain: " domain
  read -p "Nama node: " node_name
  read -p "RAM (MB): " ram
  read -p "Disk (MB): " disk_space
  read -p "Loc ID: " locid

  cd /var/www/pterodactyl || exit
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
}

uninstall_panel() {
  bash <(curl -s https://pterodactyl-installer.se) <<EOF
y
y
y
y
EOF
}

configure_wings() {
  read -p "Masukkan token wings: " wings
  eval "$wings"
  systemctl start wings
}

hackback_panel() {
  read -p "Username: " user
  read -p "Password: " pass

  cd /var/www/pterodactyl || exit
  php artisan p:user:make <<EOF
yes
hackback@gmail.com
$user
$user
$user
$pass
EOF
}

ubahpw_vps() {
  read -p "Password baru: " pw
  passwd <<EOF
$pw
$pw
EOF
}

display_welcome
install_jq
check_token

while true; do
  clear
  echo "1. Install theme"
  echo "2. Uninstall theme"
  echo "3. Configure Wings"
  echo "4. Create Node"
  echo "5. Uninstall Panel"
  echo "6. Stellar Theme"
  echo "7. Hack Back Panel"
  echo "8. Ubah Password VPS"
  echo "9. Install Panel + Node (AUTO)"
  echo "x. Exit"
  read -r MENU

  case "$MENU" in
    1) install_theme ;;
    2) uninstall_theme ;;
    3) configure_wings ;;
    4) create_node ;;
    5) uninstall_panel ;;
    6) install_themeSteeler ;;
    7) hackback_panel ;;
    8) ubahpw_vps ;;
    9)
      read -p "Domain Panel: " PD
      read -p "Domain Node: " ND
      read -p "RAM (MB): " RAM
      installpanel_auto "$PD" "$ND" "$RAM"
      ;;
    x) exit ;;
  esac
done
