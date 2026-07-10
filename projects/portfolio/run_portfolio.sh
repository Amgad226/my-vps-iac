#!/bin/bash
set -e
# -------------------------------
# Determine script directory
# -------------------------------
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
PROJECT_ROOT="$SCRIPT_DIR"

# -------------------------------
# Check for docker-compose.yml
# -------------------------------
COMPOSE_FILE="$PROJECT_ROOT/docker-compose.yml"

if [ ! -f "$COMPOSE_FILE" ]; then
    echo "❌ docker-compose.yml not found at $COMPOSE_FILE"
    exit 1
fi

# -------------------------------
# Copy env file from secrets
# -------------------------------
REAL_USER="${SUDO_USER:-$USER}"
if [ "$REAL_USER" = "root" ]; then
  REAL_USER="admin"
fi
SECRETS_FOLDER="/home/$REAL_USER/secrets"

if [ -f "$SECRETS_FOLDER/portfolio.env" ]; then
    cp "$SECRETS_FOLDER/portfolio.env" "$PROJECT_ROOT/.env"
    echo "✅ Copied $SECRETS_FOLDER/portfolio.env to $PROJECT_ROOT/.env"
else
    echo "❌ No env file found at $SECRETS_FOLDER/portfolio.env, skipping copy"
fi

chmod 777 "$PROJECT_ROOT/start.sh"
# -------------------------------
# Run Docker Compose
# -------------------------------
echo "🚀 Pulling images and starting containers..."
docker compose -f "$COMPOSE_FILE" pull
docker compose -f "$COMPOSE_FILE" up -d

echo "✅ Laravel portfolio is running!"