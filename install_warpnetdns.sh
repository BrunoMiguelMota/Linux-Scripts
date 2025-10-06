#!/bin/bash
set -euo pipefail

# Clone and patch AdGuard Home source for Warp NET DNS
git clone https://github.com/AdguardTeam/AdGuardHome.git warpnetdns-src
cd warpnetdns-src

# Rebrand all AdGuard Home references
find . -type f -exec sed -i \
  -e 's/AdGuard Home/Warp NET DNS/g' \
  -e 's/AdGuardHome/WarpNETDNS/g' \
  -e 's/adguardhome/warpnetdns/g' \
  {} +

# Replace logo and theme
cp /path/to/logowarpnet.svg client/src/assets/logo.svg
cp /path/to/index.css client/src/components/App/index.css

# Update version (example, adjust path as needed)
sed -i 's/AdGuard Home/Warp NET DNS/g' version/version.go

# Build binary
go mod tidy
go build -o WarpNETDNS

# Package release
mkdir -p warpnetdns-release
cp -r client/ scripts/ assets/ WarpNETDNS warpnetdns-release/
tar czvf warpnetdns_linux_amd64.tar.gz warpnetdns-release
