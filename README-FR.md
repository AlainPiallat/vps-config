# Configuration Services Docker VPS

Configuration complète pour déployer une stack de services sécurisée sur VPS.

## Services Inclus

- **Traefik** - Reverse proxy avec SSL automatique
- **Portainer** - Interface de gestion Docker (VPN requis)
- **Nextcloud AIO** - Suite collaborative
- **Vaultwarden** - Gestionnaire de mots de passe
- **Grafana + Prometheus** - Monitoring (VPN requis)
- **Mail Server** - Serveur email complet
- **WireGuard VPN** - Accès sécurisé aux services admin
- **Restic + Duplicati** - Système de backup
- **UFW Firewall** - Sécurisation réseau

## Installation (Sans Accès Physique)

### Prérequis

**⚠️ IMPORTANT : Mettez à jour votre système d'abord**
```bash
sudo apt update && sudo apt upgrade -y
sudo reboot  # Si des mises à jour du noyau ont été installées
```

### 1. Cloner le repository sur votre VPS fraîchement installé :

```bash
git clone https://github.com/AlainPiallat/vps-config.git
cd vps-config
```

### 2. Configurer vos paramètres :

Éditer le fichier `.env` :
```bash
nano .env
```

**Obligatoire à modifier :**
- `DOMAIN=votredomaine.fr`
- `SSH_PUBLIC_KEY=ssh-rsa AAAA...`
- `CLOUDFLARE_EMAIL=votre-email@domain.com`
- `CLOUDFLARE_API_TOKEN=your-token`

### 3. Lancer l'installation :

Rendre le script exécutable et le lancer :

```bash
chmod +x install.sh
./install.sh
```

Le script configure automatiquement :
- SSH sécurisé (port personnalisé, clés, pas de root)
- Firewall UFW 
- Docker + Docker Compose
- Tous les services en containers
- SSL automatique via Cloudflare
- Réseaux Docker sécurisés

## Sécurité

### Accès VPN Requis
Ces services nécessitent une connexion VPN :
- Portainer (portainer.domain.fr)
- Grafana (monitoring.domain.fr)  
- Traefik Dashboard (traefik.domain.fr)

### Configuration WireGuard
Après installation, récupérer les configs clients :
```bash
sudo docker exec wireguard cat /config/peer1/peer1.conf
```

## Services Publics

- **Nextcloud** : https://cloud.votredomaine.fr
- **Vaultwarden** : https://vaultwarden.votredomaine.fr
- **Email** : mail.votredomaine.fr

## Sauvegardes

### Backup Automatique
- **Quotidien** à 2h du matin
- **Rétention** : 30 quotidiens + 12 hebdomadaires + 12 mensuels
- **Volumes Docker** : Tous sauvegardés
- **Interface Web** : https://back.votredomaine.fr

### Backup Manuel
```bash
docker exec restic-backup /scripts/backup.sh
```

### Restauration
```bash
# Lister les snapshots
docker exec restic-backup restic snapshots

# Restaurer un snapshot
docker exec restic-backup restic restore SNAPSHOT_ID --target /restore
```

### Télécharger les Backups Localement
Les sauvegardes sont stockées dans `/opt/docker-services/backup-data/` sur le serveur.
Pour les télécharger localement :
```bash
# Via SCP (remplacer YOUR_VPS_IP et SSH_PORT)
scp -P 2222 user@YOUR_VPS_IP:/opt/docker-services/backup-data/* ./backup-local/

# Ou accéder directement au conteneur de backup
docker exec -it restic-backup ls /backups/
```

## Gestion Post-Installation

### Démarrer/Arrêter les services
```bash
cd /opt/vps-config
docker-compose up -d      # Démarrer
docker-compose down       # Arrêter
docker-compose restart    # Redémarrer
```

### Voir les logs
```bash
docker-compose logs -f [service-name]
```

### Mettre à jour les services
```bash
docker-compose pull
docker-compose up -d
```

## Configuration DNS

Pointer ces enregistrements vers votre VPS :

