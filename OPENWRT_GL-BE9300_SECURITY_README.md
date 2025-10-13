# OpenWRT Security Configuration for GL.iNet GL-BE9300

This script provides a comprehensive security hardening configuration for the GL.iNet GL-BE9300 WiFi 7 router running OpenWRT firmware.

## Features

### 🛡️ Network Security
- **Advanced Firewall Configuration**: Hardened nftables/iptables rules with strict input/output policies
- **SYN Flood Protection**: Enabled TCP SYN cookies and connection tracking
- **Invalid Packet Dropping**: Automatically drops malformed packets
- **Anti-Spoofing**: Reverse path filtering and source route blocking

### 🔐 Wireless Security
- **WPA3-SAE Encryption**: Latest WiFi security standard (WPA3) for all radios
- **Management Frame Protection**: IEEE 802.11w enabled for all bands
- **WPS Disabled**: Eliminates WPS vulnerability vector
- **Multi-Band Support**: Secure configuration for 2.4GHz, 5GHz, and 6GHz (WiFi 7)
- **KRACK Protection**: WPA key reinstallation attack mitigation

### 🌐 Privacy & DNS
- **DNS-over-HTTPS (DoH)**: Encrypted DNS queries via Cloudflare and Quad9
- **Ad-Blocking**: Multi-source ad and tracker blocking (AdAway, OISD, Steven Black)
- **Safe Search Enforcement**: Optional safe search for search engines

### 🚫 Threat Protection
- **BanIP**: Automated IP reputation-based blocking
- **Multiple Threat Feeds**: Firehol, Spamhaus, Talos threat intelligence
- **SSH Brute Force Protection**: Automatic blocking after failed attempts
- **Drop Invalid Connections**: Prevents various network attacks

### 🔒 Access Security
- **SSH Hardening**: 
  - Password authentication disabled
  - Root password login disabled
  - LAN-only access
  - Key-based authentication only
- **HTTPS-Only Web Interface**: Encrypted LuCI access with automatic HTTP→HTTPS redirect

### 🌍 VPN Support
- **WireGuard VPN**: Pre-configured for secure remote access
- **Proper Firewall Zones**: Isolated VPN zone with controlled forwarding
- **NAT for VPN Clients**: Allows VPN users to access internet through router

### ⚙️ System Hardening
- **Kernel Parameter Tuning**: Optimized sysctl settings for security
- **Service Minimization**: Disabled unnecessary services
- **Secure Logging**: Configured system logging for security events

## Requirements

- GL.iNet GL-BE9300 router
- OpenWRT 23.05 or newer
- Internet connection for package installation
- SSH access to the router

## Installation

### Step 1: Access Your Router

SSH into your GL-BE9300 router:

```bash
ssh root@192.168.8.1
```

Default password for GL.iNet routers is typically printed on the device label.

### Step 2: Download the Script

```bash
cd /tmp
wget https://raw.githubusercontent.com/BrunoMiguelMota/Linux-Scripts/main/openwrt_glinet_be9300_security.sh
chmod +x openwrt_glinet_be9300_security.sh
```

### Step 3: Run the Script

```bash
./openwrt_glinet_be9300_security.sh
```

The script will take several minutes to complete as it:
1. Updates package lists
2. Installs security packages
3. Configures all security settings
4. Restarts necessary services

### Step 4: Post-Installation Configuration

After the script completes, you **must** perform these critical steps:

#### 1. Change WiFi Passwords

Edit the wireless configuration:

```bash
nano /etc/config/wireless
```

Find these lines and change the password:

```
option key 'ChangeThisPassword123!'
```

To something strong and unique. Then save and apply:

```bash
uci commit wireless
wifi reload
```

#### 2. Setup SSH Key Authentication

On your local computer, generate an SSH key if you don't have one:

```bash
ssh-keygen -t ed25519 -C "your_email@example.com"
```

Copy your public key to the router:

```bash
ssh-copy-id root@192.168.8.1
```

Or manually add it:

```bash
# On the router
nano /etc/dropbear/authorized_keys
# Paste your public key (from ~/.ssh/id_ed25519.pub on your computer)
```

Test SSH key login before proceeding!

#### 3. Configure WireGuard VPN

Access the LuCI web interface at `https://192.168.8.1` and navigate to:

**Network → VPN → WireGuard**

Generate client configurations for your devices. Example client configuration:

```ini
[Interface]
PrivateKey = <CLIENT_PRIVATE_KEY>
Address = 10.0.0.2/24
DNS = 10.0.0.1

[Peer]
PublicKey = <ROUTER_PUBLIC_KEY>
Endpoint = <YOUR_PUBLIC_IP>:51820
AllowedIPs = 0.0.0.0/0, ::/0
PersistentKeepalive = 25
```

#### 4. Update Firewall Rules

Review and adjust firewall rules if needed:

```bash
nano /etc/config/firewall
```

Or use LuCI: **Network → Firewall**

#### 5. Configure DNS Settings

The script configures DNS-over-HTTPS by default. You can verify:

```bash
nslookup example.com 127.0.0.1#5053
```

## Security Check

A monitoring script is installed at `/root/security_check.sh`. Run it to verify your security configuration:

```bash
/root/security_check.sh
```

This will show:
- Firewall status
- Active connections
- BanIP status
- DNS-over-TLS status
- Adblock status
- WireGuard status
- System resources

