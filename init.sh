#!/bin/bash

set -e

if [ "$EUID" -ne 0 ]; then
  echo "❌ This script must be run as root. Please use sudo."
  exit 1
fi

echo "🚀 Starting VPS setup..."

# ---------- Service registry ----------
# Format: key|Display Name|run_script_relative_path
declare -a SERVICES=(
  "portfolio|Portfolio|projects/portfolio/run_portfolio.sh"
  "gps|GPS project (backend + dashboard)|projects/gps/run_gps.sh"
  "wg|WireGuard (wg-easy)|projects/wg-easy/run_wg.sh"
  "image|Image Compressor|projects/image-compressor/run_image_compressor.sh"
  "york|York Project|projects/york/run_york.sh"
  "source_safe|Source Safe|projects/source-safe/run_source_safe.sh"
  "map_trips|Map Trips|projects/map-trips/run_map_trips.sh"
  "nginx|Nginx setup|nginx/setup_nginx.sh"
)

# ---------- Store decisions ----------
RUN_PORTFOLIO=false
RUN_GPS=false
RUN_WG=false
RUN_IMAGE=false
RUN_YORK=false
RUN_SOURCE_SAFE=false
RUN_NGINX=false
RUN_MAP_TRIPS=false

# ---------- Menu helpers ----------
show_main_menu() {
  echo ""
  echo "🧠 What do you want to do?"
  echo ""
  echo "  1) Run / update ALL services"
  echo "  2) Update specific services (pull new images + restart selected)"
  echo "  3) Run specific services only (start selected without pulling)"
  echo ""
}

show_service_menu() {
  local mode="$1"
  echo ""
  if [ "$mode" = "update" ]; then
    echo "📦 Select services to UPDATE (comma or space separated numbers, e.g. 1,3,5):"
  else
    echo "🚀 Select services to RUN (comma or space separated numbers, e.g. 1,3,5):"
  fi
  echo ""
  local i=1
  for svc in "${SERVICES[@]}"; do
    local name
    name=$(echo "$svc" | cut -d'|' -f2)
    echo "  $i) $name"
    ((i++))
  done
  echo ""
}

parse_selection() {
  local input="$1"
  # Normalize separators: comma/space -> newline
  echo "$input" | tr ', ' '\n' | grep -E '^[0-9]+$' | sort -u
}

set_service_flag() {
  local key="$1"
  case "$key" in
    portfolio)   RUN_PORTFOLIO=true ;;
    gps)         RUN_GPS=true ;;
    wg)          RUN_WG=true ;;
    image)       RUN_IMAGE=true ;;
    york)        RUN_YORK=true ;;
    source_safe) RUN_SOURCE_SAFE=true ;;
    map_trips)   RUN_MAP_TRIPS=true ;;
    nginx)       RUN_NGINX=true ;;
  esac
}

# ---------- Interactive phase ----------
echo ""
echo "🧠 Configuration phase"
echo ""

show_main_menu
read -p "Enter choice [1-3]: " MAIN_CHOICE

case "$MAIN_CHOICE" in
  1)
    echo "✅ All services selected."
    RUN_PORTFOLIO=true
    RUN_GPS=true
    RUN_WG=true
    RUN_IMAGE=true
    RUN_YORK=true
    RUN_SOURCE_SAFE=true
    RUN_NGINX=true
    RUN_MAP_TRIPS=true
    ;;
  2)
    show_service_menu "update"
    read -p "Enter numbers: " SERVICE_CHOICE
    while IFS= read -r num; do
      [ -z "$num" ] && continue
      idx=$((num - 1))
      if [ "$idx" -ge 0 ] && [ "$idx" -lt "${#SERVICES[@]}" ]; then
        key=$(echo "${SERVICES[$idx]}" | cut -d'|' -f1)
        set_service_flag "$key"
      else
        echo "⚠️  Ignoring invalid choice: $num"
      fi
    done < <(parse_selection "$SERVICE_CHOICE")
    export SKIP_PULL=false
    ;;
  3)
    show_service_menu "run"
    read -p "Enter numbers: " SERVICE_CHOICE
    while IFS= read -r num; do
      [ -z "$num" ] && continue
      idx=$((num - 1))
      if [ "$idx" -ge 0 ] && [ "$idx" -lt "${#SERVICES[@]}" ]; then
        key=$(echo "${SERVICES[$idx]}" | cut -d'|' -f1)
        set_service_flag "$key"
      else
        echo "⚠️  Ignoring invalid choice: $num"
      fi
    done < <(parse_selection "$SERVICE_CHOICE")
    export SKIP_PULL=true
    ;;
  *)
    echo "❌ Invalid choice. Exiting."
    exit 1
    ;;
esac

echo ""
echo "⚙️ Installing base system..."
echo ""

# ---------- Base setup ----------
source ./scripts/secrets/validate-secrets.sh
source ./scripts/secrets/validate-sqllite-databases.sh
validate_secrets
validate_sqllite_databases
source ./install/git.sh
source ./install/docker.sh
source ./install/tree.sh
source ./install/nginx.sh
source ./install/certbot.sh
source ./login/ghcr.sh
source ./login/gitlab.sh
source ./firewall/ufw.sh

setup_firewall_strict

install_git
install_docker
install_tree
install_nginx
install_certbot
login_to_ghcr
login_to_gitlab

bash ./login/ghcr.sh

# ---------- Execution phase ----------
echo ""
echo "🚀 Running selected projects..."
echo ""

open_port_if_needed 80
open_port_if_needed 443

if $RUN_PORTFOLIO; then
  echo "➡️ Running Portfolio"
  bash ./projects/portfolio/run_portfolio.sh
fi

if $RUN_GPS; then
  echo "➡️ Running GPS project"
  open_port_if_needed 9100
  open_port_if_needed 3100
  open_port_if_needed 5220
  bash ./projects/gps/run_gps.sh
fi

if $RUN_WG; then
  echo "➡️ Running WireGuard"
  open_port_if_needed 51821 tcp
  open_port_if_needed 51820 udp
  bash ./projects/wg-easy/run_wg.sh
fi

if $RUN_IMAGE; then
  echo "➡️ Running Image Compressor"
  open_port_if_needed 5000
  bash ./projects/image-compressor/run_image_compressor.sh
fi

if $RUN_YORK; then
  echo "➡️ Running York"
  open_port_if_needed 3011
  open_port_if_needed 3005
  open_port_if_needed 3020
  open_port_if_needed 3007
  open_port_if_needed 8080
  bash ./projects/york/run_york.sh
fi

if $RUN_SOURCE_SAFE; then
  echo "➡️ Running Source Safe"
  open_port_if_needed 5001
  bash ./projects/source-safe/run_source_safe.sh
fi

if $RUN_MAP_TRIPS; then
  echo "➡️ Running Map Trips"
  open_port_if_needed 3001
  bash ./projects/map-trips/run_map_trips.sh
fi

if $RUN_NGINX; then
  echo "➡️ Setting up Nginx"
  bash ./nginx/setup_nginx.sh
fi

echo ""
echo "🎉 VPS setup complete!"
