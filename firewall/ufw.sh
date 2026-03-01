#!/bin/bash

# Function to open a port in UFW if it's not already allowed
open_port_if_needed() {
    local PORT=$1

    if [ -z "$PORT" ]; then
        echo "Usage: open_port_if_needed <port>"
        return 1
    fi

    # Check if UFW is active
    if ! sudo ufw status | grep -q "Status: active"; then
        echo "UFW is inactive. Enabling UFW..."
        sudo ufw allow ssh          # Keep SSH open
        sudo ufw enable
    fi

    # Check if the port is already allowed
    if sudo ufw status | grep -q "${PORT}/tcp"; then
        echo "Port ${PORT}/tcp is already allowed."
    else
        echo "Port ${PORT}/tcp is not allowed. Allowing it..."
        sudo ufw allow "${PORT}/tcp"
    fi

    echo "Current UFW status:"
    sudo ufw status
}

# Example usage:
# open_port_if_needed 3000