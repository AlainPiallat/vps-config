#!/bin/bash

# Discord Notification Helper Functions
# Source this file in other scripts: source ./discord-notifications.sh

# Send notification to Discord
send_discord_notification() {
    local title="$1"
    local message="$2" 
    local color="$3"  # Green: 3066993, Red: 15158332, Orange: 15105570
    local status="$4"

    if [ -z "$NOTIFICATION_URL" ]; then
        return 0  # Skip if no webhook configured
    fi

    curl -s -X POST "$NOTIFICATION_URL" \
         -H "Content-Type: application/json" \
         -d '{
             "username": "VPS-Bot",
             "embeds": [
                 {
                     "title": "'"$title"'",
                     "description": "'"$message"'",
                     "color": '"$color"',
                     "fields": [
                         {
                             "name": "🖥️ Server",
                             "value": "'"$DOMAIN"'",
                             "inline": true
                         },
                         {
                             "name": "⏰ Time", 
                             "value": "'"$(date +'%Y-%m-%d %H:%M:%S')"'",
                             "inline": true
                         },
                         {
                             "name": "📊 Status",
                             "value": "'"$status"'",
                             "inline": false
                         }
                     ],
                     "footer": {
                         "text": "VPS Monitoring System"
                     }
                 }
             ]
         }' >/dev/null 2>&1
}

# Specific notification functions
notify_backup_success() {
    local service="$1"
    send_discord_notification \
        "✅ Backup Completed" \
        "Backup for **$service** completed successfully" \
        "3066993" \
        "Success"
}

notify_backup_failed() {
    local service="$1"
    local error="$2"
    send_discord_notification \
        "❌ Backup Failed" \
        "Backup for **$service** failed: $error" \
        "15158332" \
        "Failed"
}

notify_service_down() {
    local service="$1"
    send_discord_notification \
        "🚨 Service Down" \
        "Service **$service** is not responding" \
        "15158332" \
        "Critical"
}

notify_ssl_expiring() {
    local domain="$1"
    local days="$2"
    send_discord_notification \
        "⚠️ SSL Certificate Warning" \
        "SSL certificate for **$domain** expires in $days days" \
        "15105570" \
        "Warning"
}

notify_installation_complete() {
    send_discord_notification \
        "🎉 Installation Complete" \
        "VPS installation and configuration completed successfully" \
        "3066993" \
        "Completed"
}