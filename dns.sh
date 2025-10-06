#!/bin/bash
set -e

echo "[*] Installing cloudflared..."
wget -O cloudflared.deb https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
sudo dpkg -i cloudflared.deb

echo "[*] Configuring cloudflared to use https://warpserver.us/dns-query..."
sudo tee /etc/cloudflared/config.yml > /dev/null <<EOF
proxy-dns: true
proxy-dns-port: 5053
proxy-dns-upstream:
 - https://warpserver.us/dns-query
EOF

echo "[*] Enabling and starting cloudflared service..."
sudo systemctl enable cloudflared
sudo systemctl restart cloudflared

echo "[*] Updating system DNS to use DoH proxy..."
if grep -q 'systemd-resolved' /etc/resolv.conf; then
    sudo sed -i 's/^#DNS=/DNS=127.0.0.1/' /etc/systemd/resolved.conf
    sudo sed -i 's/^#DNSStubListener=.*/DNSStubListener=no/' /etc/systemd/resolved.conf
    sudo systemctl restart systemd-resolved
    sudo ln -sf /run/systemd/resolve/resolv.conf /etc/resolv.conf
else
    echo "nameserver 127.0.0.1" | sudo tee /etc/resolv.conf
fi

echo "[*] Setup complete! All DNS queries now use https://warpserver.us/dns-query via DoH."
