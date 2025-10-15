# =============================================================================
# new-site.sh - Deploy a new Apache-based website with Docker
# =============================================================================
# This script creates a new dockerized Apache website with Traefik integration
# Usage: ./new-site.sh [subdomain]
# Examples: 
#   ./new-site.sh blog         # Creates blog.example.com
#   ./new-site.sh @            # Creates example.com (main site)

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Load environment variables
if [ -f ~/.env ]; then
    source ~/.env
elif [ -f /etc/vps-config/.env ]; then
    source /etc/vps-config/.env
else
    echo -e "${RED}ERROR: .env file not found${NC}"
    echo "Please ensure init.sh has been run"
    exit 1
fi

# Check if running as root (should not run as root, but needs sudo for /srv/)
if [ "$EUID" -eq 0 ]; then
    echo -e "${RED}ERROR: This script should NOT be run as root${NC}"
    echo "Run as regular user with sudo privileges"
    echo "Usage: ./new-site.sh [subdomain]"
    exit 1
fi

# Parse arguments
if [ "$#" -ne 1 ]; then
    echo -e "${RED}ERROR: Invalid number of arguments${NC}"
    echo ""
    echo "Usage: $0 [subdomain]"
    echo ""
    echo "Arguments:"
    echo "  subdomain  - Subdomain name (e.g., 'blog' for blog.example.com)"
    echo "               Use '@' for the main domain (${DOMAIN})"
    echo ""
    echo "Examples:"
    echo "  $0 blog     # Creates blog.${DOMAIN}"
    echo "  $0 @        # Creates ${DOMAIN} (main site)"
    exit 1
fi

SUBDOMAIN_INPUT="$1"

# Handle main domain case
if [ "$SUBDOMAIN_INPUT" = "@" ]; then
    SUBDOMAIN="www"
    SITE_NAME="site-main"
    FULL_DOMAIN="${DOMAIN}"
else
    SUBDOMAIN="$SUBDOMAIN_INPUT"
    SITE_NAME="site-${SUBDOMAIN}"
    FULL_DOMAIN="${SUBDOMAIN}.${DOMAIN}"
    
    # Validate subdomain format (alphanumeric and hyphens only)
    if [[ ! "$SUBDOMAIN" =~ ^[a-z0-9-]+$ ]]; then
        echo -e "${RED}ERROR: Invalid subdomain format${NC}"
        echo "Subdomain must contain only lowercase letters, numbers, and hyphens"
        exit 1
    fi
fi

# Configuration - Using /srv/ for sites (Linux standard)
SITES_DIR="/srv"
SITE_DIR="${SITES_DIR}/${SITE_NAME}"

echo ""
echo -e "${BLUE}=========================================="
echo "New Website Deployment"
echo "==========================================${NC}"
echo ""
echo "Configuration:"
if [ "$SUBDOMAIN_INPUT" = "@" ]; then
    echo "  Type:         Main domain"
else
    echo "  Subdomain:    ${SUBDOMAIN}"
fi
echo "  Full domain:  ${FULL_DOMAIN}"
echo "  Site dir:     ${SITE_DIR}"
echo ""

# Check if site already exists
if [ -d "$SITE_DIR" ]; then
    echo -e "${YELLOW}WARNING: Site directory already exists: ${SITE_DIR}${NC}"
    read -p "Do you want to overwrite it? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Aborting."
        exit 1
    fi
    echo -e "${YELLOW}Removing existing site directory...${NC}"
    sudo rm -rf "$SITE_DIR"
fi

#----------------------------------------------------------------
# Create Directory Structure
#----------------------------------------------------------------
echo ""
echo -e "${GREEN}Creating directory structure...${NC}"
sudo mkdir -p "$SITES_DIR"
sudo mkdir -p "$SITE_DIR"
sudo mkdir -p "$SITE_DIR/html"
sudo mkdir -p "$SITE_DIR/logs"
sudo chown -R $USER:$USER "$SITE_DIR"
echo "  - Created ${SITE_DIR}"
echo "  - Created ${SITE_DIR}/html"
echo "  - Created ${SITE_DIR}/logs"

