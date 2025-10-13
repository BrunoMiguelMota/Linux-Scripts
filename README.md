# Linux-Scripts

A collection of Linux automation scripts for installing and configuring various services including VPN, DNS, security tools, and more.

## 📦 Available Scripts

### Warp NET DNS Installation

**Script:** `install_adguardhome_warpnet.sh`

An all-in-one installer for Warp NET DNS (a rebranded version of AdGuard Home) with custom branding and theming.

#### Firmware Download Location

The firmware binaries are automatically downloaded from:
```
https://github.com/BrunoMiguelMota/warpnetdns/releases/latest/download/
```

Available firmware packages:
- `warpnetdns_linux_amd64.tar.gz` - For x86_64/amd64 systems
- `warpnetdns_linux_arm64.tar.gz` - For ARM64/aarch64 systems

**Direct download links:**
- AMD64: https://github.com/BrunoMiguelMota/warpnetdns/releases/latest/download/warpnetdns_linux_amd64.tar.gz
- ARM64: https://github.com/BrunoMiguelMota/warpnetdns/releases/latest/download/warpnetdns_linux_arm64.tar.gz

#### Usage
```bash
# Basic installation
sudo bash install_adguardhome_warpnet.sh

# Installation with options
sudo bash install_adguardhome_warpnet.sh -v -o /custom/path -c release

# Options:
#   -c channel    : Choose channel (development, edge, beta, release) [default: release]
#   -C cpu_type   : Override CPU detection (amd64, arm64)
#   -h            : Show help
#   -O os         : Override OS detection [default: linux]
#   -o output_dir : Custom installation directory [default: /opt]
#   -v            : Verbose output
```

After installation, access the dashboard at: `http://<your-server-ip>:3000`

### Other Scripts

#### DNS Configuration (`dns.sh`)
Installs and configures Cloudflared for DNS-over-HTTPS (DoH) using warpserver.us/dns-query.

```bash
sudo bash dns.sh
```

#### NordVPN Installation (`nordvpn.sh`)
Installs NordVPN client with NordLynx (WireGuard) protocol support.

```bash
sudo bash nordvpn.sh
```

#### Security Gateway (`auto_security_gateway.sh`)
Sets up Suricata IDS/IPS, ClamAV antivirus, and UFW firewall for comprehensive network protection.

```bash
sudo bash auto_security_gateway.sh
```

#### Squid Proxy Installation (`LinuxSquidProxyInstall.sh`)
Interactive installer for Squid proxy server on Ubuntu 24.04.

```bash
sudo bash LinuxSquidProxyInstall.sh
```

#### OpenVPN Installation (`install_openvpn_and_create_client.sh`)
Installs OpenVPN server and creates client configurations.

```bash
sudo bash install_openvpn_and_create_client.sh
```

## 🔧 Requirements

Most scripts require:
- Ubuntu/Debian-based Linux distribution
- Root or sudo privileges
- Internet connection for downloading packages
- Basic utilities: `wget`, `curl`, `tar`, `git`, `sed`

## 📝 Build Instructions

If you want to build the Warp NET DNS firmware from source, use the `install_warpnetdns.sh` script:

```bash
# This will clone AdGuard Home, rebrand it, and build the binary
bash install_warpnetdns.sh
```

Note: Building from source requires Go toolchain and may take several minutes.

## 🛡️ Security

- Always review scripts before running with sudo/root privileges
- Scripts download packages from official sources and GitHub releases
- UFW firewall rules are configured to secure services

## 📄 License

Please check individual script headers for specific licensing information.

## 🤝 Contributing

Feel free to submit issues and pull requests for improvements or new scripts.
