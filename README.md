# VPS Docker Services Configuration

Complete configuration to deploy a secure services stack on VPS.

## Services Included

- **Traefik** - Reverse proxy with automatic SSL
- **Portainer** - Docker management interface (VPN required)
- **Nextcloud AIO** - Collaborative suite
- **Vaultwarden** - Password manager
- **Grafana + Prometheus** - Monitoring (VPN required)
- **Mail Server** - Complete email server
- **WireGuard VPN** - Secure access to admin services
- **Restic + Duplicati** - Backup system
- **UFW Firewall** - Network security

## Installation (No Physical Access Required)

### 1. Clone the repository on your fresh VPS:

```bash
git clone https://github.com/AlainPiallat/vps-config.git
cd vps-config
```

### 2. Configure your settings:

Edit the `.env` file:
```bash
nano .env
```

**Required to modify:**
- `DOMAIN=yourdomain.com`
- `SSH_PUBLIC_KEY=ssh-rsa AAAA...`
- `CLOUDFLARE_EMAIL=your-email@domain.com`
- `CLOUDFLARE_API_TOKEN=your-token`

### 3. Launch installation:

```bash
./install.sh
```

The script automatically configures:
- Secure SSH (custom port, keys, no root)
- UFW firewall 
- Docker + Docker Compose
- All services in containers
- Automatic SSL via Cloudflare
- Secure Docker networks

## Security

### VPN Required Access
These services require VPN connection:
- Portainer (portainer.domain.com)
- Grafana (monitoring.domain.com)  
- Traefik Dashboard (traefik.domain.com)

### WireGuard Configuration
After installation, get client configs:
```bash
sudo docker exec wireguard cat /config/peer1/peer1.conf
```

## Public Services

- **Nextcloud**: https://cloud.yourdomain.com
- **Vaultwarden**: https://vaultwarden.yourdomain.com
- **Email**: mail.yourdomain.com

## Backups

### Automatic Backup
- **Daily** at 2 AM
- **Retention**: 1 daily + 1 weekly + 1 monthly + 1 yearly
- **Docker volumes**: All backed up
- **Web interface**: https://back.yourdomain.com

### Manual Backup
```bash
docker exec restic-backup /scripts/backup.sh
```

### Restoration
```bash
# List snapshots
docker exec restic-backup restic snapshots

# Restore a snapshot
docker exec restic-backup restic restore SNAPSHOT_ID --target /restore
```

### Download Backups Locally
Backups are stored in `/opt/docker-services/backup-data/` on the server.
To download them locally:
```bash
# Via SCP (replace YOUR_VPS_IP and SSH_PORT)
scp -P 2222 user@YOUR_VPS_IP:/opt/docker-services/backup-data/* ./local-backup/

# Or access the backup container directly
docker exec -it restic-backup ls /backups/
```

## Post-Installation Management

### Start/Stop services
```bash
cd /opt/vps-config
docker-compose up -d      # Start
docker-compose down       # Stop
docker-compose restart    # Restart
```

### View logs
```bash
docker-compose logs -f [service-name]
```

### Update services
```bash
docker-compose pull
docker-compose up -d
```

## DNS Configuration

Point these records to your VPS:

| Type | Name | Value |
|------|-----|--------|
| A | @ | VPS_IP |
| A | www | VPS_IP |
| A | cloud | VPS_IP |
| A | vaultwarden | VPS_IP |
| A | mail | VPS_IP |
| A | portainer | VPS_IP |
| A | monitoring | VPS_IP |
| A | traefik | VPS_IP |
| A | back | VPS_IP |
| A | vpn | VPS_IP |
| MX | @ | 10 mail.yourdomain.com |

## Troubleshooting

### Services won't start
```bash
docker-compose ps
docker-compose logs
```

### SSL issues
Check Cloudflare configuration and DNS.

### VPN not working
```bash
docker logs wireguard
# Check UDP port 51820 is open
sudo ufw status | grep 51820
sudo netstat -ulnp | grep 51820
# Test from external
nmap -sU -p 51820 YOUR_VPS_IP
```

### Backup fails
```bash
docker logs restic-backup
# Check disk space
df -h
```

## File Structure

```
/opt/docker-services/
├── docker-compose.yml          # Main configuration
├── .env                        # Environment variables
├── install.sh                  # Installation script
├── traefik/
│   ├── traefik.yml            # Traefik config
│   └── dynamic/
│       └── middlewares.yml    # Middlewares (VPN whitelist)
├── monitoring/
│   ├── prometheus.yml         # Prometheus config
│   └── grafana.ini           # Grafana config
├── vaultwarden/
│   └── config.json           # Vaultwarden config
├── backup/
│   ├── scripts/
│   │   ├── backup.sh         # Backup script
│   │   └── backup-cron.sh    # Backup cron
│   └── config/
└── vpn/
    └── config/               # WireGuard client configs
```

## Performance

### Recommended Resources
- **RAM**: 4GB minimum, 8GB recommended
- **CPU**: 2 cores minimum
- **Storage**: 50GB minimum (SSD recommended)
- **Bandwidth**: Unlimited recommended

### Optimizations
- Docker volumes for persistence
- Separate Docker networks for security
- Incremental backups with compression
- SSL/TLS with certificate caching

## Useful Commands

```bash
# Check services status
docker ps
docker-compose ps

# View service logs
docker logs traefik
docker logs nextcloud-aio-mastercontainer
docker logs grafana

# Restart a service
docker-compose restart traefik

# Check Traefik configuration
curl -H "Host: traefik.yourdomain.com" http://localhost:8080/api/rawdata

# VPN port testing
sudo ufw status | grep 51820
sudo netstat -ulnp | grep 51820
nmap -sU -p 51820 YOUR_VPS_IP

# Manual backup
cd /opt/server-config/backup
./scripts/selective-backup.sh backup nextcloud

# Snapshot management
./scripts/selective-backup.sh list
./scripts/selective-backup.sh restore nextcloud <snapshot-id>
```