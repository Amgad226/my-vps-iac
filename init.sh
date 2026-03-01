#!/bin/bash

set -e

if [ "$EUID" -ne 0 ]; then
  echo "❌ This script must be run as root. Please use sudo."
  exit 1
fi

echo "🚀 Starting VPS setup..."

# Load external scripts
source ./install/git.sh
source ./install/docker.sh
source ./install/tree.sh
source ./login/ghcr.sh
source ./firewall/ufw.sh

# Call functions
install_git
install_docker
install_tree

login_to_ghcr

bash ./login/ghcr.sh

open_port_if_needed 80
sudo bash ./projects/portfolio/run_portfolio.sh

open_port_if_needed 3000
sudo bash ./projects/tracking-gps-server/run_gps.sh

open_port_if_needed 51821 tcp
open_port_if_needed 51820 udp
sudo bash ./projects/wg-easy/run_wg.sh


open_port_if_needed 5000
sudo bash ./projects/image-compressor/run_image_compressor.sh

echo "🎉 VPS setup complete!"