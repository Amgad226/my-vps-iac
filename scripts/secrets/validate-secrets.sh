#!/bin/bash

# =========================
# Secrets Validation Script
# =========================



validate_secrets() {
  REAL_USER="${SUDO_USER:-$USER}"
  if [ "$REAL_USER" = "root" ]; then
    REAL_USER="admin"
  fi
  SECRETS_FOLDER="/home/$REAL_USER/secrets"
REQUIRED_FILES=(
  "PAT_SECRET"
  "source-safe.env"
  "map-trips.env"
  "portfolio.env"
  "image-compressor.env"
  "wg.env"
  "york-certificate.env"
  "york-nest.env"
  "york-next.env"
  "york-staging-nest.env"
  "york-v1.env"
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

