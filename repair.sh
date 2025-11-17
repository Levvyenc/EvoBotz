#!/bin/bash

if (( EUID != 0 )); then
    echo "Silahkan masuk sebagai root"
    exit
fi

repairPanel() {
    cd /var/www/pterodactyl || exit

    php artisan down

    rm -rf /var/www/pterodactyl/resources

    curl -L https://github.com/pterodactyl/panel/releases/latest/download/panel.tar.gz | tar -xz

    chmod -R 755 storage/* bootstrap/cache

    composer install --no-dev --optimize-autoloader

    php artisan view:clear
    php artisan config:clear
    php artisan migrate --seed --force

    chown -R www-data:www-data /var/www/pterodactyl/*

    php artisan queue:restart
    php artisan up
}

while true; do
    read -p "Apakah kamu yakin ingin menghapus theme? (y/n): " yn
    case $yn in
        [Yy]* ) repairPanel; break ;;
        [Nn]* ) exit ;;
        * ) echo "Pilih y/n." ;;
    esac
done