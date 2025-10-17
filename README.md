# VPS Admin Stack Configuration

[![License: Apache 2.0](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](LICENSE)
[![Docker](https://img.shields.io/badge/Docker-Ready-blue)](https://www.docker.com/)
[![Ubuntu](https://img.shields.io/badge/Tested%20on-Ubuntu%2022.04-orange)](https://ubuntu.com/)
[![WireGuard](https://img.shields.io/badge/WireGuard-Enabled-success)](https://www.wireguard.com/)

Automated setup for a secure VPS with WireGuard VPN, Traefik reverse proxy, and Portainer container management. 

## Features

* **WireGuard VPN**: Secure private network access to administration services.
* **Traefik v2**: Reverse proxy with automatic HTTPS via Let's Encrypt.
* **Portainer**: Web-based interface for Docker container management.
* **Website Deployment**: Easy deployment of Apache-based websites with automatic SSL.
* **Security**: Admin services accessible only through the VPN and optional IP whitelisting.
* **Automation**: Complete setup in a few commands.
* **Modularity**: Add or remove services easily.

## Project Structure

```
vps-config/
├── init.sh              # Main initialization script (run as root)
├── scripts/             # User scripts directory
│   ├── setup.sh        # Admin stack setup
│   ├── start-admin-stack.sh
│   ├── show-vpn-config.sh
│   ├── update-ufw.sh   # UFW firewall management
│   └── new-site.sh     # Deploy new websites
├── .env                # Environment configuration
└── README.md           # This file
```

All scripts in the `scripts/` directory are automatically copied to `/home/$USER_NAME/` during initialization.

## Prerequisites

* A fresh Debian or Ubuntu VPS.
* Root access to the server.
* A domain name pointing to the VPS.
* Basic knowledge of Linux and Docker.

## Installation

### 1. Clone the repository

```bash
git clone https://github.com/AlainPiallat/vps-config.git
cd vps-config
```

### 2. Configure the environment

```bash
cp .env.example .env
nano .env
```

**Main variables:**

* `USER_NAME`: Linux username to create.
* `USER_EMAIL`: Email used for Let's Encrypt.
* `DOMAIN`: Main domain name.
* `VPN_SUBNET`: VPN network (default: 10.13.13.0/24).
* `SSH_PUBLIC_KEY`: Your SSH public key.

### 3. Initialize the system (as root)

```bash
chmod +x init.sh # Make script executable
sudo ./init.sh
```

This will:

* Create the `/etc/vps-config` directory for shared configuration files.
* Create the user account.
* Install Docker and Docker Compose.
* Set up WireGuard VPN.
* Configure UFW and Fail2Ban.
* Harden SSH access.
* Generate the port registry file (`/etc/vps-config/.port`).
* Copy configuration files to `/etc/vps-config`.

> The script is idempotent and can be re-run safely.

### 4. Set up the admin stack (as regular user)

```bash
su USER_NAME
cd ~

./setup.sh
```

This will:

* Create the `~/admin-stack` directory.
* Generate the Traefik configuration.
* Create `docker-compose.yml`.
* Prepare startup scripts.

### 5. Start the stack

```bash
cd ~/admin-stack
./start.sh
```

## VPN Configuration

Once `init.sh` is complete, WireGuard configurations will be generated for your devices.

Display or export configurations with:

```bash
./show-vpn-config.sh
```

To connect:

1. Install WireGuard on your device.
2. Import the configuration file.
3. Enable the VPN tunnel.

## Access to Admin Services

Once connected to the VPN:

* **Traefik Dashboard**: `http://10.13.13.1:8080/dashboard/`
* **Portainer**: `http://10.13.13.1:9000/`

> **Note:** Create your Portainer admin account within the first 5 minutes after startup.

## Security Overview

* Admin interfaces accessible only via VPN.
* Automatic HTTPS certificates via Let's Encrypt.
* Fail2Ban protection against brute-force attacks.
* UFW firewall allowing only necessary ports.
* SSH hardened with key-only authentication.

## Configuration Management

### `/etc/vps-config` Directory

The project creates a dedicated directory `/etc/vps-config` to store shared configuration files:

```
/etc/vps-config/
├── .env              # Environment variables (copy from project)
├── .port             # Port registry file
└── update-ufw.sh     # UFW update script
```

### Port Registry File (`.port`)

The `.port` file is automatically generated during initialization and lists all open ports in the following format:

```
<port> <protocol> <service_name>
```

**Example:**

```
22 tcp SSH
80 tcp HTTP
443 tcp HTTPS
51820 udp WireGuard
```

**Usage:**

* This file is used by the `update-ufw.sh` script to manage firewall rules.
* To add a new port, edit `/etc/vps-config/.port` and run `sudo /etc/vps-config/update-ufw.sh`.
* Comments can be added with `#` at the beginning of a line.
* Service names with spaces are supported (e.g., `8080 tcp Web Application`).

### Updating Firewall Rules

To update UFW rules based on the port registry:

```bash
# Edit the port configuration
sudo nano /etc/vps-config/.port

# Apply the changes
sudo /etc/vps-config/update-ufw.sh
```

This will reset UFW and recreate all rules based on the `.port` file.

## Network Architecture

```
Internet
    │
    ├─── Ports 80/443 ───→ Traefik ───→ Future websites and services
    │
    └─── Port 51820 ───→ WireGuard VPN
                              │
                              └─→ 10.13.13.0/24 (VPN Network)
                                     ├─→ Traefik Dashboard
                                     └─→ Portainer
```

> All containers share an external Docker network named `proxy`, enabling secure internal routing through Traefik.

## Troubleshooting

### VPN not connecting

```bash
sudo systemctl status wg-quick@wg0
sudo journalctl -u wg-quick@wg0 -n 50
```

### Unable to access admin services

```bash
ping 10.13.13.1
docker ps
docker compose logs traefik
```

## Useful Commands

```bash
# Start admin stack
cd ~/admin-stack && ./start.sh

# View logs
docker compose logs -f

# Restart stack
docker compose restart

# Stop stack
docker compose down

# Check VPN status
sudo wg show
```

## Deploying Websites

### Quick Start

Deploy a new website with automatic SSL certificate:

```bash
./new-site.sh [subdomain]
```

**Examples:**

```bash
./new-site.sh blog        # Creates blog.yourdomain.com

./new-site.sh @           # Creates yourdomain.com
```

### What it does

The `new-site.sh` script automatically:

1. Creates a directory structure in `/srv/site-<name>/`
2. Generates a Docker Compose configuration with Apache
3. Creates a welcome HTML page
4. Configures Traefik for automatic HTTPS (Let's Encrypt)
5. Starts the container
6. Verifies the site is accessible

**Note:** Sites are stored in `/srv/` following Linux Filesystem Hierarchy Standard (FHS).

### Directory Structure

```
/srv/site-blog/
├── docker-compose.yml # Docker configuration
├── html/              # Website files (edit here)
│   └── index.html     # Main page
├── logs/              # Apache access and error logs
├── manage.sh          # Quick management script
└── README.md          # Site-specific documentation
```

### Managing Your Sites

Each site includes a `manage.sh` script for common operations:

```bash
cd /srv/site-blog

# Start the site
./manage.sh start

# Stop the site
./manage.sh stop

# Restart the site
./manage.sh restart

# View logs
./manage.sh logs

# Check status
./manage.sh status
```

### Updating Content

1. Edit files in `/srv/site-<name>/html/`
2. Restart the container: `cd /srv/site-<name> && docker compose restart`

### Requirements

- DNS record for the (sub)domain must point to your VPS IP
- Ports 80 and 443 must be open (configured during init.sh)
- Traefik must be running (admin stack)
- Apache containers use port 80 internally, Traefik handles external routing

## Adding Your Own Services

You can deploy your own applications behind Traefik by connecting them to the `proxy` network and adding the required Traefik labels.

Example:

```yaml
services:
  myapp:
    image: nginx:alpine
    networks:
      - proxy
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.myapp.rule=Host(`myapp.yourdomain.com`)"
      - "traefik.http.routers.myapp.entrypoints=websecure"
      - "traefik.http.routers.myapp.tls.certresolver=letsencrypt"

networks:
  proxy:
    external: true
```

## Available Scripts

After initialization, the following scripts are available in your home directory:

| Script | Description |
|--------|-------------|
| `setup.sh` | Set up the admin stack (Traefik + Portainer) |
| `start-admin-stack.sh` | Start the admin stack containers |
| `show-vpn-config.sh` | Display WireGuard VPN configurations |
| `new-site.sh` | Deploy a new Apache website with automatic SSL |
| `update-ufw.sh` | Update firewall rules (requires sudo) |

## Configuration Files

### User Directory (`~/`)
- Scripts and utilities for day-to-day operations

### System Directory (`/etc/vps-config/`)
- `.env` - Environment variables
- `.port` - Port registry for firewall management
- `update-ufw.sh` - Firewall management script

## License

This project is licensed under the **Apache License 2.0** - see the [LICENSE](LICENSE) file for details.

## Disclaimer

This configuration is provided as-is. You are responsible for reviewing and adapting it to your specific use case.

## Acknowledgments

* Based on the work of [thienhaole92](https://medium.com/@thienhaole92/using-wireguard-for-private-vpn-accessing-to-traefik-private-services-3fd57e181879).
* Thanks to the Traefik and WireGuard communities.

## Contact

Alain Piallat - [GitHub](https://github.com/AlainPiallat)
