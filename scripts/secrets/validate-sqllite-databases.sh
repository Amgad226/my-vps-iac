#!/bin/bash

# =========================
# Sqlite Databases Validation Script
# =========================


validate_sqllite_databases() {
  REAL_USER="${SUDO_USER:-$USER}"
  if [ "$REAL_USER" = "root" ]; then
    REAL_USER="admin"
  fi
  SQLITE_DATABASES_FOLDER="/home/$REAL_USER/sqlite-databases"
REQUIRED_FILES=(
  "map-trips/file.db"
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
      chmod -R 777 "$SQLITE_DATABASES_FOLDER/$file"
      echo "✔ $file exists and permissions set to 777"
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

