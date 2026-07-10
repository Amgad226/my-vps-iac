#!/bin/bash

login_to_gitlab() {
  # -------------------------------
  # Variables
  # -------------------------------
  GITLAB_USERNAME="${GITLAB_USERNAME:-Amgad226}"

  TOKEN_FILE="/home/admin/secrets/GITLAB_TOKEN"
  if [ ! -f "$TOKEN_FILE" ]; then
    echo "❌ GitLab token file not found at $TOKEN_FILE"
    exit 1
  fi

  GITLAB_TOKEN=$(cat "$TOKEN_FILE")
  REGISTRY="registry.gitlab.com"

  if command -v docker &> /dev/null; then
    echo "🚀 Logging in to GitLab Container Registry..."
    echo "$GITLAB_TOKEN" | docker login $REGISTRY -u "$GITLAB_USERNAME" --password-stdin
    echo "✅ Logged in to $REGISTRY successfully"
  else
    echo "❌ Docker not installed. Please install Docker first."
    exit 1
  fi
}