## Configuration Files

The script modifies these OpenWRT configuration files:

- `/etc/config/firewall` - Firewall rules and zones
- `/etc/config/wireless` - WiFi security settings
- `/etc/config/dhcp` - DNS configuration
- `/etc/config/network` - WireGuard VPN interface
- `/etc/config/dropbear` - SSH server settings
- `/etc/config/uhttpd` - Web server (HTTPS)
- `/etc/config/adblock` - Ad-blocking settings
- `/etc/config/banip` - IP threat blocking
- `/etc/config/https-dns-proxy` - DNS-over-HTTPS
- `/etc/sysctl.conf` - Kernel security parameters

Backups are created before modifications (e.g., `/etc/config/firewall.backup`).

## Troubleshooting

### Can't Access Web Interface

If you lose web access, SSH into the router and check uhttpd:

```bash
/etc/init.d/uhttpd status
/etc/init.d/uhttpd restart
```

### Locked Out via SSH

If SSH key authentication fails and password auth is disabled:

1. Connect via serial console (if available)
2. Or reset to factory defaults (hold reset button for 10 seconds)
3. Reconfigure from scratch

### WiFi Not Working

Check wireless configuration:

```bash
wifi status
wifi reload
```

View logs:

```bash
logread | grep -i wireless
```

### VPN Not Connecting

Check WireGuard status:

```bash
wg show
```

Verify firewall rule:

```bash
nft list ruleset | grep 51820
```

### DNS Issues

Test DNS resolution:

```bash
nslookup google.com
```

Check DNS proxy:

```bash
/etc/init.d/https-dns-proxy status
netstat -tulpn | grep 5053
```

## Performance Considerations

The GL-BE9300 is a high-performance router with:
- Quad-core processor
- 1GB RAM
- WiFi 7 support

Security features enabled by this script use minimal resources:
- BanIP: ~10-20MB RAM
- Adblock: ~5-10MB RAM
- DNS-over-HTTPS: ~5MB RAM
- WireGuard: ~5-10MB RAM per peer

Total overhead: ~30-50MB RAM, <5% CPU under normal load.

## Security Best Practices

After installation, follow these practices:

1. **Regular Updates**: 
   ```bash
   opkg update
   opkg list-upgradable
   opkg upgrade <package>
   ```

2. **Monitor Logs**:
   ```bash
   logread -f
   ```

3. **Review BanIP Blocks**:
   ```bash
   cat /tmp/ban_data/banip.list
   ```

4. **Check for Intrusion Attempts**:
   ```bash
   logread | grep -i "input.*DROP"
   ```

5. **Update Threat Feeds**:
   ```bash
   /etc/init.d/banip reload
   ```

6. **Backup Configuration**:
   ```bash
   sysupgrade -b /tmp/backup-$(date +%F).tar.gz
   ```

## Advanced Configuration

### Change WireGuard Port

```bash
uci set network.wg0.listen_port='51821'
uci commit network
/etc/init.d/network reload
```

Don't forget to update firewall rule!

### Add Additional DNS-over-HTTPS Providers

```bash
uci add https-dns-proxy https-dns-proxy
uci set https-dns-proxy.@https-dns-proxy[-1].resolver_url='https://dns.google/dns-query'
uci set https-dns-proxy.@https-dns-proxy[-1].listen_port='5055'
uci commit https-dns-proxy
/etc/init.d/https-dns-proxy restart
```

### Enable Country-Based Blocking

```bash
uci add_list banip.global.ban_countries='cn'
uci add_list banip.global.ban_countries='ru'
uci commit banip
/etc/init.d/banip reload
```

### Custom Firewall Rules

Add custom rules in `/etc/firewall.user`:

```bash
# Block specific IP
iptables -I INPUT -s 1.2.3.4 -j DROP

# Rate limit SSH
iptables -I INPUT -p tcp --dport 22 -m state --state NEW -m recent --set
iptables -I INPUT -p tcp --dport 22 -m state --state NEW -m recent --update --seconds 60 --hitcount 4 -j DROP
```

## Uninstallation

To revert to default settings:

```bash
# Restore firewall backup
cp /etc/config/firewall.backup /etc/config/firewall

# Factory reset (WARNING: Loses all settings)
firstboot -y
reboot
```

## Support & Resources

- **OpenWRT Documentation**: https://openwrt.org/docs/start
- **GL.iNet Forum**: https://forum.gl-inet.com/
- **WireGuard Documentation**: https://www.wireguard.com/
- **This Repository**: https://github.com/BrunoMiguelMota/Linux-Scripts

## License

This script is provided as-is without warranty. Use at your own risk.

## Contributing

Contributions are welcome! Please submit pull requests or open issues on GitHub.

## Changelog

### Version 1.0.0 (Initial Release)
- Complete security hardening for GL-BE9300
- WPA3 configuration for all bands
- DNS-over-HTTPS with multiple providers
- BanIP with threat intelligence feeds
- WireGuard VPN setup
- SSH hardening
- System kernel hardening
- Automated security monitoring

## Security Disclaimer

While this script implements many security best practices, no system is 100% secure. Always:
- Keep firmware updated
- Use strong passwords
- Monitor your network
- Follow security news
- Regularly review configurations
- Backup your settings

## Credits

Created for the GL.iNet GL-BE9300 router community.

Based on OpenWRT security best practices and community recommendations.
