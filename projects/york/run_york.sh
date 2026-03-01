#!/bin/bash
set -e

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
PROJECT_ROOT="$SCRIPT_DIR"     


YORK_COMPOSE_FILE="$PROJECT_ROOT/docker/york_v1/docker-compose.yml"

if [ ! -f "$YORK_COMPOSE_FILE" ]; then
    echo "❌ docker-compose.yml not found at $YORK_COMPOSE_FILE"
    exit 1
fi

echo "🚀 Pulling images and starting containers..."
docker compose -f "$YORK_COMPOSE_FILE" pull
docker compose -f "$YORK_COMPOSE_FILE" up -d

echo "✅ york v1 laravel is running!"


NEST_COMPOSE_FILE="$PROJECT_ROOT/docker/nest/docker-compose.yml"

if [ ! -f "$NEST_COMPOSE_FILE" ]; then
    echo "❌ docker-compose.yml not found at $NEST_COMPOSE_FILE"
    exit 1
fi


echo "🚀 Pulling images and starting containers..."
docker compose -f "$NEST_COMPOSE_FILE" pull
docker compose -f "$NEST_COMPOSE_FILE" up -d

echo "✅ york nest is running!"


CERTIFICATE_COMPOSE_FILE="$PROJECT_ROOT/docker/certificate/docker-compose.yml"

if [ ! -f "$CERTIFICATE_COMPOSE_FILE" ]; then
    echo "❌ docker-compose.yml not found at $CERTIFICATE_COMPOSE_FILE"
    exit 1
fi


echo "🚀 Pulling images and starting containers..."
docker compose -f "$CERTIFICATE_COMPOSE_FILE" pull
docker compose -f "$CERTIFICATE_COMPOSE_FILE" up -d

echo "✅ york certificate is running!"




NEXT_COMPOSE_FILE="$PROJECT_ROOT/docker/next/docker-compose.yml"

if [ ! -f "$NEXT_COMPOSE_FILE" ]; then
    echo "❌ docker-compose.yml not found at $NEXT_COMPOSE_FILE"
    exit 1
fi


echo "🚀 Pulling images and starting containers..."
docker compose -f "$NEXT_COMPOSE_FILE" pull
docker compose -f "$NEXT_COMPOSE_FILE" up -d

echo "✅ york next is running!"
