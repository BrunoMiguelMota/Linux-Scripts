#!/bin/bash

# AdGuard Home Geo-Restriction Script
# Allows access only from Portugal, Spain, France, and Denmark

set -e

# Configuration
ALLOWED_COUNTRIES=("PT" "ES" "FR" "DK")
GEOIP_DB="/usr/share/GeoIP/GeoLite2-Country.mmdb"
LOG_FILE="/var/log/adguard-geo-restrict.log"
IPTABLES_CHAIN="ADGUARD_GEO"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
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
    log "Checking and installing dependencies..."
    
    if ! command -v geoiplookup &> /dev/null && ! command -v mmdb-lookup &> /dev/null; then
        if [ -f /etc/debian_version ]; then
            apt-get update
            apt-get install -y geoip-bin geoip-database wget
        elif [ -f /etc/redhat-release ]; then
            yum install -y GeoIP GeoIP-data wget
        else
            log "Please install geoiplookup or mmdb-lookup manually"
            exit 1
        fi
    fi
    
    log "Dependencies installed successfully"
}

download_geoip_db() {
    log "Downloading latest GeoIP database..."
    
    mkdir -p /usr/share/GeoIP
    
    # Download GeoLite2 Country database (requires MaxMind account for direct download)
    # Alternative: use GeoIP legacy database
    if [ -f /etc/debian_version ]; then
        apt-get install -y geoip-database geoip-database-extra
    fi
    
    log "GeoIP database updated"
}

create_iptables_chain() {
    log "Creating iptables chain for geo-restriction..."
    
    # Create custom chain if it doesn't exist
    if ! iptables -L "$IPTABLES_CHAIN" -n &> /dev/null; then
        iptables -N "$IPTABLES_CHAIN"
        log "Created chain: $IPTABLES_CHAIN"
    else
        # Flush existing rules
        iptables -F "$IPTABLES_CHAIN"
        log "Flushed existing rules in chain: $IPTABLES_CHAIN"
    fi
    
    # Allow localhost
    iptables -A "$IPTABLES_CHAIN" -s 127.0.0.0/8 -j ACCEPT
    iptables -A "$IPTABLES_CHAIN" -s ::1/128 -j ACCEPT
    
    # Allow private networks (adjust as needed)
    iptables -A "$IPTABLES_CHAIN" -s 10.0.0.0/8 -j ACCEPT
    iptables -A "$IPTABLES_CHAIN" -s 172.16.0.0/12 -j ACCEPT
    iptables -A "$IPTABLES_CHAIN" -s 192.168.0.0/16 -j ACCEPT
    
    log "Base rules added to chain"
}

