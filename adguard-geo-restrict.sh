#!/bin/bash

# AdGuard Home Geo-Restriction Script
# Allows access only from Portugal, Spain, France, and Denmark

set -e

# Configuration
ALLOWED_COUNTRIES=("PT" "ES" "FR" "DK")
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
    
    if ! command -v wget &> /dev/null; then
        if [ -f /etc/debian_version ]; then
            apt-get update
            apt-get install -y wget curl
        elif [ -f /etc/redhat-release ]; then
            yum install -y wget curl
        fi
    fi
    
    log "Dependencies installed successfully"
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
    
    local total_ips=0
    
    for country in "${ALLOWED_COUNTRIES[@]}"; do
        log "Processing country: $country"
        
        # Download country IP ranges from IPdeny
        if wget -q -O "/tmp/${country}.zone" "https://www.ipdeny.com/ipblocks/data/aggregated/${country,,}-aggregated.zone" 2>/dev/null; then
            # Count and add rules for each IP range
            local count=0
            while IFS= read -r ip_range; do
                if [ -n "$ip_range" ] && [[ ! "$ip_range" =~ ^# ]]; then
                    iptables -A "$IPTABLES_CHAIN" -s "$ip_range" -j ACCEPT
                    ((count++))
                fi
            done < "/tmp/${country}.zone"
            
            total_ips=$((total_ips + count))
            log "Added $count IP ranges for $country"
            rm -f "/tmp/${country}.zone"
        else
            log "ERROR: Could not download IP ranges for $country"
            return 1
        fi
    done
    
    # Drop all other traffic
    iptables -A "$IPTABLES_CHAIN" -j LOG --log-prefix "ADGUARD-GEO-DROP: " --log-level 4
    iptables -A "$IPTABLES_CHAIN" -j DROP
    log "Default DROP rule added (Total IP ranges: $total_ips)"
}

apply_to_adguard() {
    log "Applying geo-restriction to AdGuard Home ports..."
    
    # AdGuard Home default ports
    ADGUARD_PORTS=(53 80 443 3000 853 784 8853 5443)
    
    for port in "${ADGUARD_PORTS[@]}"; do
        # Remove existing rules if present
        iptables -D INPUT -p tcp --dport "$port" -j "$IPTABLES_CHAIN" 2>/dev/null || true
        iptables -D INPUT -p udp --dport "$port" -j "$IPTABLES_CHAIN" 2>/dev/null || true
        
        # Add new rules
        iptables -I INPUT -p tcp --dport "$port" -j "$IPTABLES_CHAIN"
        iptables -I INPUT -p udp --dport "$port" -j "$IPTABLES_CHAIN"
    done
    
    log "Geo-restriction applied to AdGuard Home ports: ${ADGUARD_PORTS[*]}"
}

save_rules() {
    log "Saving iptables rules..."
    
    if [ -f /etc/debian_version ]; then
        # Debian/Ubuntu
        if ! command -v netfilter-persistent &> /dev/null; then
            log "Installing iptables-persistent..."
            echo iptables-persistent iptables-persistent/autosave_v4 boolean true | debconf-set-selections
            echo iptables-persistent iptables-persistent/autosave_v6 boolean true | debconf-set-selections
            apt-get install -y iptables-persistent
        fi
        netfilter-persistent save
    elif [ -f /etc/redhat-release ]; then
        # RHEL/CentOS
        service iptables save
    fi
    
    log "Rules saved successfully"
}

setup_cron() {
    log "Setting up automatic IP list updates..."
    
    # Copy this script to /usr/local/bin if not already there
    SCRIPT_PATH="/usr/local/bin/adguard-geo-restrict.sh"
    if [ "$0" != "$SCRIPT_PATH" ]; then
        cp "$0" "$SCRIPT_PATH"
        chmod +x "$SCRIPT_PATH"
    fi
    
    # Add to cron (weekly updates on Sunday at 3 AM)
    CRON_JOB="0 3 * * 0 $SCRIPT_PATH update >> $LOG_FILE 2>&1"
    if ! crontab -l 2>/dev/null | grep -qF "$SCRIPT_PATH update"; then
        (crontab -l 2>/dev/null; echo "$CRON_JOB") | crontab -
        log "Cron job added for weekly updates (Sundays at 3 AM)"
    else
        log "Cron job already exists"
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
    
    # Remove cron job
    crontab -l 2>/dev/null | grep -v "adguard-geo-restrict.sh" | crontab - || true
    
    log "Geo-restrictions removed"
}

show_status() {
    echo -e "${GREEN}=== AdGuard Home Geo-Restriction Status ===${NC}"
    echo
    
    if iptables -L "$IPTABLES_CHAIN" -n &> /dev/null; then
        echo -e "${GREEN}✓ Status: ACTIVE${NC}"
        echo -e "\nAllowed Countries: ${ALLOWED_COUNTRIES[*]}"
        
        # Count rules
        local rule_count=$(iptables -L "$IPTABLES_CHAIN" -n | grep -c "ACCEPT" || echo "0")
        echo -e "Active IP ranges: $rule_count"
        
        echo -e "\n${YELLOW}Protected Ports:${NC}"
        echo "  DNS: 53 (TCP/UDP)"
        echo "  HTTP: 80 (TCP)"
        echo "  HTTPS: 443 (TCP)"
        echo "  Admin: 3000 (TCP)"
        echo "  DNS-over-TLS: 853 (TCP)"
        echo "  DNS-over-QUIC: 784, 8853 (UDP)"
        echo "  DNSCrypt: 5443 (TCP/UDP)"
        
        echo -e "\n${YELLOW}Recent blocked attempts:${NC}"
        journalctl -k | grep "ADGUARD-GEO-DROP" | tail -5 || echo "  No blocked attempts logged yet"
        
        echo -e "\n${YELLOW}Cron Job:${NC}"
        if crontab -l 2>/dev/null | grep -q "adguard-geo-restrict"; then
            echo -e "  ${GREEN}✓ Automatic updates enabled (weekly)${NC}"
            crontab -l 2>/dev/null | grep "adguard-geo-restrict"
        else
            echo -e "  ${RED}✗ No automatic updates configured${NC}"
        fi
        
    else
        echo -e "${RED}✗ Status: NOT ACTIVE${NC}"
        echo "Run: sudo $0 install"
    fi
    echo
}

test_connection() {
    log "Testing geo-restriction..."
    echo -e "${YELLOW}Testing from various IPs...${NC}"
    
    # This would require actual testing from external IPs
    echo "To test from external location:"
    echo "1. From Portugal/Spain/France/Denmark: nslookup google.com YOUR_SERVER_IP"
    echo "2. From other countries: nslookup google.com YOUR_SERVER_IP (should timeout)"
}

main() {
    case "${1:-install}" in
        install)
            echo -e "${GREEN}=== Installing AdGuard Home Geo-Restriction ===${NC}"
            echo -e "${YELLOW}This will restrict AdGuard Home access to: ${ALLOWED_COUNTRIES[*]}${NC}"
            echo
            check_root
            install_dependencies
            create_iptables_chain
            if add_country_rules; then
                apply_to_adguard
                save_rules
                setup_cron
                echo
                echo -e "${GREEN}✓ Installation complete!${NC}"
                echo -e "Allowed countries: ${ALLOWED_COUNTRIES[*]}"
                echo
                echo -e "${YELLOW}Important:${NC}"
                echo "- Local network access (192.168.x.x, 10.x.x, etc.) is allowed"
                echo "- Automatic updates scheduled weekly"
                echo "- Check status: sudo $0 status"
                echo "- View logs: tail -f $LOG_FILE"
            else
                echo -e "${RED}✗ Installation failed - check log: $LOG_FILE${NC}"
                exit 1
            fi
            ;;
        
        update)
            echo -e "${YELLOW}=== Updating Geo-Restriction Rules ===${NC}"
            check_root
            create_iptables_chain
            if add_country_rules; then
                save_rules
                echo -e "${GREEN}✓ Update complete!${NC}"
            else
                echo -e "${RED}✗ Update failed${NC}"
                exit 1
            fi
            ;;
        
        remove)
            echo -e "${RED}=== Removing Geo-Restrictions ===${NC}"
            read -p "Are you sure? (yes/no): " confirm
            if [ "$confirm" = "yes" ]; then
                check_root
                remove_restrictions
                echo -e "${GREEN}✓ Removal complete!${NC}"
            else
                echo "Cancelled"
            fi
            ;;
        
        status)
            show_status
            ;;
        
        test)
            check_root
            test_connection
            ;;
        
        *)
            echo "Usage: $0 {install|update|remove|status|test}"
            echo
            echo "Commands:"
            echo "  install  - Install and configure geo-restrictions"
            echo "  update   - Update IP lists for allowed countries"
            echo "  remove   - Remove all geo-restrictions"
            echo "  status   - Show current status and statistics"
            echo "  test     - Show testing instructions"
            echo
            echo "Allowed countries: ${ALLOWED_COUNTRIES[*]}"
            exit 1
            ;;
    esac
}

main "$@"
