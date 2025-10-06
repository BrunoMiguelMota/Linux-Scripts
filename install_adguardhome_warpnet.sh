#!/bin/bash

# Script to clone AdGuard Home, replace its logo with Warpnet's, and prepare for custom theme installation

set -e

# Step 1: Install dependencies
sudo apt update
sudo apt install -y git wget unzip

# Step 2: Clone AdGuard Home repository
git clone https://github.com/AdguardTeam/AdGuardHome.git
cd AdGuardHome

# Step 3: Download Warpnet logo and replace the default logo
wget -O client/src/assets/logowarpnet.svg https://warpnet.es/images/logowarpnet.svg
mv client/src/assets/logo.svg client/src/assets/logo_adguard_original.svg
cp client/src/assets/logowarpnet.svg client/src/assets/logo.svg

# Step 4: Update logo references in source files
find client/src/ -type f \( -name "*.js" -o -name "*.tsx" \) -exec sed -i 's/logo\.svg/logowarpnet.svg/g' {} \;

# Step 5: (Manual) Copy CSS/theme files from warpnet.es repo
echo "Please manually copy CSS/theme files from https://github.com/BrunoMiguelMota/es-warpnet to AdGuardHome/client/src/components/App/index.css and other relevant CSS files for full theme customization."

# Step 6: (Optional) Build AdGuard Home UI (requires Node.js and npm)
# cd client
# npm install
# npm run build

echo "AdGuard Home is now customized with the Warpnet logo. Run './AdGuardHome/AdGuardHome' to start the server."
echo "Remember to finish the theme customization by copying CSS from the warpnet.es repo!"
