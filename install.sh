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

# Create log file with timestamp (absolute path)
LOG_FILE="$(pwd)/install-$(date +'%Y-%m-%d_%H-%M-%S').log"

# Function to log to file with type formatting
log_to_file() {
    local type="$1"
    local message="$2"
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] [$type] $message" >> "$LOG_FILE"
}

# Logging functions with file logging
log() {
    local message="$1"
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] $message${NC}"
    log_to_file "LOG" "$message"
}

# Information functions
info() {
    local message="$1"
    echo -e "${NC}[$(date +'%Y-%m-%d %H:%M:%S')] $message${NC}"
    log_to_file "INFO" "$message"
}

error() {
    local message="[ERROR] $1"
    echo -e "${RED}$message${NC}"
    log_to_file "ERROR" "$1"
}

success() {
    local message="[SUCCESS] $1"
    echo -e "${GREEN}$message${NC}"
    log_to_file "SUCCESS" "$1"
}

warning() {
    local message="[WARNING] $1"
    echo -e "${YELLOW}$message${NC}"
    log_to_file "WARNING" "$1"
}

# Start logging
log_to_file "SYSTEM" "===== VPS Installation Started ====="
log_to_file "SYSTEM" "Log file: $LOG_FILE"

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

# Log configuration to file
log_to_file "CONFIG" "Domain: $DOMAIN"
log_to_file "CONFIG" "SSH Port: $SSH_PORT"
log_to_file "CONFIG" "SSH User: $SSH_USER"
log_to_file "CONFIG" "Cloudflare Email: $CLOUDFLARE_EMAIL"
log_to_file "CONFIG" "Nextcloud Data Dir: $NEXTCLOUD_DATADIR"

# =============================================================================
# Configuration Verification
# =============================================================================
log "Checking configuration..."

info ""
info "Current configuration:"
info "======================"
info "Domain: $DOMAIN"
info "SSH Port: $SSH_PORT"
info "SSH User: $SSH_USER"
info "Cloudflare Email: $CLOUDFLARE_EMAIL"
info "Nextcloud Data Dir: $NEXTCLOUD_DATADIR"
info ""

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
log_to_file "USER" "User response: $confirm"
if [ "$confirm" != "yes" ]; then
    info "Installation cancelled. Please update your .env file and try again."
    log_to_file "USER" "Installation cancelled by user"
    exit 1
fi

log_to_file "USER" "User confirmed configuration"
log "Starting VPS setup..."

# =============================================================================
# 1. SSH Security Configuration
# =============================================================================
log "Configuring SSH security..."

# Backup original SSH config
sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup
log_to_file "SSH" "SSH config backed up"

# Configure SSH
log_to_file "SSH" "Configuring SSH port to $SSH_PORT"
sudo sed -i "s/#Port 22/Port $SSH_PORT/" /etc/ssh/sshd_config 
log_to_file "SSH" "Disabling root login"
sudo sed -i 's/PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config 
log_to_file "SSH" "Disabling password authentication"
sudo sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config 
log_to_file "SSH" "Enabling public key authentication"
sudo sed -i 's/#PubkeyAuthentication yes/PubkeyAuthentication yes/' /etc/ssh/sshd_config 

# Add SSH public key
log_to_file "SSH" "Setting up SSH directory"
mkdir -p ~/.ssh 
log_to_file "SSH" "Adding SSH public key"
echo "$SSH_PUBLIC_KEY" >> ~/.ssh/authorized_keys 2>/dev/null
log_to_file "SSH" "Setting SSH permissions"
chmod 700 ~/.ssh 
chmod 600 ~/.ssh/authorized_keys 
log_to_file "SSH" "SSH public key added successfully"

# Restart SSH service
sudo systemctl restart ssh 
success "SSH configured on port $SSH_PORT"

