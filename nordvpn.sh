#!/bin/bash
set -e

echo "[*] Updating package lists..."
sudo apt-get update

echo "[*] Installing NordVPN client..."
wget -qnc https://repo.nordvpn.com/deb/nordvpn/debian/pool/main/nordvpn-release_1.0.0_all.deb
sudo dpkg -i nordvpn-release_1.0.0_all.deb
sudo apt-get update
sudo apt-get install -y nordvpn

echo "[*] Adding current user to nordvpn group (required for CLI usage)..."
sudo usermod -aG nordvpn $USER

echo "[*] Logging in with service token..."
echo "Please enter your NordVPN service token:"
read -s NORD_TOKEN

# Use expect to automate token login (if needed)
sudo nordvpn login --token $NORD_TOKEN

echo "[*] Setting NordLynx (WireGuard) as VPN protocol..."
sudo nordvpn set technology nordlynx

echo "[*] You can now use 'nordvpn connect' to connect to NordVPN via WireGuard (NordLynx)."
echo "[*] Your WireGuard server is not affected by this setup."
echo "[*] Reboot or log out/in to apply group changes, if needed."
