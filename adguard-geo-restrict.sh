#!/bin/bash

# AdGuard Home Geo-Restriction Script using Block Lists
# Blocks ALL countries except Portugal, Spain, France, and Denmark
# Uses https://www.ipdeny.com/ipblocks/

set -e

# Configuration
ALLOWED_COUNTRIES=("pt" "es" "fr" "dk")  # lowercase for ipdeny.com
COUNTRY_NAMES=("Portugal" "Spain" "France" "Denmark")
LOG_FILE="/var/log/adguard-geo-restrict.log"
IPTABLES_CHAIN="ADGUARD_GEO_ALLOW"
IPSET_NAME="adguard_allowed_countries"
TEMP_DIR="/tmp/adguard-geo"
IPDENY_URL="https://www.ipdeny.com/ipblocks/data/aggregated"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

check_root() {
    if [ "$EUID" -ne 0 ]; then 
        echo -e "${RED}Error: This script must be run as root${NC}"
        exit 1
    fi
}

install_dependencies() {
    log "Installing required dependencies..."
    
    if [ -f /etc/debian_version ]; then
        apt-get update -qq
        apt-get install -y ipset iptables wget curl
    elif [ -f /etc/redhat-release ]; then
        yum install -y ipset iptables wget curl
    else
        log "ERROR: Unsupported distribution"
        exit 1
    fi
    
    log "Dependencies installed successfully"
}

create_ipset() {
    log "Creating ipset for allowed countries..."
    
    # Remove existing ipset if exists
    ipset destroy "$IPSET_NAME" 2>/dev/null || true
    
    # Create new ipset (hash:net is optimized for CIDR blocks)
    ipset create "$IPSET_NAME" hash:net maxelem 100000 comment
    
    log "IPSet '$IPSET_NAME' created"
}

