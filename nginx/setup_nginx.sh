#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

PROJECTS_FILE="$SCRIPT_DIR/config/projects.env"
WEB_SRC_DIR="$SCRIPT_DIR/web"
WEB_ROOT="/var/www/vps-projects"

NGINX_CONF="/etc/nginx/sites-available/vps-projects"
NGINX_LINK="/etc/nginx/sites-enabled/vps-projects"
NGINX_DEFAULT_LINK="/etc/nginx/sites-enabled/default"

echo "🚀 Setting up Nginx reverse proxy..."

if [ "${EUID:-0}" -eq 0 ]; then
  SUDO=""
else
  SUDO="sudo"
fi

if [ ! -f "$PROJECTS_FILE" ]; then
  echo "❌ Projects file not found: $PROJECTS_FILE"
  exit 1
fi

if [ ! -d "$WEB_SRC_DIR" ]; then
  echo "❌ Web directory not found: $WEB_SRC_DIR"
  exit 1
fi

echo "📦 Syncing dashboard files..."
$SUDO mkdir -p "$WEB_ROOT"
$SUDO cp -a "$WEB_SRC_DIR/." "$WEB_ROOT/"

OUT_CONF="$SCRIPT_DIR/projects.conf"
TMP_CONF="$(mktemp)"

cat > "$TMP_CONF" <<EOF
server {
    listen 80;
    server_name _;

    root $WEB_ROOT;
    index index.html;

    location = / {
        try_files /index.html =404;
    }

    location / {
        try_files \$uri \$uri/ =404;
    }

EOF

while IFS="|" read -r name path port; do
  name="${name#"${name%%[![:space:]]*}"}"
  name="${name%"${name##*[![:space:]]}"}"
  path="${path#"${path%%[![:space:]]*}"}"
  path="${path%"${path##*[![:space:]]}"}"
  port="${port#"${port%%[![:space:]]*}"}"
  port="${port%"${port##*[![:space:]]}"}"

  if [ -z "$name" ] || [[ "$name" == \#* ]]; then
    continue
  fi

  if [ -z "$path" ] || [ -z "$port" ]; then
    echo "⚠️  Skipping invalid line: name='$name' path='$path' port='$port'"
    continue
  fi

  if [[ "$path" != /* ]]; then
    echo "⚠️  Skipping invalid path (must start with '/'): $path"
    continue
  fi

  echo "📦 Adding $name → $path → $port"

  cat >> "$TMP_CONF" <<EOF
    location = $path {
        return 301 $path/;
    }

    location ^~ $path/ {
        rewrite ^$path/?(.*)$ /\$1 break;

        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header X-Forwarded-Prefix $path;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";

        proxy_pass http://127.0.0.1:$port;
    }

EOF

done < "$PROJECTS_FILE"

echo "}" >> "$TMP_CONF"

mv "$TMP_CONF" "$OUT_CONF"
chmod 0644 "$OUT_CONF"

echo "📄 Moving config to Nginx..."

$SUDO cp "$OUT_CONF" "$NGINX_CONF"

if [ ! -L "$NGINX_LINK" ]; then
  $SUDO ln -s "$NGINX_CONF" "$NGINX_LINK"
fi

if [ -e "$NGINX_DEFAULT_LINK" ]; then
  echo "🧹 Disabling default Nginx site..."
  $SUDO mv "$NGINX_DEFAULT_LINK" "${NGINX_DEFAULT_LINK}.disabled" || true
fi

echo "🔍 Testing Nginx config..."
$SUDO nginx -t

echo "♻️ Restarting Nginx..."
$SUDO systemctl restart nginx

echo "✅ Nginx setup complete!"
