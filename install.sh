#!/bin/bash

# VPS Docker Services Installation Script
# This script configures a secure VPS with all services

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

error() {
    echo -e "${RED}[ERROR] $1${NC}"
}

success() {
    echo -e "${GREEN}[SUCCESS] $1${NC}"
}

warning() {
    echo -e "${YELLOW}[WARNING] $1${NC}"
}

# Check if running as root
if [[ $EUID -eq 0 ]]; then
   error "This script should not be run as root for security reasons"
   exit 1
fi

# Load environment variables
if [ ! -f .env ]; then
    error ".env file not found. Please create it from the template."
    exit 1
fi

source .env

# =============================================================================
# Configuration Verification
# =============================================================================
log "Checking configuration..."

echo ""
echo "Current configuration:"
echo "======================"
echo "Domain: $DOMAIN"
echo "SSH Port: $SSH_PORT"
echo "SSH User: $SSH_USER"
echo "Cloudflare Email: $CLOUDFLARE_EMAIL"
echo "Nextcloud Data Dir: $NEXTCLOUD_DATADIR"
echo ""

# Check required variables
if [ -z "$DOMAIN" ] || [ "$DOMAIN" = "votredomaine.fr" ]; then
    error "Please set your actual domain in .env file"
    exit 1
fi

if [ -z "$SSH_PUBLIC_KEY" ] || [ "$SSH_PUBLIC_KEY" = "ssh-rsa AAAA... your-public-key-here" ]; then
    error "Please set your SSH public key in .env file"
    exit 1
fi

if [ -z "$CLOUDFLARE_API_TOKEN" ] || [ "$CLOUDFLARE_API_TOKEN" = "your-cloudflare-api-token" ]; then
    error "Please set your Cloudflare API token in .env file"
    exit 1
fi

read -p "Do you want to proceed with this configuration? (yes/no): " confirm
if [ "$confirm" != "yes" ]; then
    echo "Installation cancelled. Please update your .env file and try again."
    exit 1
fi

log "Starting VPS setup..."

# =============================================================================
# 1. System Update
# =============================================================================
log "Updating system packages..."
sudo apt update && sudo apt upgrade -y
sudo apt install -y curl wget git ufw fail2ban htop

# =============================================================================
# 2. SSH Security Configuration
# =============================================================================
log "Configuring SSH security..."

# Backup original SSH config
sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup

# Configure SSH
sudo sed -i "s/#Port 22/Port $SSH_PORT/" /etc/ssh/sshd_config
sudo sed -i 's/PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
sudo sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
sudo sed -i 's/#PubkeyAuthentication yes/PubkeyAuthentication yes/' /etc/ssh/sshd_config

# Add SSH public key
mkdir -p ~/.ssh
echo "$SSH_PUBLIC_KEY" >> ~/.ssh/authorized_keys
chmod 700 ~/.ssh
chmod 600 ~/.ssh/authorized_keys

# Restart SSH service
sudo systemctl restart ssh
success "SSH configured on port $SSH_PORT"

# =============================================================================
# 3. Firewall Configuration
# =============================================================================
log "Configuring UFW firewall..."

sudo ufw --force reset
sudo ufw default deny incoming
sudo ufw default allow outgoing

# Essential ports
sudo ufw allow $SSH_PORT/tcp comment 'SSH'
sudo ufw allow 80/tcp comment 'HTTP'
sudo ufw allow 443/tcp comment 'HTTPS'
sudo ufw allow 25/tcp comment 'SMTP'
sudo ufw allow 587/tcp comment 'SMTP Submission'
sudo ufw allow 993/tcp comment 'IMAPS'
sudo ufw allow 995/tcp comment 'POP3S'
sudo ufw allow 51820/udp comment 'WireGuard VPN'

sudo ufw --force enable
success "Firewall configured and enabled"

# =============================================================================
# 4. Docker Installation
# =============================================================================
log "Installing Docker and Docker Compose..."

# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $SSH_USER

# Install Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Create Docker networks
sudo docker network create traefik-proxy

success "Docker installed successfully"

# =============================================================================
# 5. Deploy Services
# =============================================================================
log "Deploying Docker services..."

# Create deployment directory
sudo mkdir -p /opt/docker-services
sudo chown $SSH_USER:$SSH_USER /opt/docker-services

# Copy configuration files
cp -r . /opt/docker-services/
cd /opt/docker-services

# Verify .env file exists
if [ ! -f .env ]; then
    error ".env file was not copied properly"
    exit 1
fi

# Make scripts executable
chmod +x backup/scripts/*.sh

# Generate Vaultwarden admin token if not set
if grep -q "generate-secure-token-here" .env; then
    ADMIN_TOKEN=$(openssl rand -base64 48)
    sed -i "s/generate-secure-token-here/$ADMIN_TOKEN/" .env
    warning "Generated Vaultwarden admin token. Check .env file."
fi

# Create required directories
sudo mkdir -p $NEXTCLOUD_DATADIR
sudo chown 33:33 $NEXTCLOUD_DATADIR

# Start services
docker-compose up -d

success "Services deployed successfully"

# =============================================================================
# 6. Post-installation checks
# =============================================================================
log "Running post-installation checks..."

# Wait for services to start
sleep 30

# Check if containers are running
docker-compose ps

# Display important information
echo ""
success "Installation completed successfully!"
echo ""
echo "IMPORTANT INFORMATION:"
echo "======================"
echo "SSH Port: $SSH_PORT"
echo "Domain: $DOMAIN"
echo ""
echo "DNS RECORDS TO CONFIGURE:"
echo "========================="
echo "A     @                -> YOUR_VPS_IP"
echo "A     www              -> YOUR_VPS_IP"
echo "A     cloud            -> YOUR_VPS_IP"
echo "A     vaultwarden      -> YOUR_VPS_IP"
echo "A     mail             -> YOUR_VPS_IP"
echo "A     portainer        -> YOUR_VPS_IP"
echo "A     monitoring       -> YOUR_VPS_IP"
echo "A     traefik          -> YOUR_VPS_IP"
echo "A     back             -> YOUR_VPS_IP"
echo "A     vpn              -> YOUR_VPS_IP"
echo "MX    @           10   -> mail.$DOMAIN"
echo ""
echo "SERVICES URLS:"
echo "=============="
echo "Nextcloud AIO:     https://cloud.$DOMAIN"
echo "Vaultwarden:       https://vaultwarden.$DOMAIN"
echo "Backup Interface:  https://back.$DOMAIN"
echo ""
echo "VPN-ONLY ACCESS (Connect VPN first):"
echo "===================================="
echo "Portainer:         https://portainer.$DOMAIN"
echo "Monitoring:        https://monitoring.$DOMAIN"
echo "Traefik:           https://traefik.$DOMAIN"
echo ""
echo "WIREGUARD VPN CLIENT CONFIGS:"
echo "============================="
echo "To get client configurations, run:"
echo "sudo docker exec wireguard cat /config/peer1/peer1.conf"
echo "sudo docker exec wireguard cat /config/peer2/peer2.conf"
echo "sudo docker exec wireguard cat /config/peer3/peer3.conf"
echo ""
echo "NEXTCLOUD AIO SETUP:"
echo "==================="
echo "1. Wait 2-3 minutes for all containers to start"
echo "2. Access Nextcloud AIO interface: https://cloud.$DOMAIN:8080"
echo "3. Follow the setup wizard to configure your Nextcloud instance"
echo "4. The mastercontainer will automatically create and manage Nextcloud containers"
echo ""
warning "1. Configure your DNS records as shown above"
warning "2. Connect to VPN before accessing admin interfaces"
warning "3. Complete Nextcloud AIO setup via the web interface"
warning "4. Download and save your VPN client configurations"

log "Setup completed! Reboot recommended."