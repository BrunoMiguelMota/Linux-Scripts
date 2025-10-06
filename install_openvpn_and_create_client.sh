#!/bin/bash
set -e

# Variables (edit CLIENT_NAME if needed)
SERVER_PORT=1194
CLIENT_NAME=client1

echo "[*] Updating package lists..."
sudo apt-get update

echo "[*] Installing OpenVPN and Easy-RSA..."
sudo apt-get install -y openvpn easy-rsa

echo "[*] Setting up Easy-RSA PKI directory..."
make-cadir ~/openvpn-ca
cd ~/openvpn-ca

echo "[*] Building CA, server, and client certificates..."
source ./vars
./clean-all
./build-ca --batch
./build-key-server --batch server
./build-key --batch $CLIENT_NAME
./build-dh
openvpn --genkey --secret keys/ta.key

echo "[*] Copying server certificates and keys to /etc/openvpn/server..."
sudo mkdir -p /etc/openvpn/server
sudo cp keys/{server.crt,server.key,ca.crt,dh2048.pem,ta.key} /etc/openvpn/server/

echo "[*] Creating basic OpenVPN server config..."
sudo bash -c "cat > /etc/openvpn/server/server.conf" <<EOF
port $SERVER_PORT
proto udp
dev tun
ca ca.crt
cert server.crt
key server.key
dh dh2048.pem
auth SHA256
tls-auth ta.key 0
server 10.8.0.0 255.255.255.0
ifconfig-pool-persist ipp.txt
push \"redirect-gateway def1 bypass-dhcp\"
push \"dhcp-option DNS 76.76.2.2\"
push \"dhcp-option DNS 76.76.10.2\"
keepalive 10 120
cipher AES-256-GCM
user nobody
group nogroup
persist-key
persist-tun
status openvpn-status.log
verb 3
EOF

echo "[*] Enabling IP forwarding..."
sudo sed -i '/net.ipv4.ip_forward/s/^#//g' /etc/sysctl.conf
sudo sysctl -p

echo "[*] Configuring firewall (UFW)..."
sudo ufw allow $SERVER_PORT/udp
sudo ufw allow OpenSSH
sudo ufw disable
sudo ufw enable

echo "[*] Starting OpenVPN server..."
sudo systemctl start openvpn-server@server
sudo systemctl enable openvpn-server@server

echo "[*] Creating client.ovpn file..."
CLIENT_DIR=~/openvpn-ca/keys
cat > ~/$CLIENT_NAME.ovpn <<EOF
client
dev tun
proto udp
remote $(curl -s ifconfig.me) $SERVER_PORT
resolv-retry infinite
nobind
persist-key
persist-tun
remote-cert-tls server
auth SHA256
tls-auth ta.key 1
cipher AES-256-GCM
verb 3
redirect-gateway def1
dhcp-option DNS 76.76.2.2
dhcp-option DNS 76.76.10.2

<ca>
$(cat $CLIENT_DIR/ca.crt)
</ca>
<cert>
$(cat $CLIENT_DIR/$CLIENT_NAME.crt)
</cert>
<key>
$(cat $CLIENT_DIR/$CLIENT_NAME.key)
</key>
<tls-auth>
$(cat $CLIENT_DIR/ta.key)
</tls-auth>
EOF

echo "[*] Done!"
echo "Your server is running. Download ~/$CLIENT_NAME.ovpn to your client device."
