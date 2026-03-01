#!/bin/bash

# Function to open a port in UFW if it's not already allowed
# Usage: open_port_if_needed <port> <protocol>
# Protocol can be "tcp" or "udp" (default: tcp)
open_port_if_needed() {
    local PORT=$1
    local PROTOCOL=${2:-tcp}  # Default to tcp if not provided

    # Validate input
    if [ -z "$PORT" ]; then
        echo "Usage: open_port_if_needed <port> [tcp|udp]"
        return 1
    fi

    if [[ "$PROTOCOL" != "tcp" && "$PROTOCOL" != "udp" ]]; then
        echo "Invalid protocol: $PROTOCOL. Use 'tcp' or 'udp'."
        return 1
    fi

    # Check if UFW is active
    if ! sudo ufw status | grep -q "Status: active"; then
        echo "UFW is inactive. Enabling UFW..."
        sudo ufw allow ssh          # Keep SSH open
        sudo ufw enable
    fi

    # Check if the port/protocol is already allowed
    if sudo ufw status | grep -q "${PORT}/${PROTOCOL}"; then
        echo "Port ${PORT}/${PROTOCOL} is already allowed."
    else
        echo "Port ${PORT}/${PROTOCOL} is not allowed. Allowing it..."
        sudo ufw allow "${PORT}/${PROTOCOL}"
    fi

    echo "Current UFW status:"
    sudo ufw status
}

# Example usage:
# open_port_if_needed 3000 tcp
# open_port_if_needed 53 udp