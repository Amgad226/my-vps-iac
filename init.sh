#!/bin/bash

set -e

if [ "$EUID" -ne 0 ]; then
  echo "❌ This script must be run as root. Please use sudo."
  exit 1
fi

echo "🚀 Starting VPS setup..."

# ---------- Helper ----------
ask() {
  local prompt="$1"
  local answer

  read -p "$prompt [Y/n]: " answer

  # Default = YES if empty (just Enter)
  if [[ -z "$answer" || "$answer" =~ ^[Yy]$ ]]; then
    return 0
  else
    return 1
  fi
}

# ---------- Store decisions ----------
RUN_PORTFOLIO=false
RUN_GPS=false
RUN_WG=false
RUN_IMAGE=false
RUN_YORK=false
RUN_SOURCE_SAFE=false
RUN_NGINX=false
RUN_MAP_TRIPS=false

echo ""
echo "🧠 Configuration phase (answer all questions first)"
echo ""

# New global question
if ask "Run ALL services?"; then
    RUN_PORTFOLIO=true
    RUN_GPS=true
    RUN_WG=true
    RUN_IMAGE=true
    RUN_YORK=true
    RUN_SOURCE_SAFE=true
    RUN_NGINX=true
    RUN_MAP_TRIPS=true
else
    ask "Run Portfolio?" && RUN_PORTFOLIO=true
    ask "Run GPS project (backend + dashboard)?" && RUN_GPS=true
    ask "Run WireGuard (wg-easy)?" && RUN_WG=true
    ask "Run Image Compressor?" && RUN_IMAGE=true
    ask "Run York Project?" && RUN_YORK=true
    ask "Run Source Safe?" && RUN_SOURCE_SAFE=true
    ask "Run Map Trips?" && RUN_MAP_TRIPS=true
    ask "Setup Nginx?" && RUN_NGINX=true
fi
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
  open_port_if_needed 1883
  open_port_if_needed 8883
  open_port_if_needed 8083
  open_port_if_needed 8084
  open_port_if_needed 18083
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