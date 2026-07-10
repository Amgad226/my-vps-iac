#!/bin/bash
set -e

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
PROJECT_ROOT="$SCRIPT_DIR"

# -------------------------------
# Secrets folder resolution
# -------------------------------
REAL_USER="${SUDO_USER:-$USER}"
if [ "$REAL_USER" = "root" ]; then
  REAL_USER="admin"
fi
SECRETS_FOLDER="/home/$REAL_USER/secrets"

copy_env() {
    local secret_name="$1"
    local target_dir="$2"

    if [ -f "$SECRETS_FOLDER/$secret_name.env" ]; then
        cp "$SECRETS_FOLDER/$secret_name.env" "$target_dir/.env"
        echo "✅ Copied $SECRETS_FOLDER/$secret_name.env to $target_dir/.env"
    else
        echo "❌ No env file found at $SECRETS_FOLDER/$secret_name.env, skipping copy"
    fi
}

# -------------------------------
# York V1 (Laravel)
# -------------------------------
YORK_COMPOSE_FILE="$PROJECT_ROOT/docker/york_v1/docker-compose.yml"
chmod +x "$PROJECT_ROOT/docker/york_v1/docker-entrypoint.sh"

if [ ! -f "$YORK_COMPOSE_FILE" ]; then
    echo "❌ docker-compose.yml not found at $YORK_COMPOSE_FILE"
    exit 1
fi

copy_env "york-v1" "$PROJECT_ROOT/docker/york_v1"

echo "🚀 Pulling images and starting containers..."
docker compose -f "$YORK_COMPOSE_FILE" pull
docker compose -f "$YORK_COMPOSE_FILE" up -d

echo "✅ york v1 laravel is running!"

# -------------------------------
# York Nest (streaming backend)
# -------------------------------
NEST_COMPOSE_FILE="$PROJECT_ROOT/docker/nest/docker-compose.yml"

if [ ! -f "$NEST_COMPOSE_FILE" ]; then
    echo "❌ docker-compose.yml not found at $NEST_COMPOSE_FILE"
    exit 1
fi

copy_env "york-nest" "$PROJECT_ROOT/docker/nest"

echo "🚀 Pulling images and starting containers..."
docker compose -f "$NEST_COMPOSE_FILE" pull
docker compose -f "$NEST_COMPOSE_FILE" up -d

echo "✅ york nest is running!"

# -------------------------------
# York Certificate
# -------------------------------
CERTIFICATE_COMPOSE_FILE="$PROJECT_ROOT/docker/certificate/docker-compose.yml"

if [ ! -f "$CERTIFICATE_COMPOSE_FILE" ]; then
    echo "❌ docker-compose.yml not found at $CERTIFICATE_COMPOSE_FILE"
    exit 1
fi

copy_env "york-certificate" "$PROJECT_ROOT/docker/certificate"

echo "🚀 Pulling images and starting containers..."
docker compose -f "$CERTIFICATE_COMPOSE_FILE" pull
docker compose -f "$CERTIFICATE_COMPOSE_FILE" up -d

echo "✅ york certificate is running!"

# -------------------------------
# York Next (frontend)
# -------------------------------
NEXT_COMPOSE_FILE="$PROJECT_ROOT/docker/next/docker-compose.yml"

if [ ! -f "$NEXT_COMPOSE_FILE" ]; then
    echo "❌ docker-compose.yml not found at $NEXT_COMPOSE_FILE"
    exit 1
fi

copy_env "york-next" "$PROJECT_ROOT/docker/next"

echo "🚀 Pulling images and starting containers..."
docker compose -f "$NEXT_COMPOSE_FILE" pull
docker compose -f "$NEXT_COMPOSE_FILE" up -d

echo "✅ york next is running!"

# -------------------------------
# York Gateway
# -------------------------------
GATEWAY_COMPOSE_FILE="$PROJECT_ROOT/docker/gateway/docker-compose.yml"

if [ ! -f "$GATEWAY_COMPOSE_FILE" ]; then
    echo "❌ docker-compose.yml not found at $GATEWAY_COMPOSE_FILE"
    exit 1
fi

echo "🚀 Pulling images and starting containers..."
docker compose -f "$GATEWAY_COMPOSE_FILE" pull
docker compose -f "$GATEWAY_COMPOSE_FILE" up -d

echo "✅ york gateway is running!"
