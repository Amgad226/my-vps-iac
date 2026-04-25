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

echo ""
echo "🧠 Configuration phase (answer all questions first)"
echo ""

ask "Run Portfolio?" && RUN_PORTFOLIO=true
ask "Run Tracking GPS Server?" && RUN_GPS=true
ask "Run WireGuard (wg-easy)?" && RUN_WG=true
ask "Run Image Compressor?" && RUN_IMAGE=true
ask "Run York Project?" && RUN_YORK=true
ask "Run Source Safe?" && RUN_SOURCE_SAFE=true
ask "Setup Nginx?" && RUN_NGINX=true

echo ""
echo "⚙️ Installing base system..."
echo ""

# ---------- Base setup ----------
source ./scripts/secrets/validate-secrets.sh
validate_secrets

source ./install/git.sh
source ./install/docker.sh
source ./install/tree.sh
source ./install/nginx.sh
source ./login/ghcr.sh
source ./firewall/ufw.sh

setup_firewall_strict

install_git
install_docker
install_tree
install_nginx
login_to_ghcr

bash ./login/ghcr.sh

# ---------- Execution phase ----------
echo ""
echo "🚀 Running selected projects..."
echo ""

if $RUN_PORTFOLIO; then
  echo "➡️ Running Portfolio"
  open_port_if_needed 80
  bash ./projects/portfolio/run_portfolio.sh
fi

if $RUN_GPS; then
  echo "➡️ Running GPS Server"
  open_port_if_needed 3000
  bash ./projects/tracking-gps-server/run_gps.sh
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

if $RUN_NGINX; then
  echo "➡️ Setting up Nginx"
  bash ./nginx/setup_nginx.sh
fi

echo ""
echo "🎉 VPS setup complete!"