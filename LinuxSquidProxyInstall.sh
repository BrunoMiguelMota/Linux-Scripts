#!/usr/bin/env bash
#
# interactive_squid_setup_ubuntu24.sh
# Interactive Squid proxy installer/configurator for Ubuntu 24.04
# Usage: sudo bash interactive_squid_setup_ubuntu24.sh

set -euo pipefail

# 0) Ensure root
if [[ $EUID -ne 0 ]]; then
  echo "❌ Please run as root (sudo)." >&2
  exit 1
fi

echo "⚙️  Atlante Proxy Setup (Ubuntu 24.04)"

# 1) Collect user settings

read -p "Proxy listen port [3128]: " PROXY_PORT
PROXY_PORT=${PROXY_PORT:-3128}

read -p "Allowed network CIDR [192.168.0.0/24]: " ALLOWED_NET
ALLOWED_NET=${ALLOWED_NET:-192.168.0.0/24}

read -p "Enable basic auth? [y/N]: " AUTH_CHOICE
AUTH_CHOICE=${AUTH_CHOICE,,}

if [[ $AUTH_CHOICE =~ ^(y|yes)$ ]]; then
  INSTALL_AUTH=true
  read -p "Auth username [proxyuser]: " AUTH_USER
  AUTH_USER=${AUTH_USER:-proxyuser}
  while true; do
    read -s -p "Password for '$AUTH_USER': " PASS1; echo
    read -s -p "Confirm password: " PASS2; echo
    [[ "$PASS1" == "$PASS2" ]] && break
    echo "⚠️  Passwords do not match, try again."
  done
else
  INSTALL_AUTH=false
fi

# 2) Install packages
echo "⬇️  Updating & installing packages..."
apt update
DEBIAN_FRONTEND=noninteractive apt install -y squid ufw apache2-utils

# 3) Backup original config
TIMESTAMP=$(date +%F_%H%M%S)
cp /etc/squid/squid.conf /etc/squid/squid.conf.BAK.$TIMESTAMP
echo "📦 Backup: /etc/squid/squid.conf.BAK.$TIMESTAMP"

# 4) Generate new squid.conf
echo "📝 Writing /etc/squid/squid.conf..."
cat > /etc/squid/squid.conf <<EOF
# Squid Proxy Config (generated $TIMESTAMP)

http_port ${PROXY_PORT}

# ACLs
acl localhost src 127.0.0.1/32 ::1
acl allowed_network src ${ALLOWED_NET}

EOF

if $INSTALL_AUTH; then
  cat >> /etc/squid/squid.conf <<EOF
# Basic Auth
auth_param basic program /usr/lib/squid/basic_ncsa_auth /etc/squid/passwords
auth_param basic realm "Atlante Proxy"
acl authenticated proxy_auth REQUIRED

EOF
fi

cat >> /etc/squid/squid.conf <<EOF
# Access Rules
http_access allow localhost
$( $INSTALL_AUTH && echo "http_access allow authenticated" )
http_access allow allowed_network
http_access deny all

# Cache
cache_mem 256 MB
cache_dir ufs /var/spool/squid 100 16 256
coredump_dir /var/spool/squid

# Logs
access_log /var/log/squid/access.log squid
cache_log  /var/log/squid/cache.log
EOF

# 5) Set up auth user if requested
if $INSTALL_AUTH; then
  echo "🔐 Creating htpasswd entry..."
  htpasswd -b -c /etc/squid/passwords "$AUTH_USER" "$PASS1"
  chmod 640 /etc/squid/passwords
fi

# 6) Initialize cache & start service
echo "🗄️  Initializing cache..."
squid -z

echo "🚀 Enabling & starting Squid..."
systemctl enable --now squid

# 7) Configure UFW
echo "🛡️  Configuring UFW..."
ufw default deny incoming
ufw default allow outgoing
ufw allow "${PROXY_PORT}/tcp" comment 'Squid proxy'
ufw allow ssh comment 'SSH access'
ufw --force enable

# 8) Summary
cat <<EOF

✅ Squid is up and running!
   • Port:            ${PROXY_PORT}
   • Allowed net:     ${ALLOWED_NET}
   • Basic auth:      $( $INSTALL_AUTH && echo "ENABLED ($AUTH_USER)" || echo "DISABLED" )
   • Config backup:   /etc/squid/squid.conf.BAK.${TIMESTAMP}
   • Access log:      /var/log/squid/access.log

👉 Point clients to http://<YOUR-SERVER-IP>:${PROXY_PORT}

You can tweak /etc/squid/squid.conf further and reload with:
   sudo systemctl reload squid

EOF