download_and_add_country_ips() {
    log "Downloading and adding IP ranges for allowed countries..."
    
    mkdir -p "$TEMP_DIR"
    local total_ranges=0
    
    for i in "${!ALLOWED_COUNTRIES[@]}"; do
        local country="${ALLOWED_COUNTRIES[$i]}"
        local country_name="${COUNTRY_NAMES[$i]}"
        
        log "Processing $country_name ($country)..."
        
        local zone_file="$TEMP_DIR/${country}-aggregated.zone"
        local url="$IPDENY_URL/${country}-aggregated.zone"
        
        if wget -q -O "$zone_file" "$url"; then
            local count=0
            while IFS= read -r ip_range; do
                # Skip empty lines and comments
                if [ -n "$ip_range" ] && [[ ! "$ip_range" =~ ^# ]]; then
                    ipset add "$IPSET_NAME" "$ip_range" comment "$country_name" 2>/dev/null || true
                    ((count++))
                fi
            done < "$zone_file"
            
            total_ranges=$((total_ranges + count))
            log "✓ Added $count IP ranges for $country_name"
        else
            log "ERROR: Failed to download IP ranges for $country_name from $url"
            return 1
        fi
    done
    
    log "Total IP ranges added: $total_ranges"
    rm -rf "$TEMP_DIR"
}

create_iptables_rules() {
    log "Creating iptables rules..."
    
    # Create custom chain if it doesn't exist
    if ! iptables -L "$IPTABLES_CHAIN" -n &> /dev/null; then
        iptables -N "$IPTABLES_CHAIN"
        log "Created chain: $IPTABLES_CHAIN"
    else
        iptables -F "$IPTABLES_CHAIN"
        log "Flushed existing chain: $IPTABLES_CHAIN"
    fi
    
    # Allow localhost
    iptables -A "$IPTABLES_CHAIN" -s 127.0.0.0/8 -j ACCEPT -m comment --comment "Localhost"
    iptables -A "$IPTABLES_CHAIN" -s ::1/128 -j ACCEPT -m comment --comment "Localhost IPv6"
    
    # Allow private networks (LAN access)
    iptables -A "$IPTABLES_CHAIN" -s 10.0.0.0/8 -j ACCEPT -m comment --comment "Private Network"
    iptables -A "$IPTABLES_CHAIN" -s 172.16.0.0/12 -j ACCEPT -m comment --comment "Private Network"
    iptables -A "$IPTABLES_CHAIN" -s 192.168.0.0/16 -j ACCEPT -m comment --comment "Private Network"
    
    # Allow IPs from allowed countries (using ipset)
    iptables -A "$IPTABLES_CHAIN" -m set --match-set "$IPSET_NAME" src -j ACCEPT -m comment --comment "Allowed Countries"
    
    # Log and drop everything else
    iptables -A "$IPTABLES_CHAIN" -m limit --limit 5/min -j LOG --log-prefix "ADGUARD-GEO-BLOCK: " --log-level 4
    iptables -A "$IPTABLES_CHAIN" -j DROP -m comment --comment "Block all other countries"
    
    log "Iptables chain configured"
}

apply_to_adguard_ports() {
    log "Applying geo-restriction to AdGuard Home ports..."
    
    # AdGuard Home ports:
    # 53 - DNS
    # 80 - HTTP (Web interface if not using 3000)
    # 443 - HTTPS
    # 3000 - Web interface (default)
    # 853 - DNS-over-TLS
    # 784 - DNS-over-QUIC
    # 8853 - DNS-over-QUIC (alternative)
    # 5443 - DNSCrypt
    local ADGUARD_PORTS=(53 80 443 3000 853 784 8853 5443)
    
    for port in "${ADGUARD_PORTS[@]}"; do
        # Remove old rules if they exist
        iptables -D INPUT -p tcp --dport "$port" -j "$IPTABLES_CHAIN" 2>/dev/null || true
        iptables -D INPUT -p udp --dport "$port" -j "$IPTABLES_CHAIN" 2>/dev/null || true
        
        # Add new rules at the top of INPUT chain
        iptables -I INPUT 1 -p tcp --dport "$port" -j "$IPTABLES_CHAIN" -m comment --comment "AdGuard-Geo-Port-$port"
        iptables -I INPUT 1 -p udp --dport "$port" -j "$IPTABLES_CHAIN" -m comment --comment "AdGuard-Geo-Port-$port"
    done
    
    log "Geo-restrictions applied to ports: ${ADGUARD_PORTS[*]}"
}

save_configuration() {
    log "Saving configuration..."
    
    # Save ipset
    ipset save "$IPSET_NAME" > /etc/ipset-adguard.conf
    
    # Save iptables
    if [ -f /etc/debian_version ]; then
        # Install iptables-persistent if not present
        if ! command -v netfilter-persistent &> /dev/null; then
            echo iptables-persistent iptables-persistent/autosave_v4 boolean true | debconf-set-selections
            echo iptables-persistent iptables-persistent/autosave_v6 boolean true | debconf-set-selections
            DEBIAN_FRONTEND=noninteractive apt-get install -y iptables-persistent
        fi
        
        # Save rules
        netfilter-persistent save
        
        # Create systemd service to restore ipset on boot
        cat > /etc/systemd/system/adguard-ipset.service <<'EOF'
[Unit]
Description=Restore AdGuard Geo-Restriction IPSet
Before=netfilter-persistent.service
Before=iptables.service

[Service]
Type=oneshot
ExecStart=/sbin/ipset restore -f /etc/ipset-adguard.conf
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
        
        systemctl daemon-reload
        systemctl enable adguard-ipset.service
        
    elif [ -f /etc/redhat-release ]; then
        service iptables save
        ipset save > /etc/sysconfig/ipset
    fi
    
    log "Configuration saved and will persist across reboots"
}

setup_automatic_updates() {
    log "Setting up automatic IP list updates..."
    
    # Copy script to proper location if needed
    SCRIPT_PATH="/usr/local/bin/adguard-geo-restrict.sh"
    if [ "$(readlink -f "$0")" != "$SCRIPT_PATH" ]; then
        cp "$(readlink -f "$0")" "$SCRIPT_PATH"
        chmod +x "$SCRIPT_PATH"
    fi
    
    # Create systemd timer for weekly updates
    cat > /etc/systemd/system/adguard-geo-update.service <<EOF
[Unit]
Description=Update AdGuard Geo-Restriction IP Lists
After=network-online.target

[Service]
Type=oneshot
ExecStart=$SCRIPT_PATH update
StandardOutput=journal
StandardError=journal
EOF

    cat > /etc/systemd/system/adguard-geo-update.timer <<'EOF'
[Unit]
Description=Weekly update of AdGuard Geo-Restriction IP Lists

[Timer]
OnCalendar=Sun *-*-* 03:00:00
Persistent=true

[Install]
WantedBy=timers.target
EOF

    systemctl daemon-reload
    systemctl enable adguard-geo-update.timer
    systemctl start adguard-geo-update.timer
    
    log "Automatic weekly updates enabled (Sundays at 3 AM)"
}

remove_all() {
    log "Removing all geo-restrictions..."
    
    # Remove iptables rules
    local ADGUARD_PORTS=(53 80 443 3000 853 784 8853 5443)
    for port in "${ADGUARD_PORTS[@]}"; do
        iptables -D INPUT -p tcp --dport "$port" -j "$IPTABLES_CHAIN" 2>/dev/null || true
        iptables -D INPUT -p udp --dport "$port" -j "$IPTABLES_CHAIN" 2>/dev/null || true
    done
    
    # Remove chain
    iptables -F "$IPTABLES_CHAIN" 2>/dev/null || true
    iptables -X "$IPTABLES_CHAIN" 2>/dev/null || true
    
    # Remove ipset
    ipset destroy "$IPSET_NAME" 2>/dev/null || true
    
    # Remove systemd services
    systemctl stop adguard-geo-update.timer 2>/dev/null || true
    systemctl disable adguard-geo-update.timer 2>/dev/null || true
    rm -f /etc/systemd/system/adguard-geo-update.* 2>/dev/null || true
    rm -f /etc/systemd/system/adguard-ipset.service 2>/dev/null || true
    systemctl daemon-reload
    
    # Remove saved configs
    rm -f /etc/ipset-adguard.conf 2>/dev/null || true
    
    # Save changes
    if command -v netfilter-persistent &> /dev/null; then
        netfilter-persistent save
    fi
    
    log "All geo-restrictions removed"
}

show_status() {
    echo -e "\n${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║${NC}     ${GREEN}AdGuard Home Geo-Restriction Status${NC}                    ${BLUE}║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}\n"
    
    # Check if active
    if ipset list "$IPSET_NAME" &>/dev/null && iptables -L "$IPTABLES_CHAIN" -n &>/dev/null; then
        echo -e "${GREEN}✓ Status: ACTIVE${NC}\n"
        
        # Allowed countries
        echo -e "${YELLOW}Allowed Countries:${NC}"
        for name in "${COUNTRY_NAMES[@]}"; do
            echo -e "  ${GREEN}✓${NC} $name"
        done
        
        # IP ranges count
        local ip_count=$(ipset list "$IPSET_NAME" | grep -c "^[0-9]" || echo "0")
        echo -e "\n${YELLOW}IP Ranges Loaded:${NC} $ip_count"
        
        # Protected ports
        echo -e "\n${YELLOW}Protected Ports:${NC}"
        echo -e "  ${BLUE}53${NC}   - DNS (TCP/UDP)"
        echo -e "  ${BLUE}80${NC}   - HTTP"
        echo -e "  ${BLUE}443${NC}  - HTTPS"
        echo -e "  ${BLUE}3000${NC} - Admin Panel"
        echo -e "  ${BLUE}853${NC}  - DNS-over-TLS"
        echo -e "  ${BLUE}784${NC}  - DNS-over-QUIC"
        echo -e "  ${BLUE}8853${NC} - DNS-over-QUIC (alt)"
        echo -e "  ${BLUE}5443${NC} - DNSCrypt"
        
        # Recent blocks
        echo -e "\n${YELLOW}Recent Blocked Attempts:${NC}"
        local blocks=$(journalctl -k --since "24 hours ago" 2>/dev/null | grep "ADGUARD-GEO-BLOCK" | tail -5)
        if [ -n "$blocks" ]; then
            echo "$blocks" | while read -r line; do
                echo -e "  ${RED}✗${NC} $line"
            done
        else
            echo -e "  ${GREEN}No blocked attempts in last 24 hours${NC}"
        fi
        
        # Automatic updates status
        echo -e "\n${YELLOW}Automatic Updates:${NC}"
        if systemctl is-enabled adguard-geo-update.timer &>/dev/null; then
            local next_run=$(systemctl status adguard-geo-update.timer 2>/dev/null | grep "Trigger:" | cut -d':' -f2- | xargs)
            echo -e "  ${GREEN}✓ Enabled${NC}"
            [ -n "$next_run" ] && echo -e "  Next update: $next_run"
        else
            echo -e "  ${RED}✗ Disabled${NC}"
        fi
        
        # Chain statistics
        echo -e "\n${YELLOW}Firewall Statistics:${NC}"
        iptables -L "$IPTABLES_CHAIN" -v -n | grep -E "Chain|pkts" | head -2
        
    else
        echo -e "${RED}✗ Status: NOT ACTIVE${NC}\n"
        echo -e "Run: ${YELLOW}sudo $0 install${NC} to enable geo-restrictions"
    fi
    
    echo
}

test_setup() {
    echo -e "\n${BLUE}=== Testing Geo-Restriction Setup ===${NC}\n"
    
    # Get server's public IP
    echo -e "${YELLOW}Server Public IP:${NC}"
    curl -s ifconfig.me && echo
    
    echo -e "\n${YELLOW}How to test:${NC}"
    echo -e "
${GREEN}From allowed countries (PT, ES, FR, DK):${NC}
  dig @YOUR_SERVER_IP google.com
  # Should work ✓

${RED}From other countries:${NC}
  dig @YOUR_SERVER_IP google.com
  # Should timeout ✗

${YELLOW}Check logs for blocked attempts:${NC}
  sudo journalctl -k -f | grep ADGUARD-GEO-BLOCK

${YELLOW}Test with online tools:${NC}
  - https://www.dnsleaktest.com/
  - Use VPN to test from different countries
"
}

# Main execution
main() {
    case "${1:-}" in
        install)
            echo -e "${GREEN}╔════════════════════════════════════════════════════════════════╗${NC}"
            echo -e "${GREEN}║${NC}  Installing AdGuard Home Geo-Restriction                   ${GREEN}║${NC}"
            echo -e "${GREEN}╚════════════════════════════════════════════════════════════════╝${NC}\n"
            echo -e "${YELLOW}Blocking ALL countries except:${NC} ${COUNTRY_NAMES[*]}\n"
            
            check_root
            install_dependencies
            create_ipset
            
            if download_and_add_country_ips; then
                create_iptables_rules
                apply_to_adguard_ports
                save_configuration
                setup_automatic_updates
                
                echo
                echo -e "${GREEN}╔════════════════════════════════════════════════════════════════╗${NC}"
                echo -e "${GREEN}║${NC}  ${GREEN}✓${NC} Installation Complete!                                  ${GREEN}║${NC}"
                echo -e "${GREEN}╚════════════════════════════════════════════════════════════════╝${NC}\n"
                echo -e "${YELLOW}Configuration:${NC}"
                echo -e "  • Allowed: ${COUNTRY_NAMES[*]}"
                echo -e "  • Blocked: All other countries"
                echo -e "  • Local networks: Allowed"
                echo -e "  • Auto-updates: Enabled (weekly)\n"
                echo -e "${YELLOW}Commands:${NC}"
                echo -e "  Status:  ${BLUE}sudo $0 status${NC}"
                echo -e "  Update:  ${BLUE}sudo $0 update${NC}"
                echo -e "  Test:    ${BLUE}sudo $0 test${NC}"
                echo -e "  Logs:    ${BLUE}tail -f $LOG_FILE${NC}\n"
            else
                echo -e "${RED}✗ Installation failed. Check log: $LOG_FILE${NC}"
                exit 1
            fi
            ;;
            
        update)
            echo -e "${YELLOW}=== Updating IP Lists ===${NC}\n"
            check_root
            create_ipset
            
            if download_and_add_country_ips; then
                save_configuration
                echo -e "\n${GREEN}✓ Update complete!${NC}"
            else
                echo -e "${RED}✗ Update failed${NC}"
                exit 1
            fi
            ;;
            
        remove)
            echo -e "${RED}=== Removing Geo-Restrictions ===${NC}\n"
            echo -e "${YELLOW}This will allow access from ALL countries.${NC}"
            read -p "Are you sure? (yes/no): " confirm
            
            if [ "$confirm" = "yes" ]; then
                check_root
                remove_all
                echo -e "\n${GREEN}✓ Geo-restrictions removed${NC}"
            else
                echo "Cancelled"
            fi
            ;;
            
        status)
            show_status
            ;;
            
        test)
            test_setup
            ;;
            
        *)
            echo -e "${BLUE}AdGuard Home Geo-Restriction Manager${NC}"
            echo
            echo "Usage: $0 {install|update|remove|status|test}"
            echo
            echo "Commands:"
            echo -e "  ${GREEN}install${NC}  - Install and configure geo-restrictions"
            echo -e "  ${YELLOW}update${NC}   - Update IP lists for allowed countries"
            echo -e "  ${RED}remove${NC}   - Remove all geo-restrictions"
            echo -e "  ${BLUE}status${NC}   - Show current status and statistics"
            echo -e "  ${BLUE}test${NC}     - Show testing instructions"
            echo
            echo -e "Allowed countries: ${GREEN}${COUNTRY_NAMES[*]}${NC}"
            echo -e "Blocked: ${RED}All other countries${NC}"
            exit 1
            ;;
    esac
}

main "$@"
