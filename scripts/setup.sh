#!/bin/bash
# =============================================================================
# setup.sh - Setup Admin Stack with Traefik and Portainer
# =============================================================================
# Sets up Traefik reverse proxy and Portainer for Docker management
# Run as regular user (not root)

set -e

echo "Admin Stack Configuration"
echo "========================="
echo ""

# Load environment variables
SCRIPT_DIR="$(pwd)"

if [ ! -f "$SCRIPT_DIR/.env" ]; then
    echo "ERROR: .env file not found"
    echo "Please create a .env file based on .env.example"
    exit 1
fi

source "$SCRIPT_DIR/.env"

# Verify NOT running as root
if [ "$EUID" -eq 0 ]; then
    echo "ERROR: This script should NOT be run as root"
    echo "Usage: ./setup.sh (as user $USER_NAME)"
    exit 1
fi

# Verify Docker is installed
if ! command -v docker &> /dev/null; then
    echo "ERROR: Docker is not installed"
    echo "Please run init.sh as root first"
    exit 1
fi

# Verify user is in docker group
if ! groups | grep -q docker; then
    echo "ERROR: User is not in docker group"
    echo "Please logout and login again, or run:"
    echo "  sudo usermod -aG docker $USER"
    echo "  newgrp docker"
    exit 1
fi

# Verify WireGuard is active
if ! sudo systemctl is-active --quiet wg-quick@wg0; then
    echo "WARNING: WireGuard is not active"
    echo "Verify that init.sh was executed correctly"
    read -p "Do you want to continue anyway? (y/N) " choice
    case "$choice" in
        y|Y ) echo "Continuing...";;
        * ) exit 1;;
    esac
fi

echo ""
echo "Creating directory structure..."
mkdir -p ~/admin-stack/traefik
cd ~/admin-stack

#----------------------------------------------------------------
# Traefik Configuration
#----------------------------------------------------------------
echo ""
echo "Creating Traefik configuration (dynamic.yml)..."

# VPN whitelist middleware
cat > traefik/dynamic.yml << EOF
http:
  middlewares:
    vpn-whitelist:
      ipWhiteList:
        sourceRange:
          - "${VPN_SUBNET}"
          - "${VPN_SERVER_IP}/32"
          - "127.0.0.1/32"
          - "::1/128"
EOF

echo "Traefik configuration created"

#----------------------------------------------------------------
# Docker Compose
#----------------------------------------------------------------
echo ""
echo "Creating docker-compose.yml..."

cat > docker-compose.yml << EOF
networks:
  proxy:
    driver: bridge
    name: proxy

volumes:
  traefik_letsencrypt:
  portainer_data:

services:
  traefik:
    image: traefik:v2.10
    container_name: traefik
    restart: unless-stopped
    security_opt:
      - no-new-privileges:true
    environment:
      - TZ=${TZ}
    command:
      - --entryPoints.web.address=:${HTTP_PORT}
      - --entryPoints.websecure.address=:${HTTPS_PORT}
      - --entryPoints.internal.address=:8080
      
      - --providers.docker=true
      - --providers.docker.watch=true
      - --providers.docker.network=proxy
      - --providers.docker.exposedbydefault=false
      
      - --providers.file.filename=/dynamic.yml
      - --providers.file.watch=true
      
      - --api=true
      - --api.dashboard=true
      
      - --certificatesResolvers.letsencrypt.acme.email=${USER_EMAIL}
      - --certificatesResolvers.letsencrypt.acme.storage=/letsencrypt/acme.json
      - --certificatesResolvers.letsencrypt.acme.httpChallenge.entryPoint=web
      
      - --accessLog=true
      - --accessLog.format=json
      - --accessLog.filePath=/var/log/access.log
      - --accessLog.bufferingSize=100
      - --accessLog.filters.statusCodes=204-299,400-499,500-599
      
      - --log.level=INFO
    networks:
      - proxy
    ports:
      - "${HTTP_PORT}:${HTTP_PORT}"
      - "${HTTPS_PORT}:${HTTPS_PORT}"
      - "${VPN_SERVER_IP}:8080:8080"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - traefik_letsencrypt:/letsencrypt
      - /var/log/traefik:/var/log
      - ./traefik/dynamic.yml:/dynamic.yml:ro
    labels:
      - "traefik.enable=true"
      # HTTP route via path on internal port (VPN only)
      - "traefik.http.routers.api-internal.rule=PathPrefix(\`/api\`) || PathPrefix(\`/dashboard\`)"
      - "traefik.http.routers.api-internal.service=api@internal"
      - "traefik.http.routers.api-internal.entrypoints=internal"
      - "traefik.http.routers.api-internal.middlewares=vpn-whitelist@file"

  portainer:
    image: portainer/portainer-ce:latest
    container_name: portainer
    restart: unless-stopped
    security_opt:
      - no-new-privileges:true
    networks:
      - proxy
    ports:
      - "${VPN_SERVER_IP}:9000:9000"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - portainer_data:/data
    labels:
      - "traefik.enable=true"
      - "traefik.docker.network=proxy"
      # HTTP route via path on internal port (VPN only)
      - "traefik.http.routers.portainer-internal.rule=PathPrefix(\`/portainer\`)"
      - "traefik.http.routers.portainer-internal.entrypoints=internal"
      - "traefik.http.routers.portainer-internal.service=portainer"
      - "traefik.http.routers.portainer-internal.middlewares=vpn-whitelist@file,portainer-stripprefix"
      - "traefik.http.middlewares.portainer-stripprefix.stripprefix.prefixes=/portainer"
      # Service configuration
      - "traefik.http.services.portainer.loadbalancer.server.port=9000"
