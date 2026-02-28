#!/bin/bash

login_to_ghcr() {
  # -------------------------------
# Variables
# -------------------------------
GHCR_USERNAME="Amgad226"          # GitHub username
GHCR_TOKEN="${GHCR_TOKEN}"        # Export this on VPS beforehand
REGISTRY="ghcr.io"

  if command -v docker &> /dev/null; then
    echo "🚀 Logging in to GitHub Container Registry..."
    echo "$GHCR_TOKEN" | docker login $REGISTRY -u "$GHCR_USERNAME" --password-stdin
    echo "✅ Logged in to $REGISTRY successfully"
  else
    echo "❌ Docker not installed. Please install Docker first."
    exit 1
  fi
}
