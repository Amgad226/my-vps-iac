#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

PROJECTS_FILE="$SCRIPT_DIR/config/projects.env"

NGINX_CONF="/etc/nginx/sites-available/vps-projects"
NGINX_LINK="/etc/nginx/sites-enabled/vps-projects"

echo "🚀 Generating Nginx reverse proxy config for Next.js apps..."

# Detect sudo
if [ "${EUID:-0}" -eq 0 ]; then
  SUDO=""
else
  SUDO="sudo"
fi

# Check config file
if [ ! -f "$PROJECTS_FILE" ]; then
  echo "❌ Projects file not found: $PROJECTS_FILE"
  exit 1
fi

TMP_CONF="$(mktemp)"

cat > "$TMP_CONF" <<'EOF'
server {
    listen 80 default_server;
    listen [::]:80 default_server;

    server_name _;

    # IMPORTANT: no static root fallback
    # Next.js apps handle everything via proxy

EOF

HAS_APPS=0

while IFS="|" read -r name path port; do

  # trim spaces
  name="$(echo "$name" | xargs)"
  path="$(echo "$path" | xargs)"
  port="$(echo "$port" | xargs)"

  # skip comments/empty
  if [ -z "$name" ] || [[ "$name" == \#* ]]; then
    continue
  fi

  if [ -z "$path" ] || [ -z "$port" ]; then
    echo "⚠️ Skipping invalid line: $name | $path | $port"
    continue
  fi

  if [[ "$path" != /* ]]; then
    echo "⚠️ Invalid path (must start with /): $path"
    continue
  fi

  echo "📦 Adding $name → $path → $port"
  HAS_APPS=1

  # remove trailing slash for safety
  CLEAN_PATH="${path%/}"

  cat >> "$TMP_CONF" <<EOF

    # -------------------------
    # $name ($CLEAN_PATH)
    # -------------------------

    location = $CLEAN_PATH {
        return 301 $CLEAN_PATH/;
    }

    location ^~ $CLEAN_PATH/ {

        proxy_pass http://127.0.0.1:$port;

        proxy_http_version 1.1;

        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header X-Forwarded-Prefix $CLEAN_PATH;

        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";

        proxy_redirect off;
    }

EOF

done < "$PROJECTS_FILE"

if [ "$HAS_APPS" -eq 0 ]; then
  echo "❌ No valid apps found in projects file"
  exit 1
fi

cat >> "$TMP_CONF" <<'EOF'
}
EOF

echo "📄 Installing Nginx config..."

$SUDO mv "$TMP_CONF" "$NGINX_CONF"
$SUDO chmod 644 "$NGINX_CONF"

# enable site
if [ -L "$NGINX_LINK" ]; then
  $SUDO rm -f "$NGINX_LINK"
fi

$SUDO ln -s "$NGINX_CONF" "$NGINX_LINK"

echo "🔍 Testing Nginx config..."

$SUDO nginx -t || {
  echo "❌ nginx config test failed"
  exit 1
}

echo "♻️ Restarting Nginx..."
$SUDO systemctl restart nginx

echo "✅ Done! Nginx is now proxying multiple Next.js apps safely."