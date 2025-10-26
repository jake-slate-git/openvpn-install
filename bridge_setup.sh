#!/bin/bash

# --- This script must be run as root! ---
if [ "$EUID" -ne 0 ]; then
  echo "Please run this script as root or with sudo"
  exit 1
fi

CONFIG_FILE="/etc/openvpn/server.conf"
BRIDGE_IF="br0"
DUMMY_IF="dummy0"
BRIDGE_IP="192.168.98.1"
BRIDGE_CIDR="192.168.98.1/24"
BRIDGE_NETMASK="255.255.255.0"
POOL_START="192.168.98.5"
POOL_END="192.168.98.100"
SYSTEMD_NETWORK_DIR="/etc/systemd/network"

echo "--- 1. Installing bridge-utils and iproute2 ---"
apt-get update
apt-get install -y iproute2 bridge-utils

echo "--- 2. Creating network bridge '$BRIDGE_IF' ---"
# Create dummy interface and bridge, ignoring errors if they already exist
ip link add "$DUMMY_IF" type dummy || true
ip link add name "$BRIDGE_IF" type bridge || true

# Configure the bridge IP and bring interfaces up for the current session
ip addr replace "$BRIDGE_CIDR" dev "$BRIDGE_IF"
ip link set "$DUMMY_IF" master "$BRIDGE_IF"
ip link set "$DUMMY_IF" up
ip link set "$BRIDGE_IF" up

echo "--- 3. Configuring systemd-networkd for persistent bridge ---"
mkdir -p "$SYSTEMD_NETWORK_DIR"

cat >"$SYSTEMD_NETWORK_DIR/$DUMMY_IF.netdev" <<EOF
[NetDev]
Name=$DUMMY_IF
Kind=dummy
EOF

cat >"$SYSTEMD_NETWORK_DIR/$BRIDGE_IF.netdev" <<EOF
[NetDev]
Name=$BRIDGE_IF
Kind=bridge
EOF

cat >"$SYSTEMD_NETWORK_DIR/$DUMMY_IF.network" <<EOF
[Match]
Name=$DUMMY_IF

[Network]
Bridge=$BRIDGE_IF
EOF

cat >"$SYSTEMD_NETWORK_DIR/$BRIDGE_IF.network" <<EOF
[Match]
Name=$BRIDGE_IF

[Network]
Address=$BRIDGE_CIDR
EOF

if command -v systemctl >/dev/null 2>&1; then
  systemctl enable --now systemd-networkd
  systemctl restart systemd-networkd
else
  echo "systemctl not found. Please ensure $BRIDGE_IF is configured to start on boot manually."
fi

echo "--- 4. Backing up and editing $CONFIG_FILE ---"
# Create a timestamped backup just in case
cp "$CONFIG_FILE" "$CONFIG_FILE.bak-$(date +%F)"
echo "Backup created at $CONFIG_FILE.bak-$(date +%F)"

# Use sed to find and replace/comment the required lines.
# This is safer than just appending, as it modifies the lines in-place.
sed -i \
    -e 's/^[[:space:]]*dev tun/dev tap/' \
    -e 's/^[[:space:]]*topology subnet/#topology subnet/' \
    -e "s/^[[:space:]]*server-bridge .*/server-bridge $BRIDGE_IP $BRIDGE_NETMASK $POOL_START $POOL_END/" \
    -e "s/^[[:space:]]*server 10\\.8\\.0\\.0 255\\.255\\.255\\.0/server-bridge $BRIDGE_IP $BRIDGE_NETMASK $POOL_START $POOL_END/" \
    "$CONFIG_FILE"

echo "--- 5. Appending bridge-up/down scripts to config ---"
# Use a "Here Document" (EOF) to safely append the multi-line block.
# This avoids any issues with quotes.
tee -a "$CONFIG_FILE" > /dev/null <<EOF

# --- Auto-attach tap0 -> $BRIDGE_IF ---
script-security 2
up "/bin/sh -c 'ip link set \${dev} master $BRIDGE_IF; ip link set \${dev} up'"
down-pre
down "/bin/sh -c 'ip link set \${dev} nomaster || true'"
EOF

echo "--- All done! ---"
echo ""
echo "IMPORTANT: You must RESTART the OpenVPN service to apply changes:"
echo "sudo systemctl restart openvpn@server.service"
