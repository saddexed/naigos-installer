#!/bin/bash

# Exit immediately if a command fails
set -e

# === Configuration ===
REPO_URL="https://github.com/saddexed/Weather-App.git"
APP_DIR="/var/www/weather-app"
NGINX_SITE="/etc/nginx/sites-available/weatherapp"

echo "=== Installing Nginx and Git ==="
apt update -y
apt install -y nginx git

echo "=== Cloning GitHub repository ==="
if [ -d "$APP_DIR" ]; then
    echo "Directory $APP_DIR already exists. Pulling latest changes..."
    cd "$APP_DIR"
    git pull
else
    git clone "$REPO_URL" "$APP_DIR"
fi

echo "=== Setting permissions ==="
chown -R www-data:www-data "$APP_DIR"
chmod -R 755 "$APP_DIR"

echo "=== Configuring Nginx ==="
cat > "$NGINX_SITE" <<EOF
server {
    listen 80;
    server_name _;
    root /var/www/weather-app;
    index index.html;

    location / {
        try_files \$uri \$uri/ =404;
    }
}
EOF

echo "=== Enabling Nginx site ==="
ln -sf "$NGINX_SITE" /etc/nginx/sites-enabled/weatherapp
rm -f /etc/nginx/sites-enabled/default

echo "=== Testing Nginx configuration ==="
nginx -t

echo "=== Reloading Nginx ==="
systemctl reload nginx

echo "=== Installation complete! ==="
echo "Your weather app is deployed at: http://<your-server-ip>/"
