#!/bin/bash

# --- This script must be run as root! ---
if [ "$EUID" -ne 0 ]; then
  echo "Please run this script as root or with sudo"
  exit 1
fi

CONFIG_FILE="/etc/openvpn/server.conf"
SYSTEMD_NETWORK_DIR="/etc/systemd/network"

echo "--- 1. Installing bridge-utils and iproute2 ---"
apt-get update
apt-get install -y iproute2 bridge-utils

echo "--- 2. Creating network bridge 'br0' ---"
# Create dummy interface and bridge, ignoring errors if they already exist
ip link add "dummy0" type dummy || true
ip link add name "br0" type bridge || true

# Configure the bridge IP and bring interfaces up for the current session
ip addr replace "192.168.98.1/24" dev "br0"
ip link set "dummy0" master "br0"
ip link set "dummy0" up
ip link set "br0" up

echo "--- 3. Configuring systemd-networkd for persistent bridge ---"
mkdir -p "$SYSTEMD_NETWORK_DIR"

cat >"$SYSTEMD_NETWORK_DIR/dummy0.netdev" <<EOF
[NetDev]
Name=dummy0
Kind=dummy
EOF

cat >"$SYSTEMD_NETWORK_DIR/br0.netdev" <<EOF
[NetDev]
Name=br0
Kind=bridge
EOF

cat >"$SYSTEMD_NETWORK_DIR/dummy0.network" <<EOF
[Match]
Name=dummy0

[Network]
Bridge=br0
EOF

cat >"$SYSTEMD_NETWORK_DIR/br0.network" <<EOF
[Match]
Name=br0

[Network]
Address=192.168.98.1/24
EOF

if command -v systemctl >/dev/null 2>&1; then
  systemctl enable --now systemd-networkd
  systemctl restart systemd-networkd
else
  echo "systemctl not found. Please ensure br0 is configured to start on boot manually."
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
    -e "s/^[[:space:]]*server-bridge .*/server-bridge 192.168.98.1 255.255.255.0 192.168.98.5 192.168.98.100/" \
    -e "s/^[[:space:]]*server 10\\.8\\.0\\.0 255\\.255\\.255\\.0/server-bridge 192.168.98.1 255.255.255.0 192.168.98.5 192.168.98.100/" \
    "$CONFIG_FILE"

echo "--- 5. Appending bridge-up/down scripts to config ---"
# Ensure client-to-client is enabled for bridged peer communication
if ! grep -qE '^[[:space:]]*client-to-client' "$CONFIG_FILE"; then
  echo "client-to-client" >>"$CONFIG_FILE"
fi

# Use a "Here Document" (EOF) to safely append the multi-line block.
# This avoids any issues with quotes.
tee -a "$CONFIG_FILE" > /dev/null <<EOF

# --- Auto-attach tap0 -> br0 ---
script-security 2
up "/bin/sh -c 'ip link set \${dev} master br0; ip link set \${dev} up'"
down-pre
down "/bin/sh -c 'ip link set \${dev} nomaster || true'"
EOF

echo "--- 6. Updating firewall helper scripts for bridge mode ---"
ADD_RULES="/etc/iptables/add-openvpn-rules.sh"
RM_RULES="/etc/iptables/rm-openvpn-rules.sh"

if [ -f "$ADD_RULES" ] && [ -f "$RM_RULES" ]; then
  ADD_CONTENT=$(cat "$ADD_RULES")
  RM_CONTENT=$(cat "$RM_RULES")

  IPV4_PORT_ADD=$(printf '%s\n' "$ADD_CONTENT" | awk '/^iptables/ && /--dport/ {print; exit}')
  IPV4_PORT_REMOVE=$(printf '%s\n' "$RM_CONTENT" | awk '/^iptables/ && /--dport/ {print; exit}')

  if printf '%s\n' "$ADD_CONTENT" | grep -q '^ip6tables'; then
    HAS_IPV6_RULES=1
    IPV6_PORT_ADD=$(printf '%s\n' "$ADD_CONTENT" | awk '/^ip6tables/ && /--dport/ {print; exit}')
    IPV6_PORT_REMOVE=$(printf '%s\n' "$RM_CONTENT" | awk '/^ip6tables/ && /--dport/ {print; exit}')
  else
    HAS_IPV6_RULES=0
  fi

  cat >"$ADD_RULES" <<'EOR'
#!/bin/sh
iptables -I INPUT 1 -i tap+ -j ACCEPT
iptables -I INPUT 1 -i br0 -j ACCEPT
iptables -I FORWARD 1 -i tap+ -o br0 -j ACCEPT
iptables -I FORWARD 1 -i br0 -o tap+ -j ACCEPT
EOR

  if [ -n "$IPV4_PORT_ADD" ]; then
    printf '%s\n' "$IPV4_PORT_ADD" >>"$ADD_RULES"
  fi

  if [ "$HAS_IPV6_RULES" -eq 1 ]; then
    cat >>"$ADD_RULES" <<'EOR'
ip6tables -I INPUT 1 -i tap+ -j ACCEPT
ip6tables -I INPUT 1 -i br0 -j ACCEPT
ip6tables -I FORWARD 1 -i tap+ -o br0 -j ACCEPT
ip6tables -I FORWARD 1 -i br0 -o tap+ -j ACCEPT
EOR

    if [ -n "$IPV6_PORT_ADD" ]; then
      printf '%s\n' "$IPV6_PORT_ADD" >>"$ADD_RULES"
    fi
  fi

  cat >"$RM_RULES" <<'EOR'
#!/bin/sh
iptables -D INPUT -i tap+ -j ACCEPT
iptables -D INPUT -i br0 -j ACCEPT
iptables -D FORWARD -i tap+ -o br0 -j ACCEPT
iptables -D FORWARD -i br0 -o tap+ -j ACCEPT
EOR

  if [ -n "$IPV4_PORT_REMOVE" ]; then
    printf '%s\n' "$IPV4_PORT_REMOVE" >>"$RM_RULES"
  fi

  if [ "$HAS_IPV6_RULES" -eq 1 ]; then
    cat >>"$RM_RULES" <<'EOR'
ip6tables -D INPUT -i tap+ -j ACCEPT
ip6tables -D INPUT -i br0 -j ACCEPT
ip6tables -D FORWARD -i tap+ -o br0 -j ACCEPT
ip6tables -D FORWARD -i br0 -o tap+ -j ACCEPT
EOR

    if [ -n "$IPV6_PORT_REMOVE" ]; then
      printf '%s\n' "$IPV6_PORT_REMOVE" >>"$RM_RULES"
    fi
  fi

  chmod +x "$ADD_RULES" "$RM_RULES"

  if command -v systemctl >/dev/null 2>&1 && [ -f /etc/systemd/system/iptables-openvpn.service ]; then
    systemctl daemon-reload
    systemctl restart iptables-openvpn || true
  fi
else
  echo "Skipping firewall helper update: $ADD_RULES or $RM_RULES missing"
fi

echo "--- 7. Disabling bridge netfilter hooks ---"
modprobe br_netfilter 2>/dev/null || true
mkdir -p /etc/sysctl.d
cat >/etc/sysctl.d/99-openvpn-bridge.conf <<'EOR'
net.bridge.bridge-nf-call-iptables = 0
net.bridge.bridge-nf-call-ip6tables = 0
net.bridge.bridge-nf-call-arptables = 0
EOR
sysctl --system

echo "--- All done! ---"
echo ""
echo "IMPORTANT: You must RESTART the OpenVPN service to apply changes:"
echo "sudo systemctl restart openvpn@server.service"
sudo systemctl restart openvpn@server.service
