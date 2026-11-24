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
DATABASE_DIRECTORY="/home/$REAL_USER/sqlite-databases/portfolio"
EXTERNAL_DATABASE_FILE="$DATABASE_DIRECTORY/database.sqlite"
DATABASE_MIGRATED=false

mkdir -p "$DATABASE_DIRECTORY"

if [ -L "$DATABASE_FILE" ]; then
    if [ ! -f "$DATABASE_FILE" ]; then
        echo "❌ Portfolio database symlink is broken: $DATABASE_FILE -> $(readlink "$DATABASE_FILE")"
        exit 1
    fi
elif [ -f "$DATABASE_FILE" ]; then
    if [ -e "$EXTERNAL_DATABASE_FILE" ]; then
        echo "❌ Both an in-project and external portfolio database exist. Refusing to overwrite either file:"
        echo "   Project:  $DATABASE_FILE"
        echo "   External: $EXTERNAL_DATABASE_FILE"
        exit 1
    fi

    echo "📦 Migrating the existing portfolio database outside the IaC repository..."
    docker compose -f "$COMPOSE_FILE" stop laravel >/dev/null 2>&1 || true

    cp --preserve=all "$DATABASE_FILE" "$EXTERNAL_DATABASE_FILE"
    if ! cmp -s "$DATABASE_FILE" "$EXTERNAL_DATABASE_FILE"; then
        echo "❌ Database copy verification failed; the original project file was not changed"
        exit 1
    fi

    DATABASE_BACKUP="$DATABASE_DIRECTORY/database.sqlite.pre-external-migration.$(date +%Y%m%d_%H%M%S).bak"
    mv "$DATABASE_FILE" "$DATABASE_BACKUP"
    ln -s "$EXTERNAL_DATABASE_FILE" "$DATABASE_FILE"
    DATABASE_MIGRATED=true
    echo "✅ Database migrated to $EXTERNAL_DATABASE_FILE"
    echo "✅ Verified migration backup kept at $DATABASE_BACKUP"
elif [ -e "$DATABASE_FILE" ]; then
    echo "❌ $DATABASE_FILE exists but is not a regular file or symlink"
    exit 1
else
    if [ -f "$EXTERNAL_DATABASE_FILE" ]; then
        echo "📦 Linking the existing external portfolio database..."
    elif [ -e "$EXTERNAL_DATABASE_FILE" ]; then
        echo "❌ $EXTERNAL_DATABASE_FILE exists but is not a regular file"
        exit 1
    else
        echo "📦 Creating the external portfolio database..."
        touch "$EXTERNAL_DATABASE_FILE"
    fi
    ln -s "$EXTERNAL_DATABASE_FILE" "$DATABASE_FILE"
    DATABASE_MIGRATED=true
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
if [ "$DATABASE_MIGRATED" = "true" ]; then
    # Recreate the containers once so Docker resolves the newly-created source
    # symlink rather than retaining the old bind mount.
    docker compose -f "$COMPOSE_FILE" up -d --force-recreate
else
    docker compose -f "$COMPOSE_FILE" up -d
fi

# The Nginx configuration is bind-mounted, so an existing container does not
# restart merely because the file changed. Validate and reload it explicitly to
# apply proxy/header fixes on every deployment.
echo "🔎 Validating and reloading the portfolio Nginx configuration..."
docker compose -f "$COMPOSE_FILE" exec -T nginx nginx -t
docker compose -f "$COMPOSE_FILE" exec -T nginx nginx -s reload

echo "✅ Laravel portfolio is running!"
