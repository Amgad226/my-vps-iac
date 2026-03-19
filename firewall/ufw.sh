#!/bin/bash

# Function to allow a port in iptables if it's not already allowed
# Usage: open_port_if_needed <port> <protocol>
# Protocol can be "tcp" or "udp" (default: tcp)
open_port_if_needed() {
    local PORT=$1
    local PROTOCOL=${2:-tcp}  # Default to tcp if not provided

    if [ -z "$PORT" ]; then
        echo "Usage: open_port_if_needed <port> [tcp|udp]"
        return 1
    fi

    if [[ "$PROTOCOL" != "tcp" && "$PROTOCOL" != "udp" ]]; then
        echo "Invalid protocol: $PROTOCOL. Use 'tcp' or 'udp'."
        return 1
    fi

    # Check if rule already exists
    if sudo iptables -C INPUT -p "$PROTOCOL" --dport "$PORT" -j ACCEPT &>/dev/null; then
        echo "Port $PORT/$PROTOCOL already allowed."
    else
        echo "Allowing port $PORT/$PROTOCOL..."
        sudo iptables -I INPUT -p "$PROTOCOL" --dport "$PORT" -j ACCEPT
    fi
}

setup_firewall_strict() {
    echo "🔒 Setting up STRICT iptables firewall..."

    # Flush existing rules
    sudo iptables -F
    sudo iptables -t nat -F
    sudo iptables -t mangle -F
    sudo iptables -X

    # Default policies
    sudo iptables -P INPUT DROP
    sudo iptables -P FORWARD DROP
    sudo iptables -P OUTPUT ACCEPT

    # Allow loopback
    sudo iptables -A INPUT -i lo -j ACCEPT

    # Allow established connections
    sudo iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

    # Allow SSH
    sudo iptables -A INPUT -p tcp --dport 22 -j ACCEPT

    # Allow Docker-exposed ports manually via a whitelist
    ALLOWED_PORTS=(80 3000 51821 51820 5000 3011 3005 3020 3007 8080 5001)

    for PORT in "${ALLOWED_PORTS[@]}"; do
        sudo iptables -A INPUT -p tcp --dport $PORT -j ACCEPT
        sudo iptables -A INPUT -p udp --dport $PORT -j ACCEPT
    done

    # Enforce Docker container ports via DOCKER-USER
    sudo iptables -F DOCKER-USER || true
    sudo iptables -I DOCKER-USER -j DROP
    for PORT in "${ALLOWED_PORTS[@]}"; do
        sudo iptables -I DOCKER-USER -p tcp --dport $PORT -j ACCEPT
        sudo iptables -I DOCKER-USER -p udp --dport $PORT -j ACCEPT
    done
    # Always allow localhost inside DOCKER-USER
    sudo iptables -I DOCKER-USER -s 127.0.0.1 -j ACCEPT

    # Save rules to persist after reboot
    sudo iptables-save | sudo tee /etc/iptables/rules.v4 >/dev/null

    echo "✅ Firewall setup complete. Only allowed ports are accessible."
}