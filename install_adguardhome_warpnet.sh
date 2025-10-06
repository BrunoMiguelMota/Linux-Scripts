#!/bin/bash

# Warp NET DNS Installation Script

set -euo pipefail

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
	echo 'install_warpnet_dns.sh: usage: [-c channel] [-C cpu_type] [-h] [-O os] [-o output_dir] [-r|-R] [-u|-U] [-v|-V]' 1>&2
	exit 2
}

maybe_sudo() {
	if [[ "${use_sudo:-0}" -eq 0 ]]; then
		"$@"
	else
		"$sudo_cmd" "$@"
	fi
}

is_command() {
	command -v "$1" >/dev/null 2>&1
}

is_little_endian() {
	local result
	result="$(printf 'I' | hexdump -o | awk '{ print substr($2, 6, 1); exit; }')"
	[[ "$result" -eq 1 ]]
}

check_required() {
	local required
	case "${os:-}" in
		'freebsd' | 'linux' | 'openbsd') required="tar" ;;
		'darwin') required="unzip" ;;
		*) error_exit "unsupported operating system: '${os:-}'" ;;
	esac

	for cmd in $required; do
		log "checking $cmd"
		if ! is_command "$cmd"; then
			log "the full list of required software: [$required]"
			error_exit "$cmd is required to install Warp NET DNS via this script"
		fi
	done
}

check_out_dir() {
	if [[ -z "${out_dir:-}" ]]; then
		error_exit 'output directory should be presented'
	fi

	if [[ ! -d "$out_dir" ]]; then
		log "$out_dir directory will be created"
		mkdir -p "$out_dir"
	fi
}

parse_opts() {
	while getopts "C:c:hO:o:rRuUvV" opt; do
		case "$opt" in
			C) cpu="$OPTARG" ;;
			c) channel="$OPTARG" ;;
			h) usage ;;
			O) os="$OPTARG" ;;
			o) out_dir="$OPTARG" ;;
			R) reinstall='0' ;;
			U) uninstall='0' ;;
			r) reinstall='1' ;;
			u) uninstall='1' ;;
			V) verbose='0' ;;
			v) verbose='1' ;;
			*) log "bad option $OPTARG"; usage ;;
		esac
	done

	if [[ "${uninstall:-0}" -eq 1 && "${reinstall:-0}" -eq 1 ]]; then
		error_exit 'the -r and -u options are mutually exclusive'
	fi
}

set_channel() {
	case "${channel:-release}" in
		'development' | 'edge' | 'beta' | 'release') ;;
		*) error_exit "invalid channel '${channel:-release}' supported values are 'development', 'edge', 'beta', and 'release'" ;;
	esac
	log "channel: ${channel:-release}"
}

set_os() {
	if [[ -z "${os:-}" ]]; then
		os="$(uname -s)"
		case "$os" in
			'Darwin') os='darwin' ;;
			'FreeBSD') os='freebsd' ;;
			'Linux') os='linux' ;;
			'OpenBSD') os='openbsd' ;;
			*) error_exit "unsupported operating system: '$os'" ;;
		esac
	fi

	case "$os" in
		'darwin' | 'freebsd' | 'linux' | 'openbsd') ;;
		*) error_exit "unsupported operating system: '$os'" ;;
	esac
	log "operating system: $os"
}

set_cpu() {
	if [[ -z "${cpu:-}" ]]; then
		cpu="$(uname -m)"
		case "$cpu" in
			'x86_64' | 'x86-64' | 'x64' | 'amd64') cpu='amd64' ;;
			'i386' | 'i486' | 'i686' | 'i786' | 'x86') cpu='386' ;;
			'armv5l') cpu='armv5' ;;
			'armv6l') cpu='armv6' ;;
			'armv7l' | 'armv8l') cpu='armv7' ;;
			'aarch64' | 'arm64') cpu='arm64' ;;
			'mips' | 'mips64')
				if is_little_endian; then
					cpu="${cpu}le"
				fi
				cpu="${cpu}_softfloat"
				;;
			'riscv64') cpu='riscv64' ;;
			*) error_exit "unsupported cpu type: $cpu" ;;
		esac
	fi

	case "$cpu" in
		'amd64' | '386' | 'armv5' | 'armv6' | 'armv7' | 'arm64' | 'riscv64' | \
		'mips64le_softfloat' | 'mips64_softfloat' | 'mipsle_softfloat' | 'mips_softfloat') ;;
		*) error_exit "unsupported cpu type: $cpu" ;;
	esac

	log "cpu type: $cpu"
}

