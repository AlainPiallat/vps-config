#!/bin/bash
# =============================================================================
# update-ufw.sh - Update UFW firewall rules based on .port configuration
# =============================================================================
# This script updates UFW rules to match the ports defined in .port file
# Run as root: sudo ./update-ufw.sh

set -e

# Load port configuration from /etc/vps-config/.port
PORT_FILE="/etc/vps-config/.port"
if [ ! -f "$PORT_FILE" ]; then
    echo "ERROR: .port file not found at $PORT_FILE"
    echo "Please ensure init.sh has been run and the .port file exists"
    exit 1
fi

# Check if running as root
if [ "$(id -u)" -ne 0 ]; then 
    echo "ERROR: This script must be run as root"
    echo "Usage: sudo ./update-ufw.sh"
    exit 1
fi

echo "UFW Firewall Update"
echo "==================="
echo ""

#----------------------------------------------------------------
# Remove Previous Configuration
#----------------------------------------------------------------

echo "Remove Previous Configuration ..."
echo ""

# Remove all existing rules
ufw --force reset
echo "  - All existing UFW rules removed"

# Set default policies
ufw default deny incoming
ufw default allow outgoing

#----------------------------------------------------------------
# Port Configuration
#----------------------------------------------------------------

echo "Configuring ports from .port file..."
echo ""

while IFS= read -r line; do
    # Skip empty lines and comments
    if [ -z "$line" ] || echo "$line" | grep -q '^[[:space:]]*#'; then
        continue
    fi
    
    # Parse line: port protocol service_name
    port=$(echo "$line" | awk '{print $1}')
    proto=$(echo "$line" | awk '{print $2}')
    name=$(echo "$line" | awk '{$1=""; $2=""; print $0}' | sed 's/^[[:space:]]*//')
    
    # Convert protocol to lowercase
    proto=$(echo "$proto" | tr '[:upper:]' '[:lower:]')
    
    # Validate port and protocol
    if [ -z "$port" ] || [ -z "$proto" ]; then
        echo "  - Skipping invalid line: $line"
        continue
    fi
    
    # Add UFW rule
    if [ -n "$name" ]; then
        ufw allow "$port/$proto" comment "$name"
        echo "  - Allowed $proto port $port ($name)"
    else
        ufw allow "$port/$proto"
        echo "  - Allowed $proto port $port"
    fi
done < "$PORT_FILE"

#----------------------------------------------------------------
# Reload UFW
#----------------------------------------------------------------
echo ""
echo "Reloading UFW..."
ufw reload
ufw --force enable
echo "UFW reloaded and enabled"

echo ""
echo "=========================================="
echo "UFW Configuration Updated"
echo "=========================================="
echo ""
echo "Current UFW status:"
ufw status verbose
echo ""
echo "=========================================="