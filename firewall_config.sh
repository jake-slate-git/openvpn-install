#!/usr/bin/env bash
set -euo pipefail

sudo apt install ufw -y

echo "[+] Disabling IPv6 in UFW"
sudo sed -i 's/IPV6=.*/IPV6=no/g' /etc/ufw/ufw.conf

echo "[+] Resetting UFW"
sudo ufw --force reset

echo "[+] Setting default policies"
sudo ufw default deny incoming
sudo ufw default allow outgoing

echo "[+] Allowing SSH (rate-limited)"
sudo ufw limit 22/tcp comment "Allow and rate-limit SSH"

echo "[+] Allowing OpenVPN UDP 1194"
sudo ufw allow 1194/udp comment "OpenVPN Server"

echo "[+] Allowing ICMP"
sudo ufw allow proto icmp comment "Allow ICMP for ping and path MTU"

echo "[+] Enabling UFW firewall"
sudo ufw --force enable
sudo ufw reload

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
