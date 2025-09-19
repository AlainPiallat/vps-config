#!/bin/bash

# Setup cron for automated backups

# Create cron schedule
echo "0 2 * * * /scripts/backup.sh >> /var/log/backup.log 2>&1" > /var/spool/cron/crontabs/root

# Start cron daemon
crond -f