#!/bin/bash

# Set absolute paths
CERTBOT_PATH="/usr/bin/certbot"
PM2_PATH="/usr/bin/pm2"
SSL_SOURCE_DIR="/etc/letsencrypt/live/levynger.farted.net"
SSL_DEST_DIR="/opt/GustoSchedule/ssl"
APP_USER="levynger"

# Log file for debugging
LOG_FILE="/opt/GustoSchedule/certbot_renewal.log"

# Function to log messages
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

# Start logging
log_message "Starting certificate renewal process"

# Stop PM2 as levynger
if ! sudo -u $APP_USER $PM2_PATH stop 0; then
    log_message "Error: Failed to stop PM2"
    exit 1
fi
log_message "PM2 stopped successfully"

# Wait a second for port 80 to free
sleep 2

# Run certbot as root
if ! $CERTBOT_PATH renew --quiet; then
    log_message "Error: Certificate renewal failed"
    # Try to restart PM2 even if renewal failed
    sudo -u $APP_USER $PM2_PATH start 0
    exit 1
fi
log_message "Certificate renewal completed"

# Create SSL directory if it doesn't exist
if [ ! -d "$SSL_DEST_DIR" ]; then
    if ! sudo mkdir -p "$SSL_DEST_DIR"; then
        log_message "Error: Failed to create SSL directory"
        exit 1
    fi
    log_message "Created SSL directory"
fi

# Copy the renewed certificates
if ! sudo cp "$SSL_SOURCE_DIR/privkey.pem" "$SSL_DEST_DIR/"; then
    log_message "Error: Failed to copy privkey.pem"
    exit 1
fi

if ! sudo cp "$SSL_SOURCE_DIR/fullchain.pem" "$SSL_DEST_DIR/"; then
    log_message "Error: Failed to copy fullchain.pem"
    exit 1
fi
log_message "Certificates copied successfully"

# Set correct permissions
if ! sudo chown $APP_USER:$APP_USER "$SSL_DEST_DIR/privkey.pem" "$SSL_DEST_DIR/fullchain.pem"; then
    log_message "Error: Failed to set ownership"
    exit 1
fi

if ! sudo chmod 600 "$SSL_DEST_DIR/privkey.pem"; then
    log_message "Error: Failed to set privkey.pem permissions"
    exit 1
fi

if ! sudo chmod 644 "$SSL_DEST_DIR/fullchain.pem"; then
    log_message "Error: Failed to set fullchain.pem permissions"
    exit 1
fi
log_message "Permissions set successfully"

# Restart PM2 as levynger
if ! sudo -u $APP_USER $PM2_PATH start 0; then
    log_message "Error: Failed to restart PM2"
    exit 1
fi
log_message "PM2 restarted successfully"
