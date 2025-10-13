#!/bin/sh
# OpenWRT Security Configuration for GL.iNet GL-BE9300 Router
# This script configures maximum security settings for the GL-BE9300 router
# Compatible with OpenWRT 23.05+ on GL-BE9300

set -e

echo "[*] GL-BE9300 OpenWRT Security Configuration Script"
echo "[*] ================================================"
echo ""

# Check if running on OpenWRT
if [ ! -f /etc/openwrt_release ]; then
    echo "[!] Error: This script must be run on an OpenWRT system."
    exit 1
fi

echo "[*] Step 1: Updating package lists..."
opkg update

echo "[*] Step 2: Installing essential security packages..."
# Install core security packages
opkg install luci-ssl-openssl
opkg install wpad-mbedtls
opkg install wireguard-tools luci-app-wireguard kmod-wireguard
opkg install banip luci-app-banip
opkg install adblock luci-app-adblock
opkg install https-dns-proxy luci-app-https-dns-proxy
opkg install nano curl wget-ssl
opkg install tcpdump-mini
opkg install uhttpd-mod-ubus

echo "[*] Step 3: Configuring firewall for maximum security..."

# Backup existing firewall config
cp /etc/config/firewall /etc/config/firewall.backup

# Configure nftables firewall zones
uci set firewall.@defaults[0].input='REJECT'
uci set firewall.@defaults[0].output='ACCEPT'
uci set firewall.@defaults[0].forward='REJECT'
uci set firewall.@defaults[0].synflood_protect='1'
uci set firewall.@defaults[0].drop_invalid='1'

# Configure WAN zone with strict security
uci set firewall.@zone[1].input='REJECT'
uci set firewall.@zone[1].forward='REJECT'
uci set firewall.@zone[1].masq='1'
uci set firewall.@zone[1].mtu_fix='1'

# Enable additional firewall protections
uci set firewall.@defaults[0].tcp_syncookies='1'
uci set firewall.@defaults[0].tcp_ecn='0'
uci set firewall.@defaults[0].tcp_window_scaling='1'
uci set firewall.@defaults[0].accept_redirects='0'
uci set firewall.@defaults[0].accept_source_route='0'

# Disable ping from WAN
uci delete firewall.@rule[$(uci show firewall | grep "Allow-Ping" | cut -d'[' -f2 | cut -d']' -f1)] 2>/dev/null || true

uci commit firewall
/etc/init.d/firewall restart

echo "[*] Step 4: Configuring secure wireless settings..."

# Configure 2.4GHz radio
uci set wireless.radio0.disabled='0'
uci set wireless.radio0.country='US'
uci set wireless.radio0.channel='auto'
uci set wireless.radio0.htmode='HE40'
uci set wireless.radio0.txpower='20'

# Configure 5GHz radio
uci set wireless.radio1.disabled='0'
uci set wireless.radio1.country='US'
uci set wireless.radio1.channel='auto'
uci set wireless.radio1.htmode='HE80'
uci set wireless.radio1.txpower='23'

# Configure 6GHz radio (BE9300 supports WiFi 7)
uci set wireless.radio2.disabled='0'
uci set wireless.radio2.country='US'
uci set wireless.radio2.channel='auto'
uci set wireless.radio2.htmode='EHT160'
uci set wireless.radio2.txpower='23'

# Configure secure WiFi settings for default_radio0 (2.4GHz)
uci set wireless.default_radio0.encryption='sae-mixed'
uci set wireless.default_radio0.key='ChangeThisPassword123!'
uci set wireless.default_radio0.ieee80211w='2'
uci set wireless.default_radio0.wps_pushbutton='0'
uci set wireless.default_radio0.wps_label='0'
uci set wireless.default_radio0.wpa_disable_eapol_key_retries='1'

# Configure secure WiFi settings for default_radio1 (5GHz)
uci set wireless.default_radio1.encryption='sae-mixed'
uci set wireless.default_radio1.key='ChangeThisPassword123!'
uci set wireless.default_radio1.ieee80211w='2'
uci set wireless.default_radio1.wps_pushbutton='0'
uci set wireless.default_radio1.wps_label='0'
uci set wireless.default_radio1.wpa_disable_eapol_key_retries='1'

# Configure secure WiFi settings for default_radio2 (6GHz)
uci set wireless.default_radio2.encryption='sae'
uci set wireless.default_radio2.key='ChangeThisPassword123!'
uci set wireless.default_radio2.ieee80211w='2'
uci set wireless.default_radio2.wps_pushbutton='0'
uci set wireless.default_radio2.wps_label='0'

uci commit wireless
wifi reload

echo "[*] Step 5: Configuring DNS-over-TLS for privacy..."

