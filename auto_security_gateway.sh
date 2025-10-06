#!/bin/bash
set -e

echo "[*] Updating package lists..."
sudo apt-get update

echo "[*] Installing Suricata (IDS/IPS), ClamAV (antivirus), and UFW (firewall)..."
sudo apt-get install -y suricata clamav clamav-daemon ufw

echo "[*] Enabling ClamAV services..."
sudo systemctl enable clamav-freshclam
sudo systemctl enable clamav-daemon
sudo systemctl start clamav-freshclam
sudo systemctl start clamav-daemon

echo "[*] Setting up Suricata user and group if missing..."
if ! getent group suricata > /dev/null; then
    sudo groupadd --system suricata
fi
if ! id -u suricata > /dev/null 2>&1; then
    sudo useradd --system --no-create-home -g suricata suricata
fi

echo "[*] Detecting network interfaces..."
WG_IF=$(ip -o link show | awk -F': ' '{print $2}' | grep wg | head -n1)
NET_IF=$(ip route | grep default | awk '{print $5}' | head -n1)
if [ -z "$WG_IF" ]; then WG_IF="wg0"; fi
if [ -z "$NET_IF" ]; then NET_IF="eth0"; fi

echo "[*] Configuring Suricata to monitor $WG_IF and $NET_IF..."
sudo mkdir -p /var/lib/suricata/file-store
sudo chown -R suricata:suricata /var/lib/suricata/file-store

sudo sed -i "s/interface: .*/interface: $NET_IF/" /etc/suricata/suricata.yaml
if ! grep -q "  - interface: $WG_IF" /etc/suricata/suricata.yaml; then
  sudo sed -i "/af-packet:/a\  - interface: $WG_IF" /etc/suricata/suricata.yaml
fi

if ! grep -q "file-store:" /etc/suricata/suricata.yaml; then
  sudo sed -i '/outputs:/a\  - file-store:\n      enabled: yes\n      force-magic: yes\n      force-md5: yes\n      stream-depth: 0\n      dir: /var/lib/suricata/file-store' /etc/suricata/suricata.yaml
else
  sudo sed -i '/file-store:/,/dir:/s/enabled: no/enabled: yes/' /etc/suricata/suricata.yaml
  sudo sed -i '/file-store:/,/dir:/s|dir:.*|dir: /var/lib/suricata/file-store|' /etc/suricata/suricata.yaml
fi

echo "[*] Restarting Suricata to apply changes..."
sudo systemctl restart suricata

echo "[*] Preparing folder for infected files..."
sudo mkdir -p /var/lib/suricata/file-infected
sudo chown clamav:clamav /var/lib/suricata/file-infected

echo "[*] Setting up ClamAV cron job for continuous scanning..."
CRONJOB="* * * * * clamscan -r /var/lib/suricata/file-store --move=/var/lib/suricata/file-infected"
( crontab -l 2>/dev/null | grep -v 'clamscan -r /var/lib/suricata/file-store' ; echo "$CRONJOB" ) | crontab -

echo "[*] Configuring UFW firewall for WireGuard and SSH..."
sudo ufw allow OpenSSH
sudo ufw allow 51820/udp   # WireGuard port
sudo ufw default deny incoming
sudo ufw default allow outgoing
yes | sudo ufw enable

echo "[*] SSH hardening: disabling root login and password auth..."
if systemctl list-units --type=service | grep -q "sshd.service"; then
    sudo sed -i 's/^PermitRootLogin .*/PermitRootLogin no/' /etc/ssh/sshd_config
    sudo sed -i 's/^#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
    sudo systemctl reload sshd
elif systemctl list-units --type=service | grep -q "ssh.service"; then
    sudo sed -i 's/^PermitRootLogin .*/PermitRootLogin no/' /etc/ssh/sshd_config
    sudo sed -i 's/^#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
    sudo systemctl reload ssh
fi

echo "[*] System secured and traffic monitoring active!"
echo "[*] Suricata IDS/IPS, ClamAV antivirus, and UFW firewall are now protecting your server and its traffic."
echo "[*] All network traffic (including VPN) is monitored. Extracted files are quarantined if infected."