fix_darwin() {
	if [[ "${os:-}" != 'darwin' ]]; then
		return 0
	fi
	pkg_ext='zip'
	out_dir='/Applications'
}

fix_freebsd() {
	if [[ "${os:-}" != 'freebsd' ]]; then
		return 0
	fi
	rcd='/usr/local/etc/rc.d'
	if [[ ! -d "$rcd" ]]; then
		mkdir "$rcd"
	fi
}

download_curl() {
	local curl_output="${2:-}"
	if [[ -z "$curl_output" ]]; then
		curl -L -S -s "$1"
	else
		curl -L -S -o "$curl_output" -s "$1"
	fi
}

download_wget() {
	local wget_output="${2:--}"
	wget --no-verbose -O "$wget_output" "$1"
}

download_fetch() {
	local fetch_output="${2:-}"
	if [[ -z "$fetch_output" ]]; then
		fetch -o '-' "$1"
	else
		fetch -o "$fetch_output" "$1"
	fi
}

set_download_func() {
	if is_command 'curl'; then
		download_func='download_curl'
	elif is_command 'wget'; then
		download_func='download_wget'
	elif is_command 'fetch'; then
		download_func='download_fetch'
	else
		error_exit "either curl or wget is required to install Warp NET DNS via this script"
	fi
}

set_sudo_cmd() {
	case "${os:-}" in
		'openbsd') sudo_cmd='doas' ;;
		'darwin' | 'freebsd' | 'linux') sudo_cmd='sudo' ;;
		*) error_exit "unsupported operating system: '$os'" ;;
	esac
}

configure() {
	set_channel
	set_os
	set_cpu
	fix_darwin
	set_download_func
	set_sudo_cmd
	check_out_dir

	pkg_name="AdGuardHome_${os}_${cpu}.${pkg_ext:-tar.gz}"
	url="https://static.adtidy.org/adguardhome/${channel:-release}/${pkg_name}"
	agh_dir="${out_dir:-/opt}/WarpNETDNS"
	log "Warp NET DNS will be installed into $agh_dir"
}

is_root() {
	local user_id
	user_id="$(id -u)"
	if [[ "$user_id" -eq 0 ]]; then
		log 'script is executed with root privileges'
		return 0
	fi
	if is_command "${sudo_cmd:-sudo}"; then
		log 'note that Warp NET DNS requires root privileges to install using this script'
		return 1
	fi
	error_exit 'root privileges are required to install Warp NET DNS using this script
please, restart it with root privileges'
}

rerun_with_root() {
	local script_url='https://raw.githubusercontent.com/BrunoMiguelMota/es-warpnet/main/install_warpnet_dns.sh'
	local r='-R'
	local u='-U'
	local v='-V'
	if [[ "${reinstall:-0}" -eq 1 ]]; then r='-r'; fi
	if [[ "${uninstall:-0}" -eq 1 ]]; then u='-u'; fi
	if [[ "${verbose:-0}" -eq 1 ]]; then v='-v'; fi

	log 'restarting with root privileges'
	{ ${download_func:-download_curl} "$script_url" || echo 'exit 1'; } \
		| ${sudo_cmd:-sudo} bash -s -- -c "${channel:-release}" -C "${cpu:-}" -O "${os:-}" -o "${out_dir:-/opt}" "$r" "$u" "$v"
	exit 0
}

download() {
	log "downloading package from $url to $pkg_name"
	if ! ${download_func} "$url" "$pkg_name"; then
		error_exit "cannot download the package from $url into $pkg_name"
	fi
	log "successfully downloaded $pkg_name"
}

