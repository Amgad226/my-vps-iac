#!/bin/bash


open_port_if_needed() {
    local PORT=$1
    local PROTOCOL=${2:-tcp}

    if [ -z "$PORT" ]; then
        echo "Usage: open_port_if_needed <port> [tcp|udp]"
        return 1
    fi

    if ufw status | grep -q "$PORT/$PROTOCOL"; then
        echo "Port $PORT/$PROTOCOL already allowed."
    else
        echo "Allowing port $PORT/$PROTOCOL..."
        sudo ufw allow $PORT/$PROTOCOL
    fi
}

setup_firewall_strict() {
    echo "🔒 Setting up STRICT UFW firewall..."

    # Reset UFW completely
    sudo ufw --force reset

    # Default policies
    sudo ufw default deny incoming
    sudo ufw default allow outgoing

    # Allow SSH (VERY IMPORTANT)
    sudo ufw allow 22/tcp

    # Enable UFW
    sudo ufw --force enable

    echo "✅ UFW strict mode enabled. All ports closed except SSH."
}