# =============================================================================
# 2. Firewall Configuration
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
# 3. Docker Installation
# =============================================================================
log "Installing Docker and Docker Compose..."
info "Downloading and installing Docker (this may take a few minutes)..."

# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $SSH_USER
log_to_file "DOCKER" "User $SSH_USER added to docker group"

# Install Docker Compose
log_to_file "DOCKER" "Downloading Docker Compose"
info "Downloading Docker Compose..."
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose 
log_to_file "DOCKER" "Making Docker Compose executable"
sudo chmod +x /usr/local/bin/docker-compose
log_to_file "DOCKER" "Docker Compose installed successfully"

# Create Docker networks
sudo docker network create traefik-proxy 
log_to_file "DOCKER" "Docker network created"

success "Docker installed successfully"

# =============================================================================
# 4. Deploy Services
# =============================================================================
log "Deploying Docker services..."

# Create deployment directory
sudo mkdir -p /opt/docker-services
sudo chown $SSH_USER:$SSH_USER /opt/docker-services
log_to_file "DEPLOY" "Deployment directory created: /opt/docker-services"

# Copy configuration files
log_to_file "DEPLOY" "Copying configuration files to /opt/docker-services/"
cp -r . /opt/docker-services/ 
log_to_file "DEPLOY" "Changing to deployment directory"
cd /opt/docker-services

# Verify .env file exists
if [ ! -f .env ]; then
    error ".env file was not copied properly"
    exit 1
fi
log_to_file "DEPLOY" ".env file verified successfully"

