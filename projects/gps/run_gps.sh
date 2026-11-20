#!/bin/bash
set -Eeuo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
PROJECT_ROOT="$SCRIPT_DIR"
BACKEND_DIR="$PROJECT_ROOT/backend"
BACKEND_COMPOSE_FILE="$BACKEND_DIR/docker-compose.yml"
LEGACY_COMPOSE_FILE="$BACKEND_DIR/docker-compose.legacy.yml"
BACKEND_IMAGE="registry.gitlab.com/amgad226/gps-backend/backend:main"

REAL_USER="${SUDO_USER:-$USER}"
if [ "$REAL_USER" = "root" ]; then
  REAL_USER="admin"
fi

SECRETS_FOLDER="/home/$REAL_USER/secrets"
BACKUP_ROOT="/home/$REAL_USER/backups/gps"
ROLLBACK_STATE_FILE="$BACKUP_ROOT/latest-rollback.env"
COMMAND="${1:-deploy}"
ROLLBACK_AVAILABLE=false
BACKEND_RUNTIME_SERVICES=(
  api
  realtime
  device-gateway
  telemetry-worker
  command-worker
  notification-worker
  history-worker
  scheduler-worker
  messaging-gateway
  demo-simulator
  edge
)

backend_compose() {
  docker compose --project-directory "$BACKEND_DIR" -f "$BACKEND_COMPOSE_FILE" "$@"
}

legacy_compose() {
  docker compose --project-directory "$BACKEND_DIR" -f "$LEGACY_COMPOSE_FILE" "$@"
}

container_exists() {
  docker inspect "$1" >/dev/null 2>&1
}

container_running() {
  [ "$(docker inspect --format '{{.State.Running}}' "$1" 2>/dev/null || true)" = "true" ]
}

copy_env() {
  local secret_name="$1"
  local target_dir="$2"
  local source_file="$SECRETS_FOLDER/$secret_name.env"

  if [ ! -f "$source_file" ]; then
    echo "❌ Required env file not found: $source_file"
    return 1
  fi

  cp "$source_file" "$target_dir/.env"
  chmod 600 "$target_dir/.env"
  echo "✅ Installed $secret_name.env"
}

prepare_backend_env() {
  copy_env "gps-backend" "$BACKEND_DIR"
}

preflight_backend() {
  [ -f "$BACKEND_COMPOSE_FILE" ] || {
    echo "❌ Compose file not found: $BACKEND_COMPOSE_FILE"
    return 1
  }
  [ -f "$LEGACY_COMPOSE_FILE" ] || {
    echo "❌ Legacy rollback compose file not found: $LEGACY_COMPOSE_FILE"
    return 1
  }
  docker info >/dev/null
  backend_compose config --quiet

  local available_kb
  available_kb=$(df -Pk "$PROJECT_ROOT" | awk 'NR == 2 { print $4 }')
  if [ "$available_kb" -lt 5242880 ]; then
    echo "❌ At least 5 GB of free disk space is required"
    return 1
  fi
}

wait_for_health() {
  local container="$1"
  local timeout_seconds="${2:-180}"
  local deadline=$((SECONDS + timeout_seconds))

  while [ "$SECONDS" -lt "$deadline" ]; do
    local state
    state=$(docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' "$container" 2>/dev/null || true)
    case "$state" in
      healthy)
        return 0
        ;;
      unhealthy|dead|exited)
        echo "❌ $container entered state: $state"
        return 1
        ;;
    esac
    sleep 3
  done

  echo "❌ Timed out waiting for $container"
  return 1
}

wait_for_running() {
  local container="$1"
  local timeout_seconds="${2:-120}"
  local deadline=$((SECONDS + timeout_seconds))

  while [ "$SECONDS" -lt "$deadline" ]; do
    if container_running "$container"; then
      return 0
    fi
    sleep 3
  done

  echo "❌ Timed out waiting for $container to run"
  return 1
}