unpack() {
	log "unpacking package from $pkg_name into ${out_dir:-/opt}"
	mkdir -p "${out_dir:-/opt}"

	case "${pkg_ext:-tar.gz}" in
		'zip') unzip "$pkg_name" -d "${out_dir:-/opt}" ;;
		'tar.gz') tar -C "${out_dir:-/opt}" -f "$pkg_name" -x -z ;;
		*) error_exit "unexpected package extension: '${pkg_ext:-tar.gz}'" ;;
	esac

	rm "$pkg_name"

	# Rename the main directory to WarpNETDNS if it's AdGuardHome
	if [[ -d "${out_dir:-/opt}/AdGuardHome" ]]; then
		mv "${out_dir:-/opt}/AdGuardHome" "$agh_dir"
	fi

	# Rename the AdGuardHome binary to WarpNETDNS
	if [[ -f "$agh_dir/AdGuardHome" ]]; then
		mv "$agh_dir/AdGuardHome" "$agh_dir/WarpNETDNS"
	fi
}

handle_existing() {
	if [[ ! -d "$agh_dir" ]]; then
		log 'no need to uninstall'
		if [[ "${uninstall:-0}" -eq 1 ]]; then
			exit 0
		fi
		return 0
	fi

	local existing_warpnet_dns
	existing_warpnet_dns="$(ls -1 -A "$agh_dir")"
	if [[ -n "$existing_warpnet_dns" ]]; then
		log 'the existing Warp NET DNS installation is detected'
		if [[ "${reinstall:-0}" -ne 1 && "${uninstall:-0}" -ne 1 ]]; then
			error_exit "to reinstall/uninstall Warp NET DNS using this script specify one of the '-r' or '-u' flags"
		fi
		if (cd "$agh_dir" && ! ./WarpNETDNS -s stop || ! ./WarpNETDNS -s uninstall); then
			log "cannot uninstall Warp NET DNS from $agh_dir"
		fi
		rm -r "$agh_dir"
		log 'Warp NET DNS was successfully uninstalled'
	fi
	if [[ "${uninstall:-0}" -eq 1 ]]; then
		exit 0
	fi
}

install_service() {
	use_sudo='0'
	if [[ "${os:-}" = 'freebsd' ]]; then
		use_sudo='1'
	fi
	if (cd "$agh_dir" && maybe_sudo ./WarpNETDNS -s install); then
		return 0
	fi
	log "installation failed, removing $agh_dir"
	rm -r "$agh_dir"
	if [[ "${cpu:-}" = 'armv7' ]]; then
		cpu='armv5'
		reinstall='1'
		log "trying to use $cpu cpu"
		rerun_with_root
	fi
	error_exit 'cannot install Warp NET DNS as a service'
}

customize_warpnet_dns() {
	local assets_dir="${agh_dir}/client/src/assets"
	mkdir -p "$assets_dir"
	log "Downloading Warp NET logo..."
	wget -nv -O "$assets_dir/logowarpnet.svg" "https://warpnet.es/images/logowarpnet.svg"
	if [[ -f "$assets_dir/logo.svg" ]]; then
		mv "$assets_dir/logo.svg" "$assets_dir/logo_original.svg"
	fi
	cp "$assets_dir/logowarpnet.svg" "$assets_dir/logo.svg"

	# Change logo reference in source files
	find "${agh_dir}/client/src/" -type f \( -name "*.js" -o -name "*.tsx" \) \
		-exec sed -i 's/logo\.svg/logowarpnet.svg/g' {} \;

	# Change display name from "AdGuard Home" to "Warp NET DNS"
	find "${agh_dir}/client/src/" -type f \( -name "*.js" -o -name "*.tsx" \) \
		-exec sed -i 's/AdGuard Home/Warp NET DNS/g' {} \;
	log "Warp NET DNS customization complete!"
}

# Default values
channel='release'
reinstall='0'
uninstall='0'
verbose='0'
cpu=''
os=''
out_dir='/opt'
pkg_ext='tar.gz'
download_func='download_curl'
sudo_cmd='sudo'

parse_opts "$@"
echo 'starting Warp NET DNS installation script'

configure
check_required

if ! is_root; then
	rerun_with_root
fi

fix_freebsd
handle_existing

download
unpack

customize_warpnet_dns

install_service

printf '%s\n' \
	'Warp NET DNS is now installed and running' \
	'you can control the service status with the following commands:' \
	"$sudo_cmd ${agh_dir}/WarpNETDNS -s start|stop|restart|status|install|uninstall"