#----------------------------------------------------------------
# Create Welcome Page
#----------------------------------------------------------------
echo ""
echo -e "${GREEN}Creating welcome page...${NC}"
cat > "$SITE_DIR/html/index.html" << EOF
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Welcome to ${FULL_DOMAIN}</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, Cantarell, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
            padding: 20px;
        }
        .container {
            background: white;
            border-radius: 20px;
            padding: 60px 40px;
            max-width: 600px;
            box-shadow: 0 20px 60px rgba(0, 0, 0, 0.3);
            text-align: center;
        }
        h1 {
            color: #667eea;
            font-size: 2.5em;
            margin-bottom: 20px;
            animation: fadeInDown 1s ease;
        }
        .domain {
            color: #764ba2;
            font-weight: bold;
            font-size: 1.2em;
        }
        p {
            color: #666;
            font-size: 1.1em;
            line-height: 1.6;
            margin-bottom: 30px;
        }
        .status {
            display: inline-block;
            background: #10b981;
            color: white;
            padding: 10px 30px;
            border-radius: 50px;
            font-weight: bold;
            margin-top: 20px;
            animation: pulse 2s ease infinite;
        }
        .info {
            margin-top: 40px;
            padding: 20px;
            background: #f3f4f6;
            border-radius: 10px;
            color: #4b5563;
            font-size: 0.9em;
        }
        @keyframes fadeInDown {
            from {
                opacity: 0;
                transform: translateY(-20px);
            }
            to {
                opacity: 1;
                transform: translateY(0);
            }
        }
        @keyframes pulse {
            0%, 100% {
                transform: scale(1);
            }
            50% {
                transform: scale(1.05);
            }
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>Welcome!</h1>
        <p>Your website <span class="domain">${FULL_DOMAIN}</span> is now live and ready to go!</p>
        <div class="status">Site Online</div>
        <div class="info">
            <strong>Next steps:</strong><br>
            Replace this page with your content by editing:<br>
            <code>${SITE_DIR}/html/index.html</code>
        </div>
    </div>
</body>
</html>
EOF
echo "  - Created ${SITE_DIR}/html/index.html"

#----------------------------------------------------------------
# Create Docker Compose Configuration
#----------------------------------------------------------------
echo ""
echo -e "${GREEN}Creating Docker Compose configuration...${NC}"
cat > "$SITE_DIR/docker-compose.yml" << EOF
version: '3.8'

networks:
  proxy:
    external: true

services:
  ${SITE_NAME}:
    image: httpd:2.4-alpine
    container_name: ${SITE_NAME}
    restart: unless-stopped
    networks:
      - proxy
    volumes:
      - ./html:/usr/local/apache2/htdocs:ro
      - ./logs:/usr/local/apache2/logs
    labels:
      - "traefik.enable=true"
      - "traefik.docker.network=proxy"
      
      # HTTP router
      - "traefik.http.routers.${SITE_NAME}.rule=Host(\\\`${FULL_DOMAIN}\\\`)"
      - "traefik.http.routers.${SITE_NAME}.entrypoints=web"
      - "traefik.http.routers.${SITE_NAME}.middlewares=${SITE_NAME}-redirect"
      
      # HTTPS router
      - "traefik.http.routers.${SITE_NAME}-secure.rule=Host(\\\`${FULL_DOMAIN}\\\`)"
      - "traefik.http.routers.${SITE_NAME}-secure.entrypoints=websecure"
      - "traefik.http.routers.${SITE_NAME}-secure.tls=true"
      - "traefik.http.routers.${SITE_NAME}-secure.tls.certresolver=letsencrypt"
      
      # Middleware for HTTP to HTTPS redirect
      - "traefik.http.middlewares.${SITE_NAME}-redirect.redirectscheme.scheme=https"
      - "traefik.http.middlewares.${SITE_NAME}-redirect.redirectscheme.permanent=true"
      
      # Service configuration
      - "traefik.http.services.${SITE_NAME}.loadbalancer.server.port=80"
EOF
echo "  - Created ${SITE_DIR}/docker-compose.yml"

#----------------------------------------------------------------
# Create README
#----------------------------------------------------------------
echo ""
echo -e "${GREEN}Creating README...${NC}"
cat > "$SITE_DIR/README.md" << EOF
# ${FULL_DOMAIN}

This site is deployed using Docker and Traefik.

## Directory Structure

\`\`\`
${SITE_NAME}/
├── docker-compose.yml  # Docker configuration
├── html/               # Website files
│   └── index.html     # Main page
├── logs/              # Apache logs
└── README.md          # This file
\`\`\`

## Management Commands

### Start the site
\`\`\`bash
cd ${SITE_DIR}
docker compose up -d
\`\`\`

### Stop the site
\`\`\`bash
cd ${SITE_DIR}
docker compose down
\`\`\`

### View logs
\`\`\`bash
cd ${SITE_DIR}
docker compose logs -f
\`\`\`

### Restart the site
\`\`\`bash
cd ${SITE_DIR}
docker compose restart
\`\`\`

### Update content
1. Edit files in \`${SITE_DIR}/html/\`
2. Restart the container: \`docker compose restart\`

## URLs

- **Production**: https://${FULL_DOMAIN}
- **HTTP (redirects to HTTPS)**: http://${FULL_DOMAIN}

## SSL Certificate

SSL certificates are automatically generated and renewed by Let's Encrypt via Traefik.
EOF
echo "  - Created ${SITE_DIR}/README.md"

#----------------------------------------------------------------
# Create Management Script
#----------------------------------------------------------------
echo ""
echo -e "${GREEN}Creating management script...${NC}"
cat > "$SITE_DIR/manage.sh" << 'EOF'
#!/bin/bash
# Site management script

case "$1" in
    start)
        docker compose up -d
        ;;
    stop)
        docker compose down
        ;;
    restart)
        docker compose restart
        ;;
    logs)
        docker compose logs -f
        ;;
    status)
        docker compose ps
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|logs|status}"
        exit 1
        ;;
esac
EOF
chmod +x "$SITE_DIR/manage.sh"
echo "  - Created ${SITE_DIR}/manage.sh"

#----------------------------------------------------------------
# Start Docker Container
#----------------------------------------------------------------
echo ""
echo -e "${GREEN}Starting Docker container...${NC}"
cd "$SITE_DIR"
docker compose up -d

# Wait for container to be ready
echo "Waiting for container to start..."
sleep 5

#----------------------------------------------------------------
# Verify Deployment
#----------------------------------------------------------------
echo ""
echo -e "${BLUE}Verifying deployment...${NC}"

# Check if container is running
if docker compose ps | grep -q "Up"; then
    echo -e "${GREEN}Container is running${NC}"
else
    echo -e "${RED}Container failed to start${NC}"
    docker compose logs
    exit 1
fi

# Test HTTP access
echo ""
echo "Testing HTTP access..."
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -L "http://${FULL_DOMAIN}" --connect-timeout 10 --max-time 30 2>/dev/null || echo "000")

if [ "$HTTP_CODE" = "200" ]; then
    echo -e "${GREEN}Site is accessible via HTTP${NC}"
    echo -e "${GREEN}HTTP redirects to HTTPS (if configured)${NC}"
elif [ "$HTTP_CODE" = "000" ]; then
    echo -e "${YELLOW}Could not reach ${FULL_DOMAIN}${NC}"
    echo -e "${YELLOW}  This is normal if DNS is not configured yet${NC}"
    echo -e "${YELLOW}  Please ensure your DNS records point to this server${NC}"
else
    echo -e "${YELLOW}Received HTTP code: ${HTTP_CODE}${NC}"
fi

#----------------------------------------------------------------
# Final Summary
#----------------------------------------------------------------
echo ""
echo -e "${BLUE}=========================================="
echo "Deployment Complete!"
echo "==========================================${NC}"
echo ""
echo "Site Information:"
echo "  Name:         ${SITE_NAME}"
echo "  Domain:       ${FULL_DOMAIN}"
echo "  Directory:    ${SITE_DIR}"
echo "  Container:    ${SITE_NAME}"
echo ""
echo "Access URLs:"
echo "  Production:   https://${FULL_DOMAIN}"
echo "  HTTP:         http://${FULL_DOMAIN} (redirects to HTTPS)"
echo ""
echo "Management:"
echo "  Start:        cd ${SITE_DIR} && docker compose up -d"
echo "  Stop:         cd ${SITE_DIR} && docker compose down"
echo "  Logs:         cd ${SITE_DIR} && docker compose logs -f"
echo "  Quick:        cd ${SITE_DIR} && ./manage.sh {start|stop|restart|logs|status}"
echo ""
echo "Content:"
echo "  Edit files in: ${SITE_DIR}/html/"
echo "  Main page:     ${SITE_DIR}/html/index.html"
echo ""
echo -e "${YELLOW}Important:${NC}"
echo "  1. Ensure DNS records for ${FULL_DOMAIN} point to this server"
echo "  2. SSL certificate will be automatically generated by Let's Encrypt"
echo "  3. It may take a few minutes for HTTPS to become available"
echo ""
echo -e "${BLUE}==========================================${NC}"
