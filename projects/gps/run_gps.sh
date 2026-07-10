#!/bin/bash
set -e

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
PROJECT_ROOT="$SCRIPT_DIR"

# -------------------------------
# Secrets folder resolution
# -------------------------------
REAL_USER="${SUDO_USER:-$USER}"
if [ "$REAL_USER" = "root" ]; then
  REAL_USER="admin"
fi
SECRETS_FOLDER="/home/$REAL_USER/secrets"

copy_env() {
    local secret_name="$1"
    local target_dir="$2"

    if [ -f "$SECRETS_FOLDER/$secret_name.env" ]; then
        cp "$SECRETS_FOLDER/$secret_name.env" "$target_dir/.env"
        echo "✅ Copied $SECRETS_FOLDER/$secret_name.env to $target_dir/.env"
    else
        echo "❌ No env file found at $SECRETS_FOLDER/$secret_name.env, skipping copy"
    fi
}

# -------------------------------
# GPS Backend
# -------------------------------
BACKEND_COMPOSE_FILE="$PROJECT_ROOT/backend/docker-compose.yml"

if [ ! -f "$BACKEND_COMPOSE_FILE" ]; then
    echo "❌ docker-compose.yml not found at $BACKEND_COMPOSE_FILE"
    exit 1
fi

copy_env "gps-backend" "$PROJECT_ROOT/backend"

echo "🚀 Pulling images and starting GPS backend..."
docker compose -f "$BACKEND_COMPOSE_FILE" pull
docker compose -f "$BACKEND_COMPOSE_FILE" up -d

echo "✅ GPS backend is running!"

# -------------------------------
# GPS Dashboard
# -------------------------------
DASHBOARD_COMPOSE_FILE="$PROJECT_ROOT/dashboard/docker-compose.yml"

if [ ! -f "$DASHBOARD_COMPOSE_FILE" ]; then
    echo "❌ docker-compose.yml not found at $DASHBOARD_COMPOSE_FILE"
    exit 1
fi

copy_env "gps-dashboard" "$PROJECT_ROOT/dashboard"

echo "🚀 Pulling images and starting GPS dashboard..."
docker compose -f "$DASHBOARD_COMPOSE_FILE" pull
docker compose -f "$DASHBOARD_COMPOSE_FILE" up -d

echo "✅ GPS dashboard is running!"
