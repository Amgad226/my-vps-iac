#!/bin/bash

# -------------------------------
# Check for root / sudo
# -------------------------------
if [ "$EUID" -ne 0 ]; then
  echo "❌ This script must be run as root. Re-running with sudo..."
  exec sudo "$0" "$@"
fi

# -------------------------------
# Paths
# -------------------------------
COMPOSE_FILE="./docker-compose.yml"   # Make sure this file exists in your IaC repo

# -------------------------------
# Pull latest images and run
# -------------------------------
if [ -f "$COMPOSE_FILE" ]; then
    echo "🚀 Pulling latest images and starting containers..."
    docker-compose -f $COMPOSE_FILE pull
    docker-compose -f $COMPOSE_FILE up -d
    echo "✅ Containers are running!"
else
    echo "❌ docker-compose.yml not found at $COMPOSE_FILE"
    exit 1
fi