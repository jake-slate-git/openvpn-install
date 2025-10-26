#!/bin/bash

# --- This script must be run as root! ---
if [ "$EUID" -ne 0 ]; then
  echo "Please run this script as root or with sudo"
  exit 1
fi

CONFIG_FILE="/etc/openvpn/server.conf"

echo "--- 1. Installing bridge-utils and iproute2 ---"
apt-get update
apt-get install -y iproute2 bridge-utils

echo "--- 2. Creating network bridge 'br0' ---"
# Create dummy interface and bridge, ignoring errors if they already exist
ip link add dummy0 type dummy || true
ip link add name br0 type bridge || true

# Configure the bridge IP and bring interfaces up
ip addr add 191.168.98.1/24 dev br0
ip link set dummy0 master br0
ip link set dummy0 up
ip link set br0 up

echo "--- 3. Backing up and editing $CONFIG_FILE ---"
# Create a timestamped backup just in case
cp "$CONFIG_FILE" "$CONFIG_FILE.bak-$(date +%F)"
echo "Backup created at $CONFIG_FILE.bak-$(date +%F)"

# Use sed to find and replace/comment the required lines.
# This is safer than just appending, as it modifies the lines in-place.
sed -i \
    -e 's/^[[:space:]]*dev tun/dev tap/' \
    -e 's/^[[:space:]]*topology subnet/#topology subnet/' \
    -e 's/^[[:space:]]*server 10.8.0.1.1 255.255.255.0/server-bridge 192.168.98.1 255.255.255.0 192.168.98.5 192.168.98.100/' \
    "$CONFIG_FILE"

echo "--- 4. Appending bridge-up/down scripts to config ---"
# Use a "Here Document" (EOF) to safely append the multi-line block.
# This avoids any issues with quotes.
tee -a "$CONFIG_FILE" > /dev/null <<EOF

# --- Auto-attach tap0 -> br0 ---
script-security 2
up "/bin/sh -c 'ip link set \${dev} master br0; ip link set \${dev} up'"
down-pre
down "/bin/sh -c 'ip link set \${dev} nomaster || true'"
EOF

echo "--- All done! ---"
echo ""
echo "IMPORTANT: You must RESTART the OpenVPN service to apply changes:"
echo "sudo systemctl restart openvpn@server.service"
