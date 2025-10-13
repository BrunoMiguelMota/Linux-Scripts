# Linux-Scripts

Collection of Linux utility and automation scripts.

## Scripts Available

### WarpNETDNS Build System

A complete build and release system for WarpNETDNS, a rebranded version of AdGuard Home customized for Warp NET services.

**Key Features:**
- Automated building from AdGuard Home source
- Custom branding and theming
- Multi-architecture support (amd64, arm64, arm, armv7)
- Automated releases via GitHub Actions
- Installation scripts for easy deployment

**Documentation:** See [WARPNETDNS_BUILD.md](WARPNETDNS_BUILD.md) for complete details.

**Quick Start:**
```bash
# Install WarpNETDNS on your server
curl -fsSL https://raw.githubusercontent.com/BrunoMiguelMota/Linux-Scripts/main/install_adguardhome_warpnet.sh | sudo bash

# Or download releases directly
wget https://github.com/BrunoMiguelMota/warpnetdns/releases/latest/download/warpnetdns_linux_amd64.tar.gz
```

### Security Gateway Setup

**auto_security_gateway.sh** - Automated security gateway setup with:
- Suricata IDS/IPS for traffic monitoring
- ClamAV antivirus integration
- UFW firewall configuration
- SSH hardening
- WireGuard VPN support

### Other Scripts

- **auto.secure.sh** - System security hardening
- **dns.sh** - DNS configuration utilities
- **nordvpn.sh** - NordVPN setup and management
- **install_openvpn_and_create_client.sh** - OpenVPN server setup
- **LinuxSquidProxyInstall.sh** - Squid proxy installation

## Usage

Each script is designed to be run directly or curled:

```bash
# Download and execute
curl -fsSL https://raw.githubusercontent.com/BrunoMiguelMota/Linux-Scripts/main/[script-name].sh | bash

# Or clone and run locally
git clone https://github.com/BrunoMiguelMota/Linux-Scripts.git
cd Linux-Scripts
chmod +x [script-name].sh
./[script-name].sh
```

## Contributing

Contributions are welcome! Please feel free to submit pull requests or open issues.

## License

See individual scripts for licensing information. WarpNETDNS maintains GPL-3.0 license from AdGuard Home.
