#!/bin/bash
set -e
# -------------------------------
# Determine script directory
# -------------------------------
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
PROJECT_ROOT="$SCRIPT_DIR"

# -------------------------------
# Check for docker-compose.yml
# -------------------------------
COMPOSE_FILE="$PROJECT_ROOT/docker-compose.yml"

if [ ! -f "$COMPOSE_FILE" ]; then
    echo "❌ docker-compose.yml not found at $COMPOSE_FILE"
    exit 1
fi

# -------------------------------
# Copy env file from secrets
# -------------------------------
REAL_USER="${SUDO_USER:-$USER}"
if [ "$REAL_USER" = "root" ]; then
  REAL_USER="admin"
fi
SECRETS_FOLDER="/home/$REAL_USER/secrets"

if [ -f "$SECRETS_FOLDER/portfolio.env" ]; then
    cp "$SECRETS_FOLDER/portfolio.env" "$PROJECT_ROOT/.env"
    echo "✅ Copied $SECRETS_FOLDER/portfolio.env to $PROJECT_ROOT/.env"
else
    echo "❌ No env file found at $SECRETS_FOLDER/portfolio.env"
    exit 1
fi

# The database lives outside this repository. Keep the project path as a
# symlink so image pulls and IaC updates can never replace production data.
DATABASE_FILE="$PROJECT_ROOT/database.sqlite"
if [ ! -L "$DATABASE_FILE" ]; then
    echo "❌ $DATABASE_FILE must be a symlink to the external portfolio SQLite database"
    exit 1
fi
if [ ! -f "$DATABASE_FILE" ]; then
    echo "❌ Portfolio database symlink is broken: $DATABASE_FILE -> $(readlink "$DATABASE_FILE")"
    exit 1
fi
echo "✅ Using external portfolio database: $(readlink -f "$DATABASE_FILE")"

# -------------------------------
# Run Docker Compose
# -------------------------------
if [ "${SKIP_PULL:-false}" = "true" ]; then
    echo "🚀 Starting containers without pulling..."
else
    echo "🚀 Pulling images and starting containers..."
    docker compose -f "$COMPOSE_FILE" pull
fi
docker compose -f "$COMPOSE_FILE" up -d

# The Nginx configuration is bind-mounted, so an existing container does not
# restart merely because the file changed. Validate and reload it explicitly to
# apply proxy/header fixes on every deployment.
echo "🔎 Validating and reloading the portfolio Nginx configuration..."
docker compose -f "$COMPOSE_FILE" exec -T nginx nginx -t
docker compose -f "$COMPOSE_FILE" exec -T nginx nginx -s reload

echo "✅ Laravel portfolio is running!"
