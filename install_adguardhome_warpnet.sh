#!/bin/bash

# Custom installer based on AdGuard Home's official install.sh, 
# changes logo to Warpnet and display name to "Warp NET DNS"

set -e

ARCHIVE_URL="https://github.com/AdguardTeam/AdGuardHome/releases/latest/download/AdGuardHome_linux_amd64.tar.gz"
ARCHIVE="AdGuardHome_linux_amd64.tar.gz"

echo "==> Downloading AdGuard Home archive..."
wget -O "$ARCHIVE" "$ARCHIVE_URL"

echo "==> Extracting AdGuard Home..."
tar -xzf "$ARCHIVE"

echo "==> Removing archive..."
rm "$ARCHIVE"

cd AdGuardHome

# --- Customization steps ---

# Ensure the assets directory exists
mkdir -p client/src/assets/

# Download Warpnet logo and replace default logo
echo "==> Applying Warpnet logo..."
wget -O client/src/assets/logowarpnet.svg https://warpnet.es/images/logowarpnet.svg

if [ -f client/src/assets/logo.svg ]; then
    mv client/src/assets/logo.svg client/src/assets/logo_adguard_original.svg
fi
cp client/src/assets/logowarpnet.svg client/src/assets/logo.svg

# Update logo references in source files
find client/src/ -type f \( -name "*.js" -o -name "*.tsx" \) -exec sed -i 's/logo\.svg/logowarpnet.svg/g' {} \;

# Change display name from "AdGuard Home" to "Warp NET DNS"
echo "==> Changing display name to Warp NET DNS..."
find client/src/ -type f \( -name "*.js" -o -name "*.tsx" \) -exec sed -i 's/AdGuard Home/Warp NET DNS/g' {} \;

echo "==> AdGuard Home is customized as Warp NET DNS with the Warpnet logo."
echo "Run './AdGuardHome/AdGuardHome' to start the server."
echo "Setup Wizard will be available at http://<your-server-ip>:3000"
