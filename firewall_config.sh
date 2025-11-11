#!/usr/bin/env bash
set -euo pipefail

stamp() { date +"%Y%m%d_%H%M%S"; }

echo "[+] Ensure UFW is installed"
sudo apt-get update -y
sudo apt-get install -y ufw

echo "[+] Disable IPv6 in UFW (your host has no IPv6)"
sudo sed -ri 's/^IPV6=.*/IPV6=no/' /etc/ufw/ufw.conf || true

echo "[+] Reset UFW to a clean state (backups kept)"
sudo cp -a /etc/ufw/user.rules      /etc/ufw/user.rules.$(stamp)      2>/dev/null || true
sudo cp -a /etc/ufw/before.rules    /etc/ufw/before.rules.$(stamp)    2>/dev/null || true
sudo cp -a /etc/ufw/after.rules     /etc/ufw/after.rules.$(stamp)     2>/dev/null || true
sudo cp -a /etc/ufw/user6.rules     /etc/ufw/user6.rules.$(stamp)     2>/dev/null || true
sudo cp -a /etc/ufw/before6.rules   /etc/ufw/before6.rules.$(stamp)   2>/dev/null || true
sudo cp -a /etc/ufw/after6.rules    /etc/ufw/after6.rules.$(stamp)    2>/dev/null || true
sudo ufw --force reset

echo "[+] Set sane defaults"
sudo ufw default deny incoming
sudo ufw default allow outgoing

echo "[+] Allow SSH (rate-limited)"
# If your SSH port is nonstandard, replace 22/tcp with that port
sudo ufw limit 22/tcp comment 'SSH (rate-limited)'

echo "[+] Allow OpenVPN server port (UDP/1194)"
sudo ufw allow 1194/udp comment 'OpenVPN server'

echo "[+] Allow ICMP (ping) in both directions"
sudo ufw allow in  proto icmp from any to any comment 'ICMP inbound'
sudo ufw allow out proto icmp from any to any comment 'ICMP outbound'

echo "[+] Enable and show status"
sudo ufw --force enable
sudo ufw reload
sudo ufw status verbose


echo "[+] Installing fail2ban"
sudo apt update -y
sudo apt install -y fail2ban

echo "[+] Configuring fail2ban for SSH"
sudo tee /etc/fail2ban/jail.local >/dev/null <<EOF
[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 15
bantime = 10m
findtime = 10m
EOF

echo "[+] Restarting fail2ban"
sudo systemctl enable --now fail2ban
sudo systemctl restart fail2ban

echo "[+] Firewall + fail2ban configuration complete."

echo
echo "=== CURRENT FIREWALL STATUS ==="
sudo ufw status verbose

echo
echo "=== FAIL2BAN STATUS (SSH) ==="
sudo fail2ban-client status sshd
