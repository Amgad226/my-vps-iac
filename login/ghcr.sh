#!/bin/bash

# -------------------------------
# Check for root / sudo
# -------------------------------
if [ "$EUID" -ne 0 ]; then
  echo "❌ This script must be run as root. Re-running with sudo..."
  exec sudo "$0" "$@"
fi

# -------------------------------
# Variables
# -------------------------------
GHCR_USERNAME="Amgad226"          # GitHub username
GHCR_TOKEN="${GHCR_TOKEN}"        # Export this on VPS beforehand
REGISTRY="ghcr.io"

# -------------------------------
# Login to GitHub Container Registry
# -------------------------------
if docker info &>/dev/null; then
    echo "🚀 Logging in to GitHub Container Registry..."
    echo "$GHCR_TOKEN" | docker login $REGISTRY -u "$GHCR_USERNAME" --password-stdin
    echo "✅ Logged in to $REGISTRY successfully"
else
    echo "❌ Docker not installed. Please install Docker first."
    exit 1
fi