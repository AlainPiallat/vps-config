#!/bin/bash

# Test Discord Webhook
# Usage: ./test-discord-webhook.sh

# Load environment variables
source .env

if [ -z "$NOTIFICATION_URL" ]; then
    echo "❌ NOTIFICATION_URL is not set in .env file"
    exit 1
fi

echo "🔔 Testing Discord webhook..."

# Test message
curl -X POST "$NOTIFICATION_URL" \
     -H "Content-Type: application/json" \
     -d '{
         "username": "VPS-Bot",
         "avatar_url": "https://cdn.discordapp.com/attachments/123/456/server-icon.png",
         "embeds": [
             {
                 "title": "🧪 Test Notification",
                 "description": "Webhook configuration test from your VPS",
                 "color": 3066993,
                 "fields": [
                     {
                         "name": "📊 Server",
                         "value": "'"$DOMAIN"'",
                         "inline": true
                     },
                     {
                         "name": "⏰ Time",
                         "value": "'"$(date)"'",
                         "inline": true
                     },
                     {
                         "name": "✅ Status",
                         "value": "Webhook working correctly!",
                         "inline": false
                     }
                 ],
                 "footer": {
                     "text": "VPS Monitoring System"
                 }
             }
         ]
     }'

if [ $? -eq 0 ]; then
    echo "✅ Test message sent successfully!"
    echo "Check your Discord channel for the notification."
else
    echo "❌ Failed to send test message"
    echo "Please check your NOTIFICATION_URL in .env file"
fi