#!/bin/bash
set -euo pipefail

# WarpNETDNS Repository Setup Script
# This script helps set up the warpnetdns repository to receive automated releases

cat << 'EOF'
╔════════════════════════════════════════════════════════════════╗
║          WarpNETDNS Repository Setup                           ║
║                                                                ║
║  This script will guide you through setting up the            ║
║  warpnetdns repository for automated releases.                 ║
╚════════════════════════════════════════════════════════════════╝

EOF

echo "Prerequisites:"
echo "1. Create repository: https://github.com/BrunoMiguelMota/warpnetdns"
echo "2. Have a GitHub Personal Access Token (PAT) ready with 'repo' permissions"
echo ""
read -p "Have you completed the prerequisites? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Please complete the prerequisites first, then run this script again."
    exit 1
fi

echo ""
echo "==> Creating initial repository structure..."

# Create temporary directory for repo setup
TEMP_DIR=$(mktemp -d)
cd "$TEMP_DIR"

# Initialize repository
cat > README.md <<'EOREADME'
# Warp NET DNS

A rebranded and customized version of AdGuard Home for Warp NET services.

## Quick Start

### Installation

Download and install for your platform:

**Linux (x86_64)**
```bash
curl -fsSL https://raw.githubusercontent.com/BrunoMiguelMota/Linux-Scripts/main/install_adguardhome_warpnet.sh | sudo bash
```

**Manual Installation**
```bash
# Download the appropriate package for your system
wget https://github.com/BrunoMiguelMota/warpnetdns/releases/latest/download/warpnetdns_linux_amd64.tar.gz

# Extract
tar xzf warpnetdns_linux_amd64.tar.gz

# Run
sudo ./WarpNETDNS
```

### Available Downloads

- [Linux x86_64](https://github.com/BrunoMiguelMota/warpnetdns/releases/latest/download/warpnetdns_linux_amd64.tar.gz)
- [Linux ARM64](https://github.com/BrunoMiguelMota/warpnetdns/releases/latest/download/warpnetdns_linux_arm64.tar.gz)
- [Linux ARM](https://github.com/BrunoMiguelMota/warpnetdns/releases/latest/download/warpnetdns_linux_arm.tar.gz)
- [Linux ARMv7](https://github.com/BrunoMiguelMota/warpnetdns/releases/latest/download/warpnetdns_linux_armv7.tar.gz)

## Features

- **Custom Branding**: Warp NET themed interface
- **DNS Filtering**: Block ads, trackers, and malicious domains
- **Privacy Protection**: DoH, DoT, DNSCrypt support
- **Network-wide Protection**: Protect all devices on your network
- **Easy Configuration**: Web-based dashboard

## Configuration

After installation, access the web dashboard at:
```
http://your-server-ip:3000
```

Follow the setup wizard to configure your Warp NET DNS server.

## Service Management

Control the WarpNETDNS service:

```bash
# Start service
sudo systemctl start warpnetdns

# Stop service
sudo systemctl stop warpnetdns

# Restart service
sudo systemctl restart warpnetdns

# Check status
sudo systemctl status warpnetdns
```

## Documentation

For more information, see:
- [Build Instructions](https://github.com/BrunoMiguelMota/Linux-Scripts/blob/main/WARPNETDNS_BUILD.md)
- [AdGuard Home Documentation](https://github.com/AdguardTeam/AdGuardHome/wiki)

## Support

For issues and questions:
- [Open an Issue](https://github.com/BrunoMiguelMota/warpnetdns/issues)
- [View Build Source](https://github.com/BrunoMiguelMota/Linux-Scripts)

## License

Based on [AdGuard Home](https://github.com/AdguardTeam/AdGuardHome) - GPL-3.0 License

---

**Note**: Releases are automatically built and published from the [Linux-Scripts repository](https://github.com/BrunoMiguelMota/Linux-Scripts).
EOREADME

cat > .gitignore <<'EOGITIGNORE'
# Build artifacts
*.tar.gz
*.zip
warpnetdns-build/
dist/

# OS files
.DS_Store
Thumbs.db

# Editor files
*.swp
*.swo
*~
.vscode/
.idea/

# Logs
*.log
EOGITIGNORE

cat > LICENSE <<'EOLICENSE'
GNU GENERAL PUBLIC LICENSE
Version 3, 29 June 2007

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <https://www.gnu.org/licenses/>.

---

WarpNETDNS is based on AdGuard Home:
https://github.com/AdguardTeam/AdGuardHome
EOLICENSE

echo ""
echo "==> Repository structure created in: $TEMP_DIR"
echo ""
echo "Next steps:"
echo ""
echo "1. Initialize the warpnetdns repository:"
echo "   cd $TEMP_DIR"
echo "   git init"
echo "   git add ."
echo "   git commit -m 'Initial commit'"
echo "   git branch -M main"
echo "   git remote add origin https://github.com/BrunoMiguelMota/warpnetdns.git"
echo "   git push -u origin main"
echo ""
echo "2. Add the WARPNETDNS_RELEASE_TOKEN secret to Linux-Scripts repository:"
echo "   - Go to: https://github.com/BrunoMiguelMota/Linux-Scripts/settings/secrets/actions"
echo "   - Click 'New repository secret'"
echo "   - Name: WARPNETDNS_RELEASE_TOKEN"
echo "   - Value: Your GitHub Personal Access Token"
echo ""
echo "3. Trigger the first build:"
echo "   - Go to: https://github.com/BrunoMiguelMota/Linux-Scripts/actions"
echo "   - Select 'Build and Release WarpNETDNS' workflow"
echo "   - Click 'Run workflow'"
echo ""
echo "Repository files are ready in: $TEMP_DIR"
