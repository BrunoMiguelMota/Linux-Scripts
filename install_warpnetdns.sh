#!/bin/bash

# Warp NET DNS Installation Script for Ubuntu (All-in-one installer and theme)

set -euo pipefail

# --- Functions ---

log() {
	if [[ "${verbose:-0}" -gt 0 ]]; then
		echo "$1" 1>&2
	fi
}

error_exit() {
	echo "$1" 1>&2
	exit 1
}

usage() {
	echo 'Usage: install_warpnetdns.sh [-c channel] [-C cpu_type] [-h] [-O os] [-o output_dir] [-v]' 1>&2
	exit 2
}

is_command() {
	command -v "$1" >/dev/null 2>&1
}

check_required() {
	for cmd in tar wget curl sed git; do
		log "Checking $cmd"
		if ! is_command "$cmd"; then
			error_exit "$cmd is required to install Warp NET DNS on Ubuntu."
		fi
	done
}

parse_opts() {
	while getopts "C:c:hO:o:v" opt; do
		case "$opt" in
			C) cpu="$OPTARG" ;;
			c) channel="$OPTARG" ;;
			h) usage ;;
			O) os="$OPTARG" ;;
			o) out_dir="$OPTARG" ;;
			v) verbose='1' ;;
			*) log "Bad option $OPTARG"; usage ;;
		esac
	done
}

set_channel() {
	case "${channel:-release}" in
		'development' | 'edge' | 'beta' | 'release') ;;
		*) error_exit "Invalid channel '${channel:-release}'. Supported: development, edge, beta, release." ;;
	esac
	log "Channel: ${channel:-release}"
}

set_os() {
	if [[ -z "${os:-}" ]]; then
		os="linux"
	fi
	log "Operating system: $os"
}

set_cpu() {
	if [[ -z "${cpu:-}" ]]; then
		cpu="$(uname -m)"
		case "$cpu" in
			'x86_64' | 'amd64' ) cpu='amd64' ;;
			'aarch64' | 'arm64') cpu='arm64' ;;
			*) error_exit "Unsupported CPU type: $cpu" ;;
		esac
	fi
	log "CPU type: $cpu"
}

configure() {
	set_channel
	set_os
	set_cpu

	pkg_name="warpnetdns_${os}_${cpu}.tar.gz"
	# For demonstration, use an actual binary source; for production, build your own.
	binary_url="https://github.com/BrunoMiguelMota/warpnetdns/releases/latest/download/${pkg_name}"
	warpnet_dir="${out_dir:-/opt}/WarpNETDNS"
	log "Warp NET DNS will be installed into $warpnet_dir"
}

download() {
	log "Downloading package from $binary_url to $pkg_name"
	wget -O "$pkg_name" "$binary_url"
	log "Successfully downloaded $pkg_name"
}

unpack() {
	log "Unpacking package from $pkg_name into ${out_dir:-/opt}"
	mkdir -p "${out_dir:-/opt}"

	tar -C "${out_dir:-/opt}" -xf "$pkg_name"

	rm "$pkg_name"

	# Rename extracted directory if necessary
	if [[ -d "${out_dir:-/opt}/warpnetdns" ]]; then
		mv "${out_dir:-/opt}/warpnetdns" "$warpnet_dir"
	fi

	# Ensure binary is named WarpNETDNS
	if [[ -f "$warpnet_dir/warpnetdns" ]]; then
		mv "$warpnet_dir/warpnetdns" "$warpnet_dir/WarpNETDNS"
	fi
}

create_css_and_logo() {
	local assets_dir="$warpnet_dir/client/src/assets"
	mkdir -p "$assets_dir"

	log "Creating Warp NET logo SVG..."
	cat > "$assets_dir/logowarpnet.svg" <<'EOF'
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 220 48" width="220" height="48">
  <rect width="220" height="48" rx="12" fill="#4183c4"/>
  <text x="50%" y="50%" text-anchor="middle" dy=".35em" font-family="Inter,Segoe UI,Arial,sans-serif" font-size="28" fill="#fff">
    Warp NET DNS
  </text>
</svg>
EOF

	# Use our logo as the main logo
	if [[ -f "$assets_dir/logo.svg" ]]; then
		mv "$assets_dir/logo.svg" "$assets_dir/logo_original.svg"
	fi
	cp "$assets_dir/logowarpnet.svg" "$assets_dir/logo.svg"

	# Create index.css theme file
	local css_dir="$warpnet_dir/client/src/components/App"
	mkdir -p "$css_dir"
	cat > "$css_dir/index.css" <<'EOF'
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
.header .logo img {
  height: 48px;
  vertical-align: middle;
}
.button, .btn {
  background: var(--warpnet-brand);
  color: #fff;
  border-radius: 3px;
  border: none;
  padding: 8px 18px;
  font-weight: 600;
  transition: background 0.2s;
}
.button:hover, .btn:hover {
  background: var(--warpnet-accent);
}
.card, .panel, .box, .table {
  background: #fff;
  border-radius: 8px;
  box-shadow: 0 0 8px rgba(65, 131, 196, 0.04);
  border: 1px solid var(--warpnet-border);
  margin-bottom: 24px;
}
input, select, textarea {
  border: 1px solid var(--warpnet-border);
  border-radius: 4px;
  padding: 8px;
  outline: none;
}
::-webkit-scrollbar {
  width: 10px;
  background: var(--warpnet-bg);
}
::-webkit-scrollbar-thumb {
  background: var(--warpnet-primary);
  border-radius: 10px;
}
EOF

	# Additional theme components
	cat > "$warpnet_dir/client/src/components/App/warpnet-theme.css" <<'EOF'
/* Additional Warp NET DNS component theme overrides */
.warpnet-banner {
  background: linear-gradient(90deg, #4183c4 0%, #00aaff 100%);
  color: #fff;
  padding: 32px 0;
  text-align: center;
  font-size: 2rem;
  font-weight: 700;
  letter-spacing: 2px;
}
.warpnet-feature {
  border-left: 4px solid var(--warpnet-brand);
  padding: 16px 24px;
  background: #f8fcff;
  margin: 24px 0;
}
.logo {
  height: 48px;
  width: auto;
}
EOF
}

customize_branding() {
	local ui_src="$warpnet_dir/client/src"
	if [[ -d "$ui_src" ]]; then
		find "$ui_src" -type f \( -name "*.js" -o -name "*.tsx" -o -name "*.ts" -o -name "*.jsx" \) -exec sed -i \
			-e 's/AdGuard Home/Warp NET DNS/g' \
			-e 's/adguard home/Warp NET DNS/g' \
			-e 's/adguardhome/warpnetdns/g' \
			-e 's/AdGuardHome/WarpNETDNS/g' \
			-e 's/logo\.svg/logowarpnet.svg/g' \
			{} +
		log "Warp NET DNS branding applied to UI code."
	else
		log "Warning: UI source directory not found; skipping UI branding changes."
	fi
}

install_service() {
	log "Installing Warp NET DNS as a systemd service..."
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
	log "Warp NET DNS service started!"
}

show_success() {
	echo "Warp NET DNS installation completed!"
	echo "Access the dashboard at http://<your-server-ip>:3000"
	echo "Control the service with: sudo systemctl start|stop|restart|status warpnetdns"
}

# --- Main ---

channel='release'
verbose='0'
cpu=''
os=''
out_dir='/opt'

parse_opts "$@"
echo 'Starting Warp NET DNS installation script for Ubuntu...'

check_required
configure

download
unpack
create_css_and_logo
customize_branding
install_service
show_success
