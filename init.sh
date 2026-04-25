#!/bin/bash

set -e

if [ "$EUID" -ne 0 ]; then
  echo "❌ This script must be run as root. Please use sudo."
  exit 1
fi

echo "🚀 Starting VPS setup..."

# ---------- Helpers ----------
ask_to_run() {
  local name=$1
  while true; do
    read -p "👉 Do you want to run $name? (y/n): " choice
    case "$choice" in
      y|Y ) return 0 ;;
      n|N ) return 1 ;;
      * ) echo "Please answer y or n." ;;
    esac
  done
}

# ---------- Secrets ----------
source ./scripts/secrets/validate-secrets.sh
validate_secrets

# ---------- Installations ----------
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

# ---------- Projects ----------

if ask_to_run "Portfolio"; then
  open_port_if_needed 80
  bash ./projects/portfolio/run_portfolio.sh
fi

if ask_to_run "Tracking GPS Server"; then
  open_port_if_needed 3000
  bash ./projects/tracking-gps-server/run_gps.sh
fi

if ask_to_run "WireGuard (wg-easy)"; then
  open_port_if_needed 51821 tcp
  open_port_if_needed 51820 udp
  bash ./projects/wg-easy/run_wg.sh
fi

if ask_to_run "Image Compressor"; then
  open_port_if_needed 5000
  bash ./projects/image-compressor/run_image_compressor.sh
fi

if ask_to_run "York Project"; then
  open_port_if_needed 3011
  open_port_if_needed 3005
  open_port_if_needed 3020
  open_port_if_needed 3007
  open_port_if_needed 8080
  bash ./projects/york/run_york.sh
fi

if ask_to_run "Source Safe"; then
  open_port_if_needed 5001
  bash ./projects/source-safe/run_source_safe.sh
fi

# ---------- Nginx ----------
if ask_to_run "Setup Nginx"; then
  bash ./nginx/setup_nginx.sh
fi

echo "🎉 VPS setup complete!"