create_runtime_backup() {
  local timestamp
  timestamp=$(date -u +%Y%m%dT%H%M%SZ)
  local backup_dir="$BACKUP_ROOT/$timestamp"
  mkdir -p "$backup_dir"
  chmod 700 "$BACKUP_ROOT" "$backup_dir"

  docker ps -a --format '{{.Names}}|{{.Image}}|{{.Status}}' > "$backup_dir/containers.txt"

  if container_running gps-postgres; then
    echo "📦 Creating PostgreSQL backup..."
    docker exec gps-postgres sh -c 'pg_dump -U "$POSTGRES_USER" -d "$POSTGRES_DB" -Fc' > "$backup_dir/postgres.dump"
    test -s "$backup_dir/postgres.dump"
    docker exec -i gps-postgres pg_restore --list < "$backup_dir/postgres.dump" >/dev/null
  fi

  if container_running gps-redis; then
    echo "📦 Creating Redis snapshot..."
    docker exec gps-redis redis-cli BGSAVE >/dev/null
    local deadline=$((SECONDS + 120))
    while [ "$SECONDS" -lt "$deadline" ]; do
      if docker exec gps-redis redis-cli INFO persistence | tr -d '\r' | grep -q '^rdb_bgsave_in_progress:0$'; then
        break
      fi
      sleep 2
    done
    docker exec gps-redis redis-cli INFO persistence | tr -d '\r' | grep -q '^rdb_bgsave_in_progress:0$'
    docker exec gps-redis redis-cli INFO persistence | tr -d '\r' | grep -q '^rdb_last_bgsave_status:ok$'
    docker cp gps-redis:/data/dump.rdb "$backup_dir/redis.rdb" >/dev/null
    test -s "$backup_dir/redis.rdb"
  fi

  echo "✅ Runtime backup created at $backup_dir"
}

save_rollback_image() {
  local source_container=""
  local rollback_mode=""

  if container_exists gps-api; then
    source_container="gps-api"
    rollback_mode="split"
  elif container_exists gps-backend; then
    source_container="gps-backend"
    rollback_mode="legacy"
  else
    echo "ℹ️ No previous backend image found; rollback image was not created"
    return 0
  fi

  local image_id
  image_id=$(docker inspect --format '{{.Image}}' "$source_container")
  local rollback_image="gps-backend-rollback:$(date -u +%Y%m%dT%H%M%SZ)"
  docker image tag "$image_id" "$rollback_image"

  mkdir -p "$BACKUP_ROOT"
  chmod 700 "$BACKUP_ROOT"
  {
    printf 'ROLLBACK_IMAGE=%s\n' "$rollback_image"
    printf 'ROLLBACK_MODE=%s\n' "$rollback_mode"
  } > "$ROLLBACK_STATE_FILE"
  chmod 600 "$ROLLBACK_STATE_FILE"
  ROLLBACK_AVAILABLE=true
  echo "✅ Saved rollback image: $rollback_image ($rollback_mode)"
}

run_bootstrap() {
  backend_compose rm -sf bootstrap >/dev/null 2>&1 || true
  backend_compose up --no-deps --abort-on-container-exit --exit-code-from bootstrap bootstrap
}

verify_split_backend() {
  local healthy_containers=(
    gps-postgres
    gps-redis
    gps-api
    gps-realtime
    gps-device-gateway
    gps-telemetry-worker
    gps-command-worker
    gps-notification-worker
    gps-history-worker
    gps-scheduler-worker
    gps-messaging-gateway
    gps-edge
  )

  local container
  for container in "${healthy_containers[@]}"; do
    wait_for_health "$container" 240 || return 1
  done
  wait_for_running gps-demo-simulator 120 || return 1
  curl --fail --silent --show-error --max-time 10 http://127.0.0.1:3100/health >/dev/null || return 1
}

remove_public_api_firewall_rule() {
  if ! command -v ufw >/dev/null 2>&1; then
    return 0
  fi
  if ! sudo -n true >/dev/null 2>&1; then
    echo "⚠️ Could not remove the old UFW 3100 rule without sudo; remove it manually"
    return 0
  fi
  if sudo -n ufw status | grep -qE '^3100/tcp'; then
    sudo -n ufw --force delete allow 3100/tcp >/dev/null || true
    echo "✅ Removed the obsolete public UFW rule for port 3100"
  fi
}

deploy_backend_release() {
  if [ "${SKIP_PULL:-false}" != "true" ]; then
    echo "🚀 Pulling GPS backend images..."
    backend_compose pull || return 1
  else
    echo "🚀 Using locally cached GPS backend images..."
  fi

  if container_running gps-backend; then
    echo "⏸ Stopping the legacy monolith..."
    docker stop gps-backend >/dev/null || return 1
  fi

  backend_compose up -d postgres redis || return 1
  wait_for_health gps-postgres 180 || return 1
  wait_for_health gps-redis 180 || return 1
  run_bootstrap || return 1
  backend_compose up -d "${BACKEND_RUNTIME_SERVICES[@]}" || return 1
  verify_split_backend || return 1

  backend_compose up -d --remove-orphans "${BACKEND_RUNTIME_SERVICES[@]}" || return 1
  if container_exists gps-mqtt-broker; then
    docker rm -f gps-mqtt-broker >/dev/null || return 1
  fi
  remove_public_api_firewall_rule
}

