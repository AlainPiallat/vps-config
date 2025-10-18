#!/bin/bash
# =============================================================================
# show-vpn-config.sh - Display VPN configurations and status
# =============================================================================

echo "=========================================="
echo "VPN Information and Access"
echo "=========================================="
echo ""

echo "WireGuard Status"
echo "-------------------"
if sudo systemctl is-active --quiet wg-quick@wg0; then
    echo "WireGuard active"
    sudo wg show
else
    echo "WireGuard inactive"
fi
echo ""

echo "Laptop client configuration:"
echo "-------------------------------"
sudo cat /etc/wireguard/client_laptop.conf 2>/dev/null || echo "File not found"
echo ""

echo "Phone client configuration:"
echo "------------------------------"
sudo cat /etc/wireguard/client_phone.conf 2>/dev/null || echo "File not found"
echo ""

echo "To generate a QR code (install qrencode):"
echo "   sudo apt install qrencode"
echo "   sudo cat /etc/wireguard/client_phone.conf | qrencode -t ansiutf8"
echo ""

echo "=========================================="