add_country_rules() {
    log "Adding country-specific rules..."
    
    for country in "${ALLOWED_COUNTRIES[@]}"; do
        log "Processing country: $country"
        
        # Download country IP ranges from IPdeny
        wget -q -O "/tmp/${country}.zone" "https://www.ipdeny.com/ipblocks/data/aggregated/${country,,}-aggregated.zone" 2>/dev/null || {
            log "Warning: Could not download IP ranges for $country"
            continue
        }
        
        # Add rules for each IP range
        while IFS= read -r ip_range; do
            if [ -n "$ip_range" ] && [[ ! "$ip_range" =~ ^# ]]; then
                iptables -A "$IPTABLES_CHAIN" -s "$ip_range" -j ACCEPT
            fi
        done < "/tmp/${country}.zone"
        
        rm -f "/tmp/${country}.zone"
        log "Added rules for $country"
    done
    
    # Drop all other traffic
    iptables -A "$IPTABLES_CHAIN" -j DROP
    log "Default DROP rule added"
}

apply_to_adguard() {
    log "Applying geo-restriction to AdGuard Home ports..."
    
    # AdGuard Home default ports
    ADGUARD_PORTS=(53 80 443 3000 853 784 8853 5443)
    
    for port in "${ADGUARD_PORTS[@]}"; do
        # Check if rule already exists
        if ! iptables -C INPUT -p tcp --dport "$port" -j "$IPTABLES_CHAIN" 2>/dev/null; then
            iptables -I INPUT -p tcp --dport "$port" -j "$IPTABLES_CHAIN"
        fi
        
        if ! iptables -C INPUT -p udp --dport "$port" -j "$IPTABLES_CHAIN" 2>/dev/null; then
            iptables -I INPUT -p udp --dport "$port" -j "$IPTABLES_CHAIN"
        fi
    done
    
    log "Geo-restriction applied to AdGuard Home ports"
}

save_rules() {
    log "Saving iptables rules..."
    
    if [ -f /etc/debian_version ]; then
        # Debian/Ubuntu
        if command -v netfilter-persistent &> /dev/null; then
            netfilter-persistent save
        else
            apt-get install -y iptables-persistent
            netfilter-persistent save
        fi
    elif [ -f /etc/redhat-release ]; then
        # RHEL/CentOS
        service iptables save
    fi
    
    log "Rules saved successfully"
}

setup_cron() {
    log "Setting up automatic IP list updates..."
    
    # Create update script
    cat > /usr/local/bin/update-adguard-geo.sh <<'EOF'
#!/bin/bash
/usr/local/bin/adguard-geo-restrict.sh --update
EOF
    
    chmod +x /usr/local/bin/update-adguard-geo.sh
    
    # Add to cron (weekly updates)
    if ! crontab -l 2>/dev/null | grep -q "update-adguard-geo.sh"; then
        (crontab -l 2>/dev/null; echo "0 3 * * 0 /usr/local/bin/update-adguard-geo.sh") | crontab -
        log "Cron job added for weekly updates"
    fi
}

remove_restrictions() {
    log "Removing geo-restrictions..."
    
    ADGUARD_PORTS=(53 80 443 3000 853 784 8853 5443)
    
    for port in "${ADGUARD_PORTS[@]}"; do
        iptables -D INPUT -p tcp --dport "$port" -j "$IPTABLES_CHAIN" 2>/dev/null || true
        iptables -D INPUT -p udp --dport "$port" -j "$IPTABLES_CHAIN" 2>/dev/null || true
    done
    
    iptables -F "$IPTABLES_CHAIN" 2>/dev/null || true
    iptables -X "$IPTABLES_CHAIN" 2>/dev/null || true
    
    save_rules
    log "Geo-restrictions removed"
}

show_status() {
    echo -e "${GREEN}=== AdGuard Home Geo-Restriction Status ===${NC}"
    echo
    
    if iptables -L "$IPTABLES_CHAIN" -n &> /dev/null; then
        echo -e "${GREEN}Status: ACTIVE${NC}"
        echo -e "\nAllowed Countries: ${ALLOWED_COUNTRIES[*]}"
        echo -e "\nChain Rules:"
        iptables -L "$IPTABLES_CHAIN" -n -v
    else
        echo -e "${RED}Status: NOT ACTIVE${NC}"
    fi
}

main() {
    case "${1:-install}" in
        install)
            echo -e "${GREEN}=== Installing AdGuard Home Geo-Restriction ===${NC}"
            check_root
            install_dependencies
            download_geoip_db
            create_iptables_chain
            add_country_rules
            apply_to_adguard
            save_rules
            setup_cron
            echo -e "${GREEN}Installation complete!${NC}"
            echo -e "Allowed countries: ${ALLOWED_COUNTRIES[*]}"
            ;;
        
        update)
            echo -e "${YELLOW}=== Updating Geo-Restriction Rules ===${NC}"
            check_root
            create_iptables_chain
            add_country_rules
            save_rules
            echo -e "${GREEN}Update complete!${NC}"
            ;;
        
        remove)
            echo -e "${RED}=== Removing Geo-Restrictions ===${NC}"
            check_root
            remove_restrictions
            echo -e "${GREEN}Removal complete!${NC}"
            ;;
        
        status)
            show_status
            ;;
        
        *)
            echo "Usage: $0 {install|update|remove|status}"
            echo
            echo "Commands:"
            echo "  install  - Install and configure geo-restrictions"
            echo "  update   - Update IP lists for allowed countries"
            echo "  remove   - Remove all geo-restrictions"
            echo "  status   - Show current status"
            exit 1
            ;;
    esac
}

main "$@"
