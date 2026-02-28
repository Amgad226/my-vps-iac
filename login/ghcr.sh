#!/bin/bash

login_to_ghcr() {
  # -------------------------------
# Variables
# -------------------------------
GHCR_USERNAME="Amgad226"          # GitHub username
# GHCR_TOKEN="${GHCR_TOKEN}"        # Export this on VPS beforehand
# FIXME
TOKEN_FILE="/home/admin/secrets/PAT_SECRET"
if [ ! -f "$TOKEN_FILE" ]; then
    echo "❌ PAT token file not found at $TOKEN_FILE"
    exit 1
fi

# Read token
GHCR_TOKEN=$(cat "$TOKEN_FILE")

  if command -v docker &> /dev/null; then
    echo "🚀 Logging in to GitHub Container Registry..."
    echo "$GHCR_TOKEN" | docker login $REGISTRY -u "$GHCR_USERNAME" --password-stdin
    echo "✅ Logged in to $REGISTRY successfully"
  else
    echo "❌ Docker not installed. Please install Docker first."
    exit 1
  fi
}
