# Linux-Scripts

Collection of Linux and OpenWRT security automation scripts.

## Scripts

### OpenWRT Router Security

#### `openwrt_glinet_be9300_security.sh`
Comprehensive security configuration for GL.iNet GL-BE9300 (WiFi 7) router running OpenWRT firmware.

**Features:**
- WPA3-SAE encryption for all WiFi bands (2.4GHz, 5GHz, 6GHz)
- Advanced firewall hardening with nftables
- DNS-over-HTTPS for privacy (Cloudflare + Quad9)
- Ad-blocking with multiple sources
- BanIP automated threat blocking
- WireGuard VPN configuration
- SSH hardening (key-only, LAN-only)
- HTTPS-only web interface
- Kernel security hardening
- Management frame protection (802.11w)

**Documentation:** See [OPENWRT_GL-BE9300_SECURITY_README.md](OPENWRT_GL-BE9300_SECURITY_README.md)

**Usage:**
```bash
ssh root@192.168.8.1
wget https://raw.githubusercontent.com/BrunoMiguelMota/Linux-Scripts/main/openwrt_glinet_be9300_security.sh
chmod +x openwrt_glinet_be9300_security.sh
./openwrt_glinet_be9300_security.sh
```

### Linux Server Security

#### `auto.secure.sh`
Automated security setup for Linux servers with VPN monitoring.

**Features:**
- WireGuard VPN installation
- ClamAV antivirus
- Suricata IDS/IPS
- UFW firewall
- SSH hardening
- Continuous malware scanning

#### `auto_security_gateway.sh`
Security gateway configuration for Linux servers.

**Features:**
- Suricata IDS/IPS
- ClamAV antivirus
- UFW firewall
- Traffic monitoring
- File extraction and scanning

### DNS Configuration

#### `dns.sh`
Configure DNS-over-HTTPS using Cloudflare's DNS service.

**Features:**
- Cloudflared installation
- DoH proxy configuration
- System DNS integration

### VPN Installation

#### `install_openvpn_and_create_client.sh`
OpenVPN server installation and client configuration generator.

#### `nordvpn.sh`
NordVPN client installation and configuration.

### DNS Server

#### `install_adguardhome_warpnet.sh`
Install and configure Warp NET DNS (AdGuard Home fork).

**Features:**
- Rebranded AdGuard Home
- Custom theme
- Ad-blocking
- DNS filtering

### Proxy Server

#### `LinuxSquidProxyInstall.sh`
Squid proxy server installation and configuration.

## Requirements

- **OpenWRT scripts**: OpenWRT 23.05+ on compatible router
- **Linux scripts**: Ubuntu/Debian-based systems
- Root or sudo access
- Internet connection

## Installation

Clone the repository:

```bash
git clone https://github.com/BrunoMiguelMota/Linux-Scripts.git
cd Linux-Scripts
chmod +x *.sh
```

Run the desired script:

```bash
sudo ./script_name.sh
```

## Security Warning

⚠️ These scripts make significant changes to system security settings. Always:
- Review scripts before running
- Test in a non-production environment first
- Backup configurations
- Understand what each script does
- Keep systems updated

## Contributing

Contributions are welcome! Please submit pull requests or open issues.

## License

MIT License - Use at your own risk.

## Support

For issues or questions:
- Open an issue on GitHub
- Check script documentation
- Review OpenWRT/Linux documentation
