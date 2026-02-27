#!/bin/bash

install_docker() {
  if command -v docker &> /dev/null
  then
    echo "✅ Docker already installed"
  else
    echo "🚀 Installing Docker..."

    # Install dependencies
    apt update -y
    apt install -y ca-certificates curl gnupg lsb-release

    # Add Docker GPG key and repository
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
      | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg

    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
      https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
      | tee /etc/apt/sources.list.d/docker.list > /dev/null

    # Install Docker packages
    apt update -y
    apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

    # Enable and start Docker service
    systemctl enable docker
    systemctl start docker

    echo "✅ Docker installed"
  fi

  # -----------------------------
  # Add current user to docker group
  # -----------------------------
  if groups $SUDO_USER | grep &>/dev/null "\bdocker\b"; then
    echo "✅ User '$SUDO_USER' already in docker group"
  else
    echo "🚀 Adding user '$SUDO_USER' to docker group..."
    usermod -aG docker $SUDO_USER
    echo "✅ User '$SUDO_USER' added to docker group"
    echo "⚠ You need to log out and log back in for this to take effect, or run: newgrp docker"
  fi
}