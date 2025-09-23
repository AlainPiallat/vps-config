#!/bin/bash

# Selective Backup and Restore Script for Docker Services
# This script allows backing up and restoring individual services

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

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

# Load environment variables
source /config/backup.env

# Load Discord notifications if webhook is configured
if [ -n "$NOTIFICATION_URL" ] && [[ "$NOTIFICATION_URL" == *"discord"* ]]; then
    source /opt/docker-services/discord-notifications.sh
fi

# Function to list available services
list_services() {
    echo "Available Docker services for backup:"
    echo "===================================="
    docker volume ls --format "table {{.Name}}" | grep -E "(nextcloud|vaultwarden|grafana|prometheus|portainer|mailserver|traefik)" | sort
}

# Function to backup specific service
backup_service() {
    local service_name="$1"
    if [ -z "$service_name" ]; then
        error "Service name is required"
        echo "Usage: $0 backup <service_name>"
        list_services
        exit 1
    fi

    # Find volumes for the service
    volumes=$(docker volume ls --format "{{.Name}}" | grep "$service_name" | tr '\n' ' ')
    
    if [ -z "$volumes" ]; then
        error "No volumes found for service: $service_name"
        list_services
        exit 1
    fi

    log "Backing up service: $service_name"
    log "Volumes: $volumes"

    # Create service-specific backup
    for volume in $volumes; do
        volume_path="/docker-volumes/$volume"
        if [ -d "$volume_path" ]; then
            log "Backing up volume: $volume"
            restic backup "$volume_path" --tag "service:$service_name" --tag "volume:$volume"
        else
            warning "Volume path not found: $volume_path"
        fi
    done

    success "Backup completed for service: $service_name"
    
    # Send Discord notification if configured
    if [ -n "$NOTIFICATION_URL" ] && [[ "$NOTIFICATION_URL" == *"discord"* ]] && command -v notify_backup_success >/dev/null 2>&1; then
        notify_backup_success "$service_name"
    fi
}

# Function to restore specific service
restore_service() {
    local service_name="$1"
    local snapshot_id="$2"
    
    if [ -z "$service_name" ] || [ -z "$snapshot_id" ]; then
        error "Service name and snapshot ID are required"
        echo "Usage: $0 restore <service_name> <snapshot_id>"
        echo "Use '$0 list-snapshots <service_name>' to find snapshot IDs"
        exit 1
    fi

    log "Restoring service: $service_name from snapshot: $snapshot_id"

    # Stop the service before restore
    warning "Stopping service: $service_name"
    docker-compose -f /opt/docker-services/docker-compose.yml stop "$service_name" || true

    # Restore the snapshot
    restore_path="/restore/$service_name"
    mkdir -p "$restore_path"
    
    restic restore "$snapshot_id" --target "$restore_path"

    # Move restored data back to volume locations
    volumes=$(docker volume ls --format "{{.Name}}" | grep "$service_name")
    for volume in $volumes; do
        volume_path="/docker-volumes/$volume"
        restored_volume_path="$restore_path/docker-volumes/$volume"
        
        if [ -d "$restored_volume_path" ]; then
            log "Restoring volume: $volume"
            sudo rm -rf "$volume_path"
            sudo mv "$restored_volume_path" "$volume_path"
            sudo chown -R 1000:1000 "$volume_path" 2>/dev/null || true
        fi
    done

    # Restart the service
    log "Restarting service: $service_name"
    docker-compose -f /opt/docker-services/docker-compose.yml up -d "$service_name"

    # Cleanup restore directory
    rm -rf "$restore_path"

    success "Restore completed for service: $service_name"
    
    # Send Discord notification if configured
    if [ -n "$NOTIFICATION_URL" ] && [[ "$NOTIFICATION_URL" == *"discord"* ]] && command -v send_discord_notification >/dev/null 2>&1; then
        send_discord_notification "✅ Restore Completed" "Service **$service_name** restored successfully from snapshot $snapshot_id" "3066993" "Success"
    fi
}

# Function to list snapshots for a specific service
list_snapshots() {
    local service_name="$1"
    if [ -z "$service_name" ]; then
        error "Service name is required"
        echo "Usage: $0 list-snapshots <service_name>"
        exit 1
    fi

    log "Snapshots for service: $service_name"
    restic snapshots --tag "service:$service_name" --compact
}

# Function to list all snapshots by service
list_all_snapshots() {
    log "All snapshots by service:"
    echo ""
    
    services=("nextcloud" "vaultwarden" "grafana" "prometheus" "portainer" "mailserver" "traefik")
    
    for service in "${services[@]}"; do
        echo "=== $service ==="
        restic snapshots --tag "service:$service" --compact 2>/dev/null || echo "No snapshots found"
        echo ""
    done
}

# Function to backup all services individually
backup_all_services() {
    log "Starting individual backup for all services"
    
    services=("nextcloud" "vaultwarden" "grafana" "prometheus" "portainer" "mailserver" "traefik")
    
    for service in "${services[@]}"; do
        log "Backing up service: $service"
        if backup_service "$service"; then
            log "Successfully backed up $service"
        else
            warning "Failed to backup $service"
            # Send Discord notification for backup failure
            if [ -n "$NOTIFICATION_URL" ] && [[ "$NOTIFICATION_URL" == *"discord"* ]] && command -v notify_backup_failed >/dev/null 2>&1; then
                notify_backup_failed "$service" "Backup failed during automated backup"
            fi
        fi
    done
    
    success "All services backed up individually"
}

# Main script logic
case "$1" in
    "backup")
        if [ -z "$2" ]; then
            backup_all_services
        else
            backup_service "$2"
        fi
        ;;
    "restore")
        restore_service "$2" "$3"
        ;;
    "list-services")
        list_services
        ;;
    "list-snapshots")
        if [ -z "$2" ]; then
            list_all_snapshots
        else
            list_snapshots "$2"
        fi
        ;;
    *)
        echo "Usage: $0 {backup|restore|list-services|list-snapshots} [arguments]"
        echo ""
        echo "Commands:"
        echo "  backup [service]           - Backup specific service or all services"
        echo "  restore <service> <snap>   - Restore specific service from snapshot"
        echo "  list-services              - List available services"
        echo "  list-snapshots [service]   - List snapshots for service or all"
        echo ""
        echo "Examples:"
        echo "  $0 backup nextcloud        - Backup only Nextcloud"
        echo "  $0 backup                  - Backup all services individually"
        echo "  $0 list-snapshots nextcloud"
        echo "  $0 restore nextcloud abc123"
        exit 1
        ;;
esac