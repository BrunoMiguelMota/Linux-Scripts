#!/bin/bash
set -euo pipefail

# Warp NET DNS Build Script
# This script clones AdGuard Home, rebrands it to Warp NET DNS, and builds binaries

ADGUARD_VERSION="${ADGUARD_VERSION:-v0.107.52}"
WORK_DIR="${WORK_DIR:-$(pwd)/warpnetdns-build}"
OS="${GOOS:-linux}"
ARCH="${GOARCH:-amd64}"

echo "==> Building Warp NET DNS from AdGuard Home ${ADGUARD_VERSION}"
echo "==> Target: ${OS}/${ARCH}"

# Clean and create work directory
rm -rf "$WORK_DIR"
mkdir -p "$WORK_DIR"
cd "$WORK_DIR"

# Clone AdGuard Home source
echo "==> Cloning AdGuard Home source..."
git clone --depth 1 --branch "${ADGUARD_VERSION}" https://github.com/AdguardTeam/AdGuardHome.git .

# Create logo and theme assets
echo "==> Creating Warp NET branding assets..."
mkdir -p client/src/assets
mkdir -p client/src/components/App

cat > client/src/assets/logowarpnet.svg <<'EOF'
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 220 48" width="220" height="48">
  <rect width="220" height="48" rx="12" fill="#4183c4"/>
  <text x="50%" y="50%" text-anchor="middle" dy=".35em" font-family="Inter,Segoe UI,Arial,sans-serif" font-size="28" fill="#fff">
    Warp NET DNS
  </text>
</svg>
EOF

cat > client/src/components/App/warpnet-theme.css <<'EOF'
/* Warp NET DNS Theme - global styles */
:root {
  --warpnet-primary: #4183c4;
  --warpnet-accent: #2e2e2e;
  --warpnet-bg: #f4f7fa;
  --warpnet-brand: #00aaff;
  --warpnet-border: #e0e0e0;
  --warpnet-text: #212121;
  --warpnet-success: #44c767;
  --warpnet-danger: #c74444;
  --warpnet-warning: #ffa500;
  --warpnet-font: 'Inter', 'Segoe UI', Arial, sans-serif;
}
body {
  background: var(--warpnet-bg);
  color: var(--warpnet-text);
  font-family: var(--warpnet-font);
  margin: 0;
  padding: 0;
}
a {
  color: var(--warpnet-brand);
  text-decoration: none;
}
.header, .navbar, .sidebar {
  background: var(--warpnet-primary);
  color: #fff;
}
.logo {
  height: 48px;
  width: auto;
}
EOF

# Rebrand all AdGuard Home references in source code
echo "==> Rebranding AdGuard Home to Warp NET DNS..."
find . -type f \( -name "*.go" -o -name "*.js" -o -name "*.ts" -o -name "*.tsx" -o -name "*.jsx" -o -name "*.html" -o -name "*.md" -o -name "*.yaml" -o -name "*.yml" -o -name "*.json" \) \
  -not -path "*/node_modules/*" \
  -not -path "*/.git/*" \
  -not -path "*/vendor/*" \
  -exec sed -i \
    -e 's/AdGuard Home/Warp NET DNS/g' \
    -e 's/AdGuardHome/WarpNETDNS/g' \
    -e 's/adguardhome/warpnetdns/g' \
    -e 's/AdGuard/WarpNET/g' \
    {} + 2>/dev/null || true

# Replace logo
if [[ -f "client/src/assets/logo.svg" ]]; then
  cp client/src/assets/logowarpnet.svg client/src/assets/logo.svg
fi

# Build the binary
echo "==> Building WarpNETDNS binary for ${OS}/${ARCH}..."
export GOOS="${OS}"
export GOARCH="${ARCH}"
export CGO_ENABLED=0

make build-release CHANNEL=release VERBOSE=1 VERSION="${ADGUARD_VERSION}"

# Find the built binary
BINARY_PATH=""
if [[ -f "dist/AdGuardHome_${OS}_${ARCH}/AdGuardHome" ]]; then
  BINARY_PATH="dist/AdGuardHome_${OS}_${ARCH}/AdGuardHome"
elif [[ -f "AdGuardHome" ]]; then
  BINARY_PATH="AdGuardHome"
fi

if [[ -z "$BINARY_PATH" || ! -f "$BINARY_PATH" ]]; then
  echo "ERROR: Binary not found after build!"
  exit 1
fi

# Rename binary to WarpNETDNS
mv "$BINARY_PATH" "WarpNETDNS" 2>/dev/null || cp "$BINARY_PATH" "WarpNETDNS"

# Create release package
echo "==> Creating release package..."
RELEASE_DIR="warpnetdns-release"
mkdir -p "$RELEASE_DIR"

# Copy necessary files
cp WarpNETDNS "$RELEASE_DIR/"
[[ -f "LICENSE.txt" ]] && cp LICENSE.txt "$RELEASE_DIR/" || true
[[ -f "README.md" ]] && cp README.md "$RELEASE_DIR/" || true

# Create README for the release
cat > "$RELEASE_DIR/README.md" <<'EOF'
# Warp NET DNS

A rebranded version of AdGuard Home, customized for Warp NET services.

## Installation

Extract the archive and run:
```bash
sudo ./WarpNETDNS
```

For more information, visit: https://github.com/BrunoMiguelMota/warpnetdns
EOF

# Create tarball
PACKAGE_NAME="warpnetdns_${OS}_${ARCH}.tar.gz"
tar czf "$PACKAGE_NAME" -C "$RELEASE_DIR" .

echo "==> Build complete!"
echo "==> Package created: $WORK_DIR/$PACKAGE_NAME"
ls -lh "$PACKAGE_NAME"
