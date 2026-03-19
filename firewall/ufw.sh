#!/bin/bash

# Function to open a port via nftables if it is not already allowed
# Only ports you explicitly open here will be accessible
open_port_if_needed() {
    local PORT=$1
    local PROTOCOL=${2:-tcp}  # Default protocol is TCP

    if [ -z "$PORT" ]; then
        echo "Usage: open_port_if_needed <port> [tcp|udp]"
        return 1
    fi

    if [[ "$PROTOCOL" != "tcp" && "$PROTOCOL" != "udp" ]]; then
        echo "Invalid protocol: $PROTOCOL. Use 'tcp' or 'udp'."
        return 1
    fi

    # Check if rule already exists
    if sudo nft list ruleset | grep -q "dport $PORT $PROTOCOL accept"; then
        echo "Port $PORT/$PROTOCOL already allowed."
    else
        echo "Allowing port $PORT/$PROTOCOL..."
        sudo nft add rule inet filter input $PROTOCOL dport $PORT accept
        sudo nft insert rule inet filter docker-user $PROTOCOL dport $PORT accept
    fi
}

setup_firewall_strict() {
    echo "🔒 Setting up STRICT nftables firewall..."

    # Flush existing ruleset
    sudo nft flush ruleset

    # Create inet table
    sudo nft add table inet filter

    # Create input, forward, output chains
    sudo nft add chain inet filter input  { type filter hook input priority 0 \; policy drop \; }
    sudo nft add chain inet filter forward { type filter hook forward priority 0 \; policy drop \; }
    sudo nft add chain inet filter output  { type filter hook output priority 0 \; policy accept \; }

    # Allow loopback interface
    sudo nft add rule inet filter input iif "lo" accept

    # Allow established/related connections
    sudo nft add rule inet filter input ct state established,related accept

    # Allow SSH (port 22)
    sudo nft add rule inet filter input tcp dport 22 accept

    # Create docker-user chain to block all Docker-exposed ports
    sudo nft add chain inet filter docker-user { type filter hook prerouting priority -100 \; policy accept \; }

    # Drop everything in docker-user by default
    sudo nft add rule inet filter docker-user drop

    # Always allow localhost traffic in docker-user
    sudo nft insert rule inet filter docker-user ip saddr 127.0.0.1 accept

    # Save rules so they persist across reboot
    sudo nft list ruleset | sudo tee /etc/nftables.conf >/dev/null
    sudo systemctl enable nftables
    sudo systemctl restart nftables

    echo "✅ Strict firewall setup complete. Only SSH is open, Docker cannot expose ports."
}
