#!/usr/bin/env bash

# =========================
# Secrets Validation Script
# =========================

SECRETS_FOLDER="$HOME/secrets"

# List of required files
REQUIRED_FILES=(
  "PAT_SECRET"
  "source-safe.env"
)

validate_secrets() {
  echo "🔍 Checking secrets folder: $SECRETS_FOLDER"

  # check folder exists
  if [ ! -d "$SECRETS_FOLDER" ]; then
    echo "❌ Secrets folder not found"
    exit 1
  fi

  local missing=0

  for file in "${REQUIRED_FILES[@]}"; do
    if [ -f "$SECRETS_FOLDER/$file" ]; then
      echo "✔ $file exists"
    else
      echo "✖ $file missing"
      missing=1
    fi
  done

  if [ "$missing" -eq 1 ]; then
    echo "❌ One or more required secret files are missing"
    exit 1
  fi

  echo "✅ All required secret files are present"
}

