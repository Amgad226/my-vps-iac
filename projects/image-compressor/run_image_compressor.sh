#!/bin/bash
set -e
# -------------------------------
# Determine script directory
# -------------------------------
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
PROJECT_ROOT="$SCRIPT_DIR"        # if docker-compose.yml is in same folder
ENVS_DIR="$SCRIPT_DIR/../../envs" # adjust relative to script location

# -------------------------------
# Check for docker-compose.yml
# -------------------------------
COMPOSE_FILE="$PROJECT_ROOT/docker-compose.yml"

if [ ! -f "$COMPOSE_FILE" ]; then
    echo "❌ docker-compose.yml not found at $COMPOSE_FILE"
    exit 1
fi

# -------------------------------
# Copy env file
# -------------------------------
if [ -f "$ENVS_DIR/image_compressor.env" ]; then
    cp "$ENVS_DIR/image_compressor.env" "./.env"
    echo "✅ envs/image_compressor.env to ./.env"
else
    echo "⚠ No env file found at $ENVS_DIR, skipping copy"
fi


# -------------------------------
# Run Docker Compose
# -------------------------------
echo "🚀 Pulling images and starting containers..."
docker compose -f "$COMPOSE_FILE" pull
docker compose -f "$COMPOSE_FILE" up -d

echo "✅ image_compressor is running!"