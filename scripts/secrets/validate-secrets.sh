#!/bin/bash

# =========================
# Secrets Validation Script
# =========================



validate_secrets() {
  SECRETS_FOLDER="$(eval echo ~${SUDO_USER:-$USER})/secrets"
REQUIRED_FILES=(
  "PAT_SECRET"
  "source-safe.env"
)
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

