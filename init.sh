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

# Call functions
install_git
install_docker
install_tree

# sudo bash ./login/ghcr.sh
sudo bash ./projects/portfolio/run_portfolio.sh

echo "🎉 VPS setup complete!"