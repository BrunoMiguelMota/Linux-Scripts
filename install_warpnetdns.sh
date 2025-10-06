#!/bin/bash

# Warp NET DNS Installer: Rebrands AdGuard Home, applies custom logo/theme, and installs as a service

set -euo pipefail

log() { echo "$1" >&2; }
error_exit() { echo "$1" >&2; exit 1; }
is_command() { command -v "$1" >/dev/null 2>&1; }

check_required() {
	for cmd in tar wget sed; do
		is_command "$cmd" || error_exit "$cmd is required."
	done
}

# Configurable install location
out_dir="${1:-/opt}"
warpnet_dir="$out_dir/WarpNETDNS"

# Download AdGuard Home (base)
os="linux"
cpu="$(uname -m)"
case "$cpu" in
	'x86_64'|'amd64') cpu="amd64" ;;
	'aarch64'|'arm64') cpu="arm64" ;;
	*) error_exit "Unsupported CPU type: $cpu" ;;
esac

pkg_name="AdGuardHome_${os}_${cpu}.tar.gz"
binary_url="https://github.com/AdguardTeam/AdGuardHome/releases/latest/download/${pkg_name}"

# 1. Requirements
check_required

# 2. Download
log "Downloading base..."
wget -O "$pkg_name" "$binary_url"

# 3. Unpack and rename
mkdir -p "$out_dir"
tar -C "$out_dir" -xf "$pkg_name"
rm "$pkg_name"
[ -d "$out_dir/AdGuardHome" ] && mv "$out_dir/AdGuardHome" "$warpnet_dir"
[ -f "$warpnet_dir/AdGuardHome" ] && mv "$warpnet_dir/AdGuardHome" "$warpnet_dir/WarpNETDNS"

# 4. Apply logo and theme
assets_dir="$warpnet_dir/client/src/assets"
css_dir="$warpnet_dir/client/src/components/App"
mkdir -p "$assets_dir" "$css_dir"

log "Applying Warp NET DNS logo..."
cat > "$assets_dir/logowarpnet.svg" <<'EOF'
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 220 48" width="220" height="48">
  <rect width="220" height="48" rx="12" fill="#4183c4"/>
  <text x="50%" y="50%" text-anchor="middle" dy=".35em" font-family="Inter,Segoe UI,Arial,sans-serif" font-size="28" fill="#fff">
    Warp NET DNS
  </text>
</svg>
EOF
if [ -f "$assets_dir/logo.svg" ]; then mv "$assets_dir/logo.svg" "$assets_dir/logo_original.svg"; fi
cp "$assets_dir/logowarpnet.svg" "$assets_dir/logo.svg"

log "Applying CSS theme..."
cat > "$css_dir/index.css" <<'EOF'
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
a { color: var(--warpnet-brand); text-decoration: none; }
.header, .navbar, .sidebar { background: var(--warpnet-primary); color: #fff; }
.header .logo img { height: 48px; vertical-align: middle; }
.button, .btn {
  background: var(--warpnet-brand); color: #fff; border-radius: 3px; border: none; padding: 8px 18px; font-weight: 600; transition: background 0.2s;
}
.button:hover, .btn:hover { background: var(--warpnet-accent); }
.card, .panel, .box, .table {
  background: #fff; border-radius: 8px; box-shadow: 0 0 8px rgba(65, 131, 196, 0.04); border: 1px solid var(--warpnet-border); margin-bottom: 24px;
}
input, select, textarea {
  border: 1px solid var(--warpnet-border); border-radius: 4px; padding: 8px; outline: none;
}
::-webkit-scrollbar { width: 10px; background: var(--warpnet-bg); }
::-webkit-scrollbar-thumb { background: var(--warpnet-primary); border-radius: 10px; }
EOF

cat > "$css_dir/warpnet-theme.css" <<'EOF'
.warpnet-banner {
  background: linear-gradient(90deg, #4183c4 0%, #00aaff 100%);
  color: #fff; padding: 32px 0; text-align: center; font-size: 2rem; font-weight: 700; letter-spacing: 2px;
}
.warpnet-feature {
  border-left: 4px solid var(--warpnet-brand); padding: 16px 24px; background: #f8fcff; margin: 24px 0;
}
.logo { height: 48px; width: auto; }
EOF

# 5. Rebrand all UI source references
log "Rebranding UI source..."
ui_src="$warpnet_dir/client/src"
if [ -d "$ui_src" ]; then
	find "$ui_src" -type f \( -name "*.js" -o -name "*.tsx" -o -name "*.ts" -o -name "*.jsx" \) -exec sed -i \
		-e 's/AdGuard Home/Warp NET DNS/g' \
		-e 's/adguard home/Warp NET DNS/g' \
		-e 's/adguardhome/warpnetdns/g' \
		-e 's/AdGuardHome/WarpNETDNS/g' \
		-e 's/logo\.svg/logowarpnet.svg/g' \
		{} +
else
	log "Warning: UI source directory not found; skipping UI branding changes."
fi

# 6. Install as systemd service
log "Installing systemd service..."
sudo bash -c "cat > /etc/systemd/system/warpnetdns.service <<EOF
[Unit]
Description=Warp NET DNS
After=network.target

[Service]
Type=simple
ExecStart=$warpnet_dir/WarpNETDNS
WorkingDirectory=$warpnet_dir
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF"
sudo systemctl daemon-reload
sudo systemctl enable warpnetdns
sudo systemctl start warpnetdns

log "Warp NET DNS installation completed."
echo "Access the dashboard at http://<your-server-ip>:3000"
echo "Control the service with: sudo systemctl start|stop|restart|status warpnetdns"
