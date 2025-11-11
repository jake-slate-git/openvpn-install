#!/usr/bin/env bash
# firewall_config.sh
# Hardens host firewall with UFW + Fail2Ban, allows SSH (rate-limited), OpenVPN UDP/1194,
# and enables ICMP (ping) the correct UFW way by editing before.rules.

set -euo pipefail

require_root() {
  if [[ $EUID -ne 0 ]]; then
    echo "[!] Please run as root: sudo $0"
    exit 1
  fi
}
require_root

echo "[+] Installing dependencies (ufw, fail2ban)"
apt-get update -y
DEBIAN_FRONTEND=noninteractive apt-get install -y ufw fail2ban

echo "[+] Disable IPv6 in UFW (your host has no IPv6)"
UFW_DEFAULT=/etc/default/ufw
if grep -q '^IPV6=' "$UFW_DEFAULT"; then
  sed -i 's/^IPV6=.*/IPV6=no/' "$UFW_DEFAULT"
else
  echo "IPV6=no" >> "$UFW_DEFAULT"
fi

echo "[+] Reset UFW to a clean state (backups kept)"
ts="$(date +%Y%m%d_%H%M%S)"
mkdir -p /etc/ufw/backups
cp -a /etc/ufw/user.rules "/etc/ufw/backups/user.rules.$ts" 2>/dev/null || true
cp -a /etc/ufw/before.rules "/etc/ufw/backups/before.rules.$ts" 2>/dev/null || true
cp -a /etc/ufw/after.rules  "/etc/ufw/backups/after.rules.$ts"  2>/dev/null || true
cp -a /etc/ufw/user6.rules "/etc/ufw/backups/user6.rules.$ts"  2>/dev/null || true
cp -a /etc/ufw/before6.rules "/etc/ufw/backups/before6.rules.$ts" 2>/dev/null || true
cp -a /etc/ufw/after6.rules  "/etc/ufw/backups/after6.rules.$ts"  2>/dev/null || true
ufw --force reset

echo "[+] Set sane defaults"
ufw default deny incoming
ufw default allow outgoing

echo "[+] Allow SSH (rate-limited)"
# If your SSH is on a non-standard port, change 22/tcp below.
ufw limit 22/tcp comment 'SSH (rate-limited)'

echo "[+] Allow OpenVPN server port (UDP/1194)"
ufw allow 1194/udp comment 'OpenVPN server'

echo "[+] Ensure ICMP (ping) is allowed via before.rules"
# Many distros already whitelist safe ICMP types in before.rules,
# but to be explicit we allow ICMP in/out by adding two rules
# inside the *filter table before COMMIT. This is idempotent.

BEFORE=/etc/ufw/before.rules
if ! grep -q -- "-A ufw-before-input -p icmp -j ACCEPT" "$BEFORE"; then
  cp -a "$BEFORE" "${BEFORE}.pre-icmp.$ts"
  awk '
    BEGIN{added=0}
    # Copy everything, but just before COMMIT in the *filter table, inject our ICMP rules once
    /^\*filter/ { in_filter=1 }
    in_filter && /^COMMIT$/ && !added {
      print "-A ufw-before-input -p icmp -j ACCEPT"
      print "-A ufw-before-output -p icmp -j ACCEPT"
      added=1
    }
    { print }
  ' "${BEFORE}.pre-icmp.$ts" > "${BEFORE}.tmp" && mv "${BEFORE}.tmp" "$BEFORE"
fi

echo "[+] Enable and reload UFW"
ufw --force enable
ufw reload
ufw status verbose

echo "[+] Configure basic Fail2Ban for sshd and openvpn (optional but recommended)"
JAIL=/etc/fail2ban/jail.local
if [[ ! -f "$JAIL" ]]; then
  cat > "$JAIL" <<'EOF'
[DEFAULT]
bantime = 4h
findtime = 5m
maxretry = 50
backend = systemd
destemail = root@localhost
sender = fail2ban@localhost

[sshd]
enabled = true
port = ssh
logpath = %(sshd_log)s
maxretry = 6

[openvpn]
enabled = true
port    = 1194
protocol = udp
logpath = /var/log/openvpn.log
# If your OpenVPN logs to journal, use:
# backend = systemd
# journalmatch = _SYSTEMD_UNIT=openvpn@server.service
EOF
fi

systemctl enable --now fail2ban

echo "[+] Done. UFW + Fail2Ban are active."
echo "[i] If your cloud provider has a network firewall, ensure it also allows: TCP/22, UDP/1194, and ICMP."