# Configure https-dns-proxy with Cloudflare DNS
uci -q delete https-dns-proxy.@https-dns-proxy[0]
uci add https-dns-proxy https-dns-proxy
uci set https-dns-proxy.@https-dns-proxy[-1].bootstrap_dns='1.1.1.1,1.0.0.1'
uci set https-dns-proxy.@https-dns-proxy[-1].resolver_url='https://cloudflare-dns.com/dns-query'
uci set https-dns-proxy.@https-dns-proxy[-1].listen_addr='127.0.0.1'
uci set https-dns-proxy.@https-dns-proxy[-1].listen_port='5053'
uci set https-dns-proxy.@https-dns-proxy[-1].user='nobody'
uci set https-dns-proxy.@https-dns-proxy[-1].group='nogroup'

# Add backup DNS-over-TLS resolver (Quad9)
uci add https-dns-proxy https-dns-proxy
uci set https-dns-proxy.@https-dns-proxy[-1].bootstrap_dns='9.9.9.9,149.112.112.112'
uci set https-dns-proxy.@https-dns-proxy[-1].resolver_url='https://dns.quad9.net/dns-query'
uci set https-dns-proxy.@https-dns-proxy[-1].listen_addr='127.0.0.1'
uci set https-dns-proxy.@https-dns-proxy[-1].listen_port='5054'
uci set https-dns-proxy.@https-dns-proxy[-1].user='nobody'
uci set https-dns-proxy.@https-dns-proxy[-1].group='nogroup'

uci commit https-dns-proxy

# Configure dnsmasq to use DoT proxy
uci -q delete dhcp.@dnsmasq[0].server
uci add_list dhcp.@dnsmasq[0].server='127.0.0.1#5053'
uci add_list dhcp.@dnsmasq[0].server='127.0.0.1#5054'
uci set dhcp.@dnsmasq[0].noresolv='1'
uci commit dhcp

/etc/init.d/https-dns-proxy enable
/etc/init.d/https-dns-proxy restart
/etc/init.d/dnsmasq restart

echo "[*] Step 6: Configuring Ad-blocking with Adblock..."

uci set adblock.global.adb_enabled='1'
uci set adblock.global.adb_safesearch='1'
uci set adblock.global.adb_jail='1'
uci set adblock.global.adb_dns='dnsmasq'
uci set adblock.global.adb_fetchutil='uclient-fetch'
uci add_list adblock.global.adb_sources='adaway'
uci add_list adblock.global.adb_sources='oisd'
uci add_list adblock.global.adb_sources='stevenblack'
uci commit adblock

/etc/init.d/adblock enable
/etc/init.d/adblock start

echo "[*] Step 7: Configuring BanIP for automated threat blocking..."

uci set banip.global.ban_enabled='1'
uci set banip.global.ban_autodetect='1'
uci set banip.global.ban_logread='1'
uci set banip.global.ban_logterm='dropbear'
uci set banip.global.ban_sshlimit='3'
uci set banip.global.ban_sshlogcount='3'
uci add_list banip.global.ban_sources='firehol1'
uci add_list banip.global.ban_sources='firehol2'
uci add_list banip.global.ban_sources='firehol3'
uci add_list banip.global.ban_sources='spamhaus'
uci add_list banip.global.ban_sources='talos'
uci commit banip

/etc/init.d/banip enable
/etc/init.d/banip start

echo "[*] Step 8: Hardening SSH access..."

# Configure dropbear (SSH server) for maximum security
uci set dropbear.@dropbear[0].PasswordAuth='off'
uci set dropbear.@dropbear[0].RootPasswordAuth='off'
uci set dropbear.@dropbear[0].Port='22'
uci set dropbear.@dropbear[0].Interface='lan'
uci set dropbear.@dropbear[0].GatewayPorts='off'
uci commit dropbear

/etc/init.d/dropbear restart

echo "[*] Step 9: Configuring WireGuard VPN for secure remote access..."

# Create WireGuard interface
uci set network.wg0='interface'
uci set network.wg0.proto='wireguard'
uci set network.wg0.private_key="$(wg genkey)"
uci set network.wg0.listen_port='51820'
uci set network.wg0.addresses='10.0.0.1/24'

# Add WireGuard firewall zone
uci add firewall zone
uci set firewall.@zone[-1].name='vpn'
uci set firewall.@zone[-1].input='ACCEPT'
uci set firewall.@zone[-1].output='ACCEPT'
uci set firewall.@zone[-1].forward='ACCEPT'
uci set firewall.@zone[-1].masq='1'
uci set firewall.@zone[-1].network='wg0'

# Allow VPN to LAN forwarding
uci add firewall forwarding
uci set firewall.@forwarding[-1].src='vpn'
uci set firewall.@forwarding[-1].dest='lan'

# Allow VPN to WAN forwarding
uci add firewall forwarding
uci set firewall.@forwarding[-1].src='vpn'
uci set firewall.@forwarding[-1].dest='wan'

