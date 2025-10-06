#!/bin/bash

# Warp NET DNS Installation Script for Ubuntu

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

customize_logo_and_theme() {
	local assets_dir="$warpnet_dir/client/src/assets"
	mkdir -p "$assets_dir"
	log "Downloading Warp NET logo..."
	wget -nv -O "$assets_dir/logowarpnet.svg" "https://warpnet.es/images/logowarpnet.svg"
	if [[ -f "$assets_dir/logo.svg" ]]; then
		mv "$assets_dir/logo.svg" "$assets_dir/logo_original.svg"
	fi
	cp "$assets_dir/logowarpnet.svg" "$assets_dir/logo.svg"

	# Update logo reference and product name in UI source
	if [[ -d "$warpnet_dir/client/src" ]]; then
		find "$warpnet_dir/client/src/" -type f \( -name "*.js" -o -name "*.tsx" \) -exec sed -i 's/logo\.svg/logowarpnet.svg/g' {} +
		find "$warpnet_dir/client/src/" -type f \( -name "*.js" -o -name "*.tsx" \) -exec sed -i 's/WARPNETDNS/Warp NET DNS/g' {} +
		find "$warpnet_dir/client/src/" -type f \( -name "*.js" -o -name "*.tsx" \) -exec sed -i 's/WarpNetDNS/Warp NET DNS/g' {} +
		find "$warpnet_dir/client/src/" -type f \( -name "*.js" -o -name "*.tsx" \) -exec sed -i 's/warpnetdns/Warp NET DNS/g' {} +
		log "Warp NET DNS logo and name customized!"
	else
		log "Warning: UI source directory not found; skipping UI logo and branding changes."
	fi

	# Download and apply Warpnet theme CSS
	local theme_repo="https://github.com/BrunoMiguelMota/es-warpnet"
	local theme_tmp_dir="/tmp/warpnet_theme"
	rm -rf "$theme_tmp_dir"
	git clone --depth=1 "$theme_repo" "$theme_tmp_dir"
	if [[ -f "$theme_tmp_dir/index.css" ]]; then
		cp "$theme_tmp_dir/index.css" "$warpnet_dir/client/src/components/App/index.css"
		log "Warp NET DNS theme applied!"
	else
		log "Warning: Couldn't find index.css in $theme_repo; skipping theme application."
	fi
	rm -rf "$theme_tmp_dir"
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
customize_logo_and_theme
install_service
show_success
