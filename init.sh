#!/bin/bash

set -e

echo "🚀 Starting VPS setup..."

# Load external scripts
source ./install/git.sh
source ./install/docker.sh

# Call functions
install_git
install_docker

echo "🎉 VPS setup complete!"