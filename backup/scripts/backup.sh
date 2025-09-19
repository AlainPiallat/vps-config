#!/bin/bash

# Restic Backup Script for Docker Volumes
# This script backs up all Docker volumes and important system files

set -e

# Load environment variables
source /config/backup.env

# Initialize repository if it doesn't exist
if ! restic snapshots &>/dev/null; then
    echo "Initializing restic repository..."
    restic init
fi

# Function to backup with error handling
backup_with_retry() {
    local path="$1"
    local tag="$2"
    local max_retries=3
    local retry=0

    while [ $retry -lt $max_retries ]; do
        if restic backup "$path" --tag "$tag" --exclude-caches --exclude-file=/config/exclude.txt; then
            echo "Backup successful for $path"
            return 0
        else
            retry=$((retry + 1))
            echo "Backup failed for $path, retry $retry/$max_retries"
            sleep 30
        fi
    done
    
    echo "Backup failed for $path after $max_retries attempts"
    return 1
}

# Backup Docker volumes
echo "Starting Docker volumes backup..."
backup_with_retry "/docker-volumes" "docker-volumes"

# Backup important configuration files
echo "Starting configuration backup..."
backup_with_retry "/config" "configuration"

# Clean old snapshots (keep 1 daily, 1 weekly, 1 monthly, 1 yearly)
echo "Cleaning old snapshots..."
restic forget --keep-daily 1 --keep-weekly 1 --keep-monthly 1 --keep-yearly 1 --prune

# Check repository integrity weekly (only on Sundays)
if [ "$(date +%u)" -eq 7 ]; then
    echo "Running repository check..."
    restic check
fi

echo "Backup completed successfully at $(date)"

# Send notification (optional)
if [ -n "$NOTIFICATION_URL" ]; then
    curl -X POST "$NOTIFICATION_URL" \
         -H "Content-Type: application/json" \
         -d "{\"text\":\"Backup completed successfully at $(date)\"}"
fi