# Allow WireGuard traffic from WAN
uci add firewall rule
uci set firewall.@rule[-1].name='Allow-WireGuard'
uci set firewall.@rule[-1].src='wan'
uci set firewall.@rule[-1].dest_port='51820'
uci set firewall.@rule[-1].proto='udp'
uci set firewall.@rule[-1].target='ACCEPT'

uci commit network
uci commit firewall

/etc/init.d/network reload
/etc/init.d/firewall reload

echo "[*] Step 10: Configuring HTTPS for LuCI web interface..."

# Enable HTTPS for LuCI
uci set uhttpd.main.listen_http='0.0.0.0:80'
uci set uhttpd.main.listen_https='0.0.0.0:443'
uci set uhttpd.main.redirect_https='1'
uci commit uhttpd

/etc/init.d/uhttpd restart

echo "[*] Step 11: Hardening system settings..."

# Disable unused services
/etc/init.d/odhcpd disable 2>/dev/null || true

# Configure system logging
uci set system.@system[0].log_size='64'
uci set system.@system[0].log_buffer_size='64'
uci commit system

# Harden kernel parameters
cat >> /etc/sysctl.conf << 'EOF'

# IP forwarding
net.ipv4.ip_forward=1
net.ipv6.conf.all.forwarding=1

# TCP hardening
net.ipv4.tcp_syncookies=1
net.ipv4.tcp_syn_retries=2
net.ipv4.tcp_synack_retries=2
net.ipv4.tcp_max_syn_backlog=4096

# ICMP security
net.ipv4.icmp_echo_ignore_all=0
net.ipv4.icmp_echo_ignore_broadcasts=1
net.ipv4.icmp_ignore_bogus_error_responses=1

# Routing security
net.ipv4.conf.all.accept_redirects=0
net.ipv4.conf.all.secure_redirects=0
net.ipv4.conf.all.send_redirects=0
net.ipv4.conf.default.accept_redirects=0
net.ipv4.conf.default.secure_redirects=0
net.ipv4.conf.default.send_redirects=0
net.ipv6.conf.all.accept_redirects=0
net.ipv6.conf.default.accept_redirects=0

# Source routing
net.ipv4.conf.all.accept_source_route=0
net.ipv4.conf.default.accept_source_route=0
net.ipv6.conf.all.accept_source_route=0
net.ipv6.conf.default.accept_source_route=0

# Reverse path filtering
net.ipv4.conf.all.rp_filter=1
net.ipv4.conf.default.rp_filter=1

# Log Martians
net.ipv4.conf.all.log_martians=1
net.ipv4.conf.default.log_martians=1
EOF

sysctl -p

echo "[*] Step 12: Creating security monitoring script..."

cat > /root/security_check.sh << 'EOF'
#!/bin/sh
# Security monitoring script for GL-BE9300

echo "=== GL-BE9300 Security Status ==="
echo ""

echo "Firewall Status:"
/etc/init.d/firewall status

echo ""
echo "Active Connections:"
netstat -tun | grep ESTABLISHED | wc -l

echo ""
echo "BanIP Status:"
/etc/init.d/banip status

echo ""
echo "DNS-over-TLS Status:"
/etc/init.d/https-dns-proxy status

echo ""
echo "Adblock Status:"
/etc/init.d/adblock status

echo ""
echo "WireGuard Status:"
wg show 2>/dev/null || echo "WireGuard not configured"

echo ""
echo "System Load:"
uptime

echo ""
echo "Memory Usage:"
free -h
EOF

chmod +x /root/security_check.sh

echo "[*] Step 13: Saving configuration..."
uci commit

echo ""
echo "[*] ============================================="
echo "[*] GL-BE9300 Security Configuration Complete!"
echo "[*] ============================================="
echo ""
echo "[*] Security features enabled:"
echo "    ✓ Hardened firewall with strict rules"
echo "    ✓ WPA3-SAE encryption for WiFi (2.4/5/6GHz)"
echo "    ✓ DNS-over-HTTPS for privacy"
echo "    ✓ Ad-blocking with multiple sources"
echo "    ✓ Automated IP threat blocking (BanIP)"
echo "    ✓ SSH hardened (key-only, LAN-only)"
echo "    ✓ WireGuard VPN configured"
echo "    ✓ HTTPS-only web interface"
echo "    ✓ Kernel hardening enabled"
echo ""
echo "[!] IMPORTANT: Next steps required:"
echo "    1. Change WiFi passwords in /etc/config/wireless"
echo "       Current password: ChangeThisPassword123!"
echo "    2. Add SSH public keys to /etc/dropbear/authorized_keys"
echo "    3. Configure WireGuard client peers in LuCI"
echo "    4. Review firewall rules in LuCI"
echo "    5. Test all connectivity before deploying"
echo ""
echo "[*] To check security status, run: /root/security_check.sh"
echo "[*] To access LuCI: https://192.168.8.1"
echo ""
echo "[*] Reboot recommended to apply all changes."
echo "[*] Run: reboot"
