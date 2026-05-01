#!/bin/bash

# =========================
# Secrets Validation Script
# =========================


validate_sqllite_databases() {
  SQLITE_DATABASES_FOLDER="$(eval echo ~${SUDO_USER:-$USER})/sqlite-databases"
REQUIRED_FILES=(
  "gps.db"
)

  echo "🔍 Checking sql databases folder: $SQLITE_DATABASES_FOLDER"

  # check folder exists
  if [ ! -d "$SQLITE_DATABASES_FOLDER" ]; then
    echo "❌ Sql databases folder not found"
    exit 1
  fi

  local missing=0

  for file in "${REQUIRED_FILES[@]}"; do
    if [ -f "$SQLITE_DATABASES_FOLDER/$file" ]; then
      echo "✔ $file exists"
    else
      echo "✖ $file missing"
      missing=1
    fi
  done

  if [ "$missing" -eq 1 ]; then
    echo "❌ One or more required database files are missing"
    exit 1
  fi

  echo "✅ All required database files are present"
}