# Make scripts executable
log_to_file "DEPLOY" "Making backup scripts executable"
chmod +x backup/scripts/*.sh 
log_to_file "DEPLOY" "Backup scripts made executable"

# Generate Vaultwarden admin token if not set
if grep -q "generate-secure-token-here" .env; then
    ADMIN_TOKEN=$(openssl rand -base64 48)
    sed -i "s/generate-secure-token-here/$ADMIN_TOKEN/" .env
    warning "Generated Vaultwarden admin token. Check .env file."
    log_to_file "SECURITY" "Vaultwarden admin token generated"
fi

# Create required directories
log_to_file "NEXTCLOUD" "Creating Nextcloud data directory: $NEXTCLOUD_DATADIR"
sudo mkdir -p $NEXTCLOUD_DATADIR 
log_to_file "NEXTCLOUD" "Setting Nextcloud directory ownership to www-data (33:33)"
sudo chown 33:33 $NEXTCLOUD_DATADIR 
log_to_file "NEXTCLOUD" "Nextcloud data directory created: $NEXTCLOUD_DATADIR"

# Function to deploy services with proper Docker permissions
deploy_services() {
    log "Starting Docker services deployment..."
    info "Pulling Docker images and starting containers (this may take several minutes)..."
    
    # Use sg to get Docker permissions in this shell
    if ! docker ps ; then
        log "Activating Docker group permissions..."
        # Execute the docker commands with the docker group
        sg docker -c "
            docker-compose up -d 
        "
    else
        # Docker already works
        docker-compose up -d 
    fi
    
    log_to_file "DEPLOY" "Docker services deployment completed"
}

# Deploy services
deploy_services

success "Services deployed successfully"

# =============================================================================
# 5. Post-installation checks
# =============================================================================
log "Running post-installation checks..."

# Wait for services to start
sleep 30

# Check if containers are running (with proper Docker permissions)
log "Checking container status..."
if ! docker ps ; then
    sg docker -c "docker-compose ps" 
else
    docker-compose ps 
fi
log_to_file "DEPLOY" "Container status checked"

# Display important information
info ""
success "Installation completed successfully!"
info ""
info "IMPORTANT INFORMATION:"
info "======================"
info "SSH Port: $SSH_PORT"
info "Domain: $DOMAIN"
info "Log File: $LOG_FILE"
info ""
info "DNS RECORDS TO CONFIGURE:"
info "=========================="
info "A     @                -> YOUR_VPS_IP"
info "A     www              -> YOUR_VPS_IP"
info "A     cloud            -> YOUR_VPS_IP"
info "A     vaultwarden      -> YOUR_VPS_IP"
info "A     mail             -> YOUR_VPS_IP"
info "A     portainer        -> YOUR_VPS_IP"
info "A     monitoring       -> YOUR_VPS_IP"
info "A     traefik          -> YOUR_VPS_IP"
info "A     back             -> YOUR_VPS_IP"
info "A     vpn              -> YOUR_VPS_IP"
info "MX    @           10   -> mail.$DOMAIN"
info ""
info "SERVICES URLS:"
info "=============="
info "Nextcloud AIO:     https://cloud.$DOMAIN"
info "Vaultwarden:       https://vaultwarden.$DOMAIN"
info "Backup Interface:  https://back.$DOMAIN"
info ""
info "VPN-ONLY ACCESS (Connect VPN first):"
info "===================================="
info "Portainer:         https://portainer.$DOMAIN"
info "Monitoring:        https://monitoring.$DOMAIN"
info "Traefik:           https://traefik.$DOMAIN"
info ""
info "WIREGUARD VPN CLIENT CONFIGS:"
info "============================="
info "To get client configurations, run:"
info "sudo docker exec wireguard cat /config/peer1/peer1.conf"
info "sudo docker exec wireguard cat /config/peer2/peer2.conf"
info "sudo docker exec wireguard cat /config/peer3/peer3.conf"
info ""
info "NEXTCLOUD AIO SETUP:"
info "==================="
info "1. Wait 2-3 minutes for all containers to start"
info "2. Access Nextcloud AIO interface: https://cloud.$DOMAIN:8080"
info "3. Follow the setup wizard to configure your Nextcloud instance"
info "4. The mastercontainer will automatically create and manage Nextcloud containers"
info ""
warning "1. Configure your DNS records as shown above"
warning "2. Connect to VPN before accessing admin interfaces"
warning "3. Complete Nextcloud AIO setup via the web interface"
warning "4. Download and save your VPN client configurations"

info "Setup completed! Reboot recommended."
log_to_file "SYSTEM" "===== VPS Installation Completed Successfully ====="

# Send Discord notification if webhook is configured
if [ ! -z "$NOTIFICATION_URL" ]; then
    log "Sending installation completion notification..."
    curl -s -X POST "$NOTIFICATION_URL" \
         -H "Content-Type: application/json" \
         -d '{
             "username": "VPS-Bot",
             "embeds": [
                 {
                     "title": "🎉 VPS Installation Complete",
                     "description": "Your VPS has been successfully configured and deployed!",
                     "color": 3066993,
                     "fields": [
                         {
                             "name": "🌐 Domain",
                             "value": "'"$DOMAIN"'",
                             "inline": true
                         },
                         {
                             "name": "🔒 SSH Port", 
                             "value": "'"$SSH_PORT"'",
                             "inline": true
                         },
                         {
                             "name": "📋 Services",
                             "value": "• Nextcloud AIO\\n• Vaultwarden\\n• Traefik\\n• WireGuard VPN\\n• Monitoring\\n• Backup System",
                             "inline": false
                         },
                         {
                             "name": "🔗 Quick Links",
                             "value": "[Nextcloud](https://cloud.'"$DOMAIN"') • [Vaultwarden](https://vaultwarden.'"$DOMAIN"') • [Backup](https://back.'"$DOMAIN"')",
                             "inline": false
                         }
                     ],
                     "footer": {
                         "text": "Installation completed on '"$(date +'%Y-%m-%d %H:%M:%S')"'"
                     }
                 }
             ]
         }' 
    
    if [ $? -eq 0 ]; then
        log_to_file "NOTIFICATION" "Discord notification sent successfully"
    else
        log_to_file "NOTIFICATION" "Failed to send Discord notification"
    fi
fi