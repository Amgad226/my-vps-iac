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

if [ -f "$SECRETS_FOLDER/map-trips.env" ]; then
    cp "$SECRETS_FOLDER/map-trips.env" "$PROJECT_ROOT/.env"
    echo "✅ Copied $SECRETS_FOLDER/map-trips.env to $PROJECT_ROOT/.env"
else
    echo "❌ No env file found at $SECRETS_FOLDER/map-trips.env, skipping copy"
fi

# -------------------------------
# Run Docker Compose
# -------------------------------
if [ "${SKIP_PULL:-false}" = "true" ]; then
    echo "🚀 Starting containers without pulling..."
else
    echo "🚀 Pulling images and starting containers..."
    docker compose -f "$COMPOSE_FILE" pull
fi
docker compose -f "$COMPOSE_FILE" up -d

echo "✅ map-trips is running!"