rollback_backend() {
  if [ ! -f "$ROLLBACK_STATE_FILE" ]; then
    echo "❌ No rollback state found at $ROLLBACK_STATE_FILE"
    return 1
  fi

  local rollback_image
  local rollback_mode
  rollback_image=$(sed -n 's/^ROLLBACK_IMAGE=//p' "$ROLLBACK_STATE_FILE")
  rollback_mode=$(sed -n 's/^ROLLBACK_MODE=//p' "$ROLLBACK_STATE_FILE")

  if [ -z "$rollback_image" ] || ! docker image inspect "$rollback_image" >/dev/null 2>&1; then
    echo "❌ Rollback image is missing: $rollback_image"
    return 1
  fi

  echo "↩️ Restoring $rollback_image in $rollback_mode mode..."
  docker image tag "$rollback_image" "$BACKEND_IMAGE"
  backend_compose down || true

  if [ "$rollback_mode" = "legacy" ]; then
    legacy_compose up -d || return 1
    wait_for_running gps-backend 180 || return 1
    curl --fail --silent --show-error --max-time 10 http://127.0.0.1:3100/health >/dev/null || return 1
  elif [ "$rollback_mode" = "split" ]; then
    backend_compose up -d postgres redis || return 1
    wait_for_health gps-postgres 180 || return 1
    wait_for_health gps-redis 180 || return 1
    run_bootstrap || return 1
    backend_compose up -d "${BACKEND_RUNTIME_SERVICES[@]}" || return 1
    verify_split_backend || return 1
  else
    echo "❌ Unknown rollback mode: $rollback_mode"
    return 1
  fi

  echo "✅ GPS backend rollback completed"
}

deploy_backend() {
  prepare_backend_env
  preflight_backend
  create_runtime_backup
  save_rollback_image

  if ! deploy_backend_release; then
    echo "❌ GPS backend deployment failed; starting automatic rollback"
    if [ "$ROLLBACK_AVAILABLE" = "true" ]; then
      rollback_backend || echo "❌ Automatic rollback failed; manual intervention is required"
    else
      echo "❌ No rollback image was available; manual intervention is required"
    fi
    return 1
  fi

  echo "✅ GPS split backend is healthy"
}

deploy_component() {
  local name="$1"
  local directory="$2"
  local secret_name="${3:-}"
  local compose_file="$directory/docker-compose.yml"

  [ -f "$compose_file" ] || {
    echo "❌ Compose file not found: $compose_file"
    return 1
  }
  if [ -n "$secret_name" ]; then
    copy_env "$secret_name" "$directory"
  fi
  if [ "${SKIP_PULL:-false}" != "true" ]; then
    docker compose -f "$compose_file" pull
  fi
  docker compose -f "$compose_file" up -d
  echo "✅ $name is running"
}

deploy_all() {
  deploy_backend
  deploy_component "GPS dashboard" "$PROJECT_ROOT/dashboard" "gps-dashboard"
  deploy_component "GPS mobile" "$PROJECT_ROOT/mobile"
  deploy_component "GPS landing page" "$PROJECT_ROOT/landing-page"
}

show_status() {
  echo "== GPS backend =="
  backend_compose ps -a
  echo "== GPS dashboard =="
  docker compose -f "$PROJECT_ROOT/dashboard/docker-compose.yml" ps -a
  echo "== GPS mobile =="
  docker compose -f "$PROJECT_ROOT/mobile/docker-compose.yml" ps -a
  echo "== GPS landing page =="
  docker compose -f "$PROJECT_ROOT/landing-page/docker-compose.yml" ps -a
}

show_logs() {
  shift || true
  if [ "$#" -gt 0 ]; then
    backend_compose logs --tail=200 -f "$@"
  else
    backend_compose logs --tail=200 -f
  fi
}

cleanup_mqtt() {
  if container_exists gps-mqtt-broker; then
    docker rm -f gps-mqtt-broker >/dev/null
  fi
  local volume
  for volume in backend_emqx_data backend_emqx_log; do
    if docker volume inspect "$volume" >/dev/null 2>&1; then
      docker volume rm "$volume"
    fi
  done
  echo "✅ MQTT container and persistent volumes were removed"
}

case "$COMMAND" in
  deploy)
    deploy_all
    ;;
  status)
    show_status
    ;;
  logs)
    show_logs "$@"
    ;;
  rollback)
    prepare_backend_env
    rollback_backend
    ;;
  cleanup-mqtt)
    cleanup_mqtt
    ;;
  *)
    echo "Usage: $0 {deploy|status|logs [service...]|rollback|cleanup-mqtt}"
    exit 2
    ;;
esac
