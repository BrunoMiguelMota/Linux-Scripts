#!/usr/bin/env bash
#
# interactive_squid_setup.sh
# Interactive installer and configurator for Squid proxy on Ubuntu.
# Usage: sudo bash interactive_squid_setup.sh

set -euo pipefail

# Ensure script is run as root
if [[ $EUID -ne 0 ]]; then
  echo "❌ Please run as root (sudo)." >&2
  exit 1
fi

echo "⚙️  Welcome to the Atlante Interactive Squid Setup!"

#
# 1) Ask for basic settings
#

# 1.1 Port
read -p "Enter proxy port [3128]: " PROXY_PORT
PROXY_PORT=${PROXY_PORT:-3128}

# 1.2 Allowed client network
read -p "Enter allowed client network CIDR (e.g. 192.168.1.0/24) [192.168.0.0/24]: " ALLOWED_NET
ALLOWED_NET=${ALLOWED_NET:-192.168.0.0/24}

#
# 2) Ask about Basic Authentication
#

read -p "Enable basic user/password authentication? [y/N]: " AUTH_CHOICE
AUTH_CHOICE=${AUTH_CHOICE,,}   # lowercase

if [[ $AUTH_CHOICE == "y" || $AUTH_CHOICE == "yes" ]]; then
  INSTALL_AUTH=true
  read -p "Enter auth username [proxyuser]: " AUTH_USER
  AUTH_USER=${AUTH_USER:-proxyuser}
  while true; do
    read -s -p "Enter password for '$AUTH_USER': " AUTH_PASS1
    echo
    read -s -p "Confirm password: " AUTH_PASS2
    echo
    [[ "$AUTH_PASS1" == "$AUTH_PASS2" ]] && break
    echo "⚠️  Passwords do not match. Please try again."
  done
else
  INSTALL_AUTH=false
fi

#
# 3) Install packages
#
echo "⬇️  Updating apt and installing Squid..."
apt update
DEBIAN_FRONTEND=noninteractive apt install -y squid ufw

#
# 4) Backup existing config
#
TIMESTAMP=$(date +%F_%T)
cp /etc/squid/squid.conf /etc/squid/squid.conf.BAK.$TIMESTAMP
echo "📦 Backup created: /etc/squid/squid.conf.BAK.$TIMESTAMP"

#
# 5) Build new squid.conf
#
echo "📝 Writing new /etc/squid/squid.conf..."
cat > /etc/squid/squid.conf <<EOF
# Squid Proxy Server Configuration (generated on ${TIMESTAMP})

# Listening port
http_port ${PROXY_PORT}

# ACLs
acl localhost src 127.0.0.1/32 ::1
acl allowed_network src ${ALLOWED_NET}

# Authenticated users (if enabled)
EOF

if $INSTALL_AUTH; then
  cat >> /etc/squid/squid.conf <<EOF
auth_param basic program /usr/lib/squid/basic_ncsa_auth /etc/squid/passwords
auth_param basic realm "Atlante Proxy"
acl authenticated proxy_auth REQUIRED
http_access allow authenticated
EOF
fi

cat >> /etc/squid/squid.conf <<EOF
# Access rules
http_access allow localhost
http_access allow allowed_network
http_access deny all

# Cache settings (defaults)
cache_mem 256 MB
cache_dir ufs /var/spool/squid 100 16 256
coredump_dir /var/spool/squid

# Logs
access_log /var/log/squid/access.log squid
cache_log /var/log/squid/cache.log
EOF

#
# 6) Set up authentication credentials if requested
#
if $INSTALL_AUTH; then
  echo "🔐 Setting up basic auth user..."
  apt install -y apache2-utils
  htpasswd -b -c /etc/squid/passwords "$AUTH_USER" "$AUTH_PASS1"
  chmod 640 /etc/squid/passwords
fi

#
# 7) Initialize cache, enable & restart Squid
#
echo "🗄️  Initializing cache directory..."
squid -z

echo "🚀 Enabling and restarting Squid service..."
systemctl enable squid
systemctl restart squid

#
# 8) Configure UFW
#
echo "🛡️  Opening port ${PROXY_PORT} in UFW..."
ufw allow "${PROXY_PORT}/tcp"

#
# 9) Summary
#
echo
echo "✅ Squid installation and configuration complete!"
echo "   - Listening on port: ${PROXY_PORT}"
echo "   - Allowed network:   ${ALLOWED_NET}"
if $INSTALL_AUTH; then
  echo "   - Basic auth:        ENABLED (user: ${AUTH_USER})"
else
  echo "   - Basic auth:        DISABLED"
fi
echo "   - Config backup:     /etc/squid/squid.conf.BAK.${TIMESTAMP}"
echo "   - Logs:              /var/log/squid/access.log"
echo
echo "📡 Point your clients to http://<server-ip>:${PROXY_PORT}"
echo "🔧 You can tweak /etc/squid/squid.conf further as needed."