EOF

echo "docker-compose.yml created"

#----------------------------------------------------------------
# Startup Script Installation
#----------------------------------------------------------------
echo ""
echo "Installing startup script..."

cp "$SCRIPT_DIR/start-admin-stack.sh" "~/admin-stack/start.sh"
chmod +x ~/admin-stack/start.sh

echo "start.sh script installed"

#----------------------------------------------------------------
# Final Summary
#----------------------------------------------------------------
echo ""
echo "=========================================="
echo "CONFIGURATION COMPLETED"
echo "=========================================="
echo ""
echo "Directory structure created in ~/admin-stack/"
echo "   ├── docker-compose.yml"
echo "   ├── traefik/"
echo "   │   └── dynamic.yml"
echo "   └── start.sh           # Start the stack"
echo ""
echo "=========================================="
echo "NEXT STEPS"
echo "=========================================="
echo ""
echo "1. Start the Docker stack:"
echo "   cd ~/admin-stack"
echo "   ./start.sh"
echo ""
echo "   OR manually:"
echo "   docker compose up -d"
echo ""
echo "2. Get VPN configurations:"
echo "   ./show-vpn-config.sh"
echo ""
echo "3. On your devices (PC/Phone):"
echo "   - Install WireGuard"
echo "   - Import the corresponding configuration"
echo "   - Activate the VPN tunnel"
echo ""
echo "4. Once connected to the VPN, access:"
echo ""
echo "   === ACCESS VIA IP (recommended on VPN) ==="
echo "   - http://${VPN_SERVER_IP}:8080/dashboard/    # Traefik Dashboard"
echo "   - http://${VPN_SERVER_IP}:9000/              # Portainer"
echo ""
echo "=========================================="
echo "SECURITY"
echo "=========================================="
echo ""
echo "Admin services (Portainer, Traefik) are protected"
echo "by the VPN whitelist middleware."
echo ""
echo "They are ONLY accessible from the VPN network:"
echo "${VPN_SUBNET}"
echo ""
echo "Without active VPN → Access denied (403 Forbidden)"
echo ""
echo "=========================================="
echo "USEFUL COMMANDS"
echo "=========================================="
echo ""
echo "cd ~/admin-stack"
echo "./start.sh                         # Start all containers"
echo ""
echo "docker compose ps                  # Container status"
echo "docker compose logs -f             # View all logs"
echo "docker compose logs -f traefik     # Logs for specific container"
echo "docker compose restart             # Restart all containers"
echo "docker compose down                # Stop and remove containers"
echo ""
echo "=========================================="
echo "QUICK ACCESS (once VPN connected)"
echo "=========================================="
echo ""
echo "Traefik Dashboard:  http://${VPN_SERVER_IP}:8080/dashboard/"
echo "Portainer:          http://${VPN_SERVER_IP}:9000/"
echo ""
echo "=========================================="