| Type | Nom | Valeur |
|------|-----|--------|
| A | @ | IP_VPS |
| A | www | IP_VPS |
| A | cloud | IP_VPS |
| A | vaultwarden | IP_VPS |
| A | mail | IP_VPS |
| A | portainer | IP_VPS |
| A | monitoring | IP_VPS |
| A | traefik | IP_VPS |
| A | back | IP_VPS |
| A | vpn | IP_VPS |
| MX | @ | 10 mail.votredomaine.fr |

## Dépannage

### Services ne démarrent pas
```bash
docker-compose ps
docker-compose logs
```

### Problème SSL
Vérifier la configuration Cloudflare et les DNS.

### VPN ne fonctionne pas
```bash
docker logs wireguard
# Vérifier le port 51820 UDP ouvert
sudo ufw status | grep 51820
sudo netstat -ulnp | grep 51820
# Test depuis l'extérieur
nmap -sU -p 51820 YOUR_VPS_IP
```

### Backup échoue
```bash
docker logs restic-backup
# Vérifier l'espace disque
df -h
```

## Structure des Fichiers

```
/opt/docker-services/
├── docker-compose.yml          # Configuration principale
├── .env                        # Variables d'environnement
├── install.sh                  # Script d'installation
├── traefik/
│   ├── traefik.yml            # Config Traefik
│   └── dynamic/
│       └── middlewares.yml    # Middlewares (VPN whitelist)
├── monitoring/
│   ├── prometheus.yml         # Config Prometheus
│   └── grafana.ini           # Config Grafana
├── vaultwarden/
│   └── config.json           # Config Vaultwarden
├── backup/
│   ├── scripts/
│   │   ├── backup.sh         # Script de backup
│   │   └── backup-cron.sh    # Cron pour backup
│   └── config/
└── vpn/
    └── config/               # Configs WireGuard clients
```

## Performance

### Ressources Recommandées
- **RAM** : 4GB minimum, 8GB recommandé
- **CPU** : 2 cores minimum
- **Stockage** : 50GB minimum (SSD recommandé)
- **Bande passante** : Illimitée recommandée

### Optimisations
- Volumes Docker pour la persistence
- Réseaux Docker séparés pour la sécurité
- Backup incrémentaux avec compression
- SSL/TLS avec cache de certificats

## Commandes Utiles

```bash
# Vérifier l'état des services
docker ps
docker-compose ps

# Logs des services
docker logs traefik
docker logs nextcloud-aio-mastercontainer
docker logs grafana

# Redémarrer un service
docker-compose restart traefik

# Vérifier la configuration Traefik
curl -H "Host: traefik.votre-domaine.com" http://localhost:8080/api/rawdata

# Test des ports VPN
sudo ufw status | grep 51820
sudo netstat -ulnp | grep 51820
nmap -sU -p 51820 YOUR_VPS_IP

# Backup manuel
cd /opt/server-config/backup
./scripts/selective-backup.sh backup nextcloud

# Gestion des snapshots
./scripts/selective-backup.sh list
./scripts/selective-backup.sh restore nextcloud <snapshot-id>
```

## Notifications Discord

Le système peut envoyer des notifications Discord pour les événements importants :

### Configuration

Ajoutez votre URL webhook Discord au fichier `.env` :
```bash
NOTIFICATION_URL=https://discord.com/api/webhooks/VOTRE_WEBHOOK_URL
```

### Événements Notifiés

- **Fin d'installation** - Configuration VPS terminée
- **Succès/Échec de backup** - Sauvegardes automatiques et manuelles
- **Restauration de service** - Quand les services sont restaurés depuis une sauvegarde
- **Alertes système** - Événements système critiques

### Configuration du Webhook

1. Créer un webhook Discord dans votre serveur :
   - Aller dans Paramètres du Serveur → Intégrations → Webhooks
   - Cliquer sur "Nouveau Webhook"
   - Choisir le canal et copier l'URL du webhook

2. Ajouter l'URL dans votre fichier `.env` :
   ```bash
   NOTIFICATION_URL=https://discord.com/api/webhooks/123456789/abcdefghijklmnop
   ```

### Test des Notifications

Tester votre webhook Discord :
```bash
cd /opt/docker-services
./test-discord-webhook.sh
```

**Note** : Les notifications ne fonctionnent qu'avec les webhooks Discord pour l'instant. Les autres types de webhooks seront ignorés tant qu'il ne seront pas ajouter au script.