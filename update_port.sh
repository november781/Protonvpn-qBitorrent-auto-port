#!/bin/bash

# Configuration
PORT_FILE="/run/user/1000/Proton/VPN/forwarded_port"
STATE_FILE="/etc/qbt_last_port"
QBT_URL="http://localhost:8080"
ZONE="dmz"

# Read the file and trim any whitespace/newlines
NEW_PORT=$(tr -d '[:space:]' < "$PORT_FILE")
OLD_PORT=$(cat "$STATE_FILE" 2>/dev/null)

# CASE 1: The file is blank (VPN starting/switching)
if [[ -z "$NEW_PORT" ]]; then
    echo "Port file is blank. VPN is likely transitioning."
    
    if [[ -n "$OLD_PORT" ]]; then
        echo "Closing old firewall port: $OLD_PORT"
        firewall-cmd --zone="$ZONE" --remove-port="$OLD_PORT/tcp" --remove-port="$OLD_PORT/udp"
        rm "$STATE_FILE"
    fi
    exit 0
fi

# CASE 2: Invalid data (Not a number)
if [[ ! "$NEW_PORT" =~ ^[0-9]+$ ]]; then
    echo "Error: Non-numeric data in port file: '$NEW_PORT'"
    exit 1
fi

# CASE 3: Port is valid and has changed
if [[ "$NEW_PORT" != "$OLD_PORT" ]]; then
    # Remove old rule if it exists
    if [[ -n "$OLD_PORT" ]]; then
        echo "Removing old firewall rule: $OLD_PORT"
        firewall-cmd --zone="$ZONE" --remove-port="$OLD_PORT/tcp" --remove-port="$OLD_PORT/udp"
    fi

    # Add new rule
    echo "Opening new firewall port: $NEW_PORT"
    firewall-cmd --zone="$ZONE" --add-port="$NEW_PORT/tcp" --add-port="$NEW_PORT/udp"

    # Update qBittorrent via Web API
    echo "Updating qBittorrent listening port to: $NEW_PORT"
    curl -s -i -X POST \
        --header "Referer: $QBT_URL" \
        --data "json={\"listen_port\": $NEW_PORT}" \
        "$QBT_URL/api/v2/app/setPreferences" > /dev/null

    # Save the new port to state file
    echo "$NEW_PORT" > "$STATE_FILE"
else
    echo "Port $NEW_PORT is already configured. No action needed."
fi
