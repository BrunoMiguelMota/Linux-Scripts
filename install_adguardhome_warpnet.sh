#!/bin/bash

# Custom installer for AdGuard Home with Warpnet logo and theme preparation
# Based on: https://raw.githubusercontent.com/AdguardTeam/AdGuardHome/master/scripts/install.sh

set -e

# --- Original install.sh steps ---
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

# Ensure the assets directory exists (for logo)
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

# Prompt user to manually copy theme CSS
echo "==> Please manually copy CSS/theme files from https://github.com/BrunoMiguelMota/es-warpnet to AdGuardHome/client/src/components/App/index.css and other relevant CSS files for full theme customization."

echo "==> AdGuard Home is customized with the Warpnet logo."
echo "Run './AdGuardHome/AdGuardHome' to start the server."
echo "Setup Wizard will be available at http://<your-server-ip>:3000"
echo "Remember to finish the theme customization by copying CSS from the warpnet.es repo!"
