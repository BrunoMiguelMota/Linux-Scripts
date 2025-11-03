#!/bin/bash

#######################################################
# AdGuard Home Continuous Watchdog Monitor
# Automatically detects and restarts frozen AdGuard Home
# 
# Author: BrunoMiguelMota
# Repository: https://github.com/BrunoMiguelMota/Linux-Scripts
# Issue: https://github.com/BrunoMiguelMota/Linux-Scripts/issues/4
#
# Installation:
#   sudo bash adguard-watchdog-monitor.sh install
#
# Manual run (for testing):
#   sudo bash adguard-watchdog-monitor.sh
#######################################################

# Configuration
AGH_HOST="127.0.0.1"
AGH_PORT="3000"
CHECK_INTERVAL="30"  # Check every 30 seconds
TIMEOUT="10"         # Timeout for health check
MAX_CONSECUTIVE_FAILURES="2"  # Restart after 2 consecutive failures
LOG_FILE="/var/log/adguard-monitor.log"
SCRIPT_DIR="/opt/adguard-monitor"
SCRIPT_NAME="adguard-watchdog.sh"

# Failure counter
FAILURE_COUNT=0

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

#######################################################
# Functions
#######################################################

# Function to log messages
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Function to check if AdGuard Home is responsive
check_health() {
    if timeout "$TIMEOUT" curl -s --connect-timeout 5 \
       "http://${AGH_HOST}:${AGH_PORT}/control/status" > /dev/null 2>&1; then
        return 0  # Success
    else
        return 1  # Failed
    fi
}

# Function to check if service is running
is_service_running() {
    systemctl is-active --quiet AdGuardHome
    return $?
}

# Function to restart AdGuard Home
restart_adguard() {
    log_message "${RED}🔴 FREEZE DETECTED! AdGuard Home is unresponsive. Initiating immediate restart...${NC}"
    
    # Force stop
    log_message "Stopping AdGuard Home (forced)..."
    systemctl stop AdGuardHome
    sleep 2
    
    # Kill any remaining processes
    pkill -9 AdGuardHome 2>/dev/null || true
    sleep 1
    
    # Start service
    log_message "Starting AdGuard Home..."
    systemctl start AdGuardHome
    sleep 5
    
    # Verify restart
    if check_health; then
        log_message "${GREEN}✅ SUCCESS! AdGuard Home restarted and is now responsive${NC}"
        FAILURE_COUNT=0
        return 0
    else
        log_message "${RED}❌ WARNING! AdGuard Home restarted but still not responsive${NC}"
        return 1
    fi
}

#######################################################
# Installation Function
#######################################################

install_watchdog() {
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  AdGuard Home Watchdog Monitor - Installation${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo ""
    
    # Check if running as root
    if [ "$EUID" -ne 0 ]; then 
        echo -e "${RED}Error: Please run installation as root (use sudo)${NC}"
        exit 1
    fi
    
    # Install dependencies
    echo "Installing dependencies..."
    apt-get update -qq
    apt-get install -y curl systemd > /dev/null 2>&1
    
    # Create directories
    echo "Creating directories..."
    mkdir -p "$SCRIPT_DIR"
    mkdir -p "$(dirname "$LOG_FILE")"
    
    # Copy script to installation directory
    echo "Installing script..."
    cp "$0" "${SCRIPT_DIR}/${SCRIPT_NAME}"
    chmod +x "${SCRIPT_DIR}/${SCRIPT_NAME}"
    
    # Create systemd service
    echo "Creating systemd service..."
    cat > /etc/systemd/system/adguard-watchdog.service << 'SERVICE_EOF'
[Unit]
Description=AdGuard Home Watchdog - Instant Freeze Detection
After=AdGuardHome.service
Wants=AdGuardHome.service

[Service]
Type=simple
ExecStart=/opt/adguard-monitor/adguard-watchdog.sh run
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal
SyslogIdentifier=adguard-watchdog
User=root
StartLimitInterval=0

[Install]
WantedBy=multi-user.target
SERVICE_EOF
    
    # Create AdGuardHome service override
    echo "Configuring AdGuard Home service..."
    mkdir -p /etc/systemd/system/AdGuardHome.service.d
    cat > /etc/systemd/system/AdGuardHome.service.d/watchdog.conf << 'OVERRIDE_EOF'
[Service]
RestartSec=5
OVERRIDE_EOF
    
    # Create log file
    touch "$LOG_FILE"
    chmod 644 "$LOG_FILE"
    
    # Reload systemd
    echo "Reloading systemd..."
    systemctl daemon-reload
    
    # Enable and start the watchdog
    echo "Enabling and starting watchdog service..."
    systemctl enable adguard-watchdog.service
    systemctl start adguard-watchdog.service
    
    sleep 2
    
    echo ""
    echo -e "${GREEN}✅ Installation complete!${NC}"
    echo ""
    echo "═══════════════════════════════════════════════════════════"
    echo "  AdGuard Home Watchdog is now running AUTOMATICALLY!"
    echo "═══════════════════════════════════════════════════════════"
    echo ""
    echo "The watchdog will:"
    echo "  • Monitor AdGuard Home every ${CHECK_INTERVAL} seconds"
    echo "  • Detect freezes within $((CHECK_INTERVAL * MAX_CONSECUTIVE_FAILURES)) seconds"
    echo "  • AUTOMATICALLY restart AdGuard Home when frozen"
    echo "  • Run continuously in the background"
    echo "  • Start automatically on system boot"
    echo ""
    echo "Useful commands:"
    echo "  Check status:    sudo systemctl status adguard-watchdog"
    echo "  View live logs:  sudo journalctl -u adguard-watchdog -f"
    echo "  View log file:   sudo tail -f $LOG_FILE"
    echo "  Stop watchdog:   sudo systemctl stop adguard-watchdog"
    echo "  Restart:         sudo systemctl restart adguard-watchdog"
    echo "  Uninstall:       sudo bash ${SCRIPT_DIR}/${SCRIPT_NAME} uninstall"
    echo ""
    
    # Show current status
    echo "Current Status:"
    if systemctl is-active --quiet adguard-watchdog; then
        echo -e "  ${GREEN}🟢 Watchdog: RUNNING${NC}"
    else
        echo -e "  ${RED}🔴 Watchdog: STOPPED${NC}"
    fi
    
    if systemctl is-active --quiet AdGuardHome; then
        echo -e "  ${GREEN}🟢 AdGuard Home: RUNNING${NC}"
    else
        echo -e "  ${RED}🔴 AdGuard Home: STOPPED${NC}"
    fi
    
    echo ""
    echo -e "${GREEN}Watchdog is now protecting your AdGuard Home installation!${NC}"
    echo ""
}

#######################################################
# Uninstallation Function
#######################################################

uninstall_watchdog() {
    echo -e "${YELLOW}Uninstalling AdGuard Home Watchdog...${NC}"
    
    # Check if running as root
    if [ "$EUID" -ne 0 ]; then 
        echo -e "${RED}Error: Please run uninstallation as root (use sudo)${NC}"
        exit 1
    fi
    
    # Stop and disable service
    echo "Stopping and disabling service..."
    systemctl stop adguard-watchdog.service 2>/dev/null || true
    systemctl disable adguard-watchdog.service 2>/dev/null || true
    
    # Remove service files
    echo "Removing service files..."
    rm -f /etc/systemd/system/adguard-watchdog.service
    rm -rf /etc/systemd/system/AdGuardHome.service.d/watchdog.conf
    
    # Remove script directory
    echo "Removing script directory..."
    rm -rf "$SCRIPT_DIR"
    
    # Reload systemd
    systemctl daemon-reload
    
    echo -e "${GREEN}✅ Uninstallation complete!${NC}"
    echo ""
    echo "Note: Log file preserved at: $LOG_FILE"
    echo "To remove logs: sudo rm $LOG_FILE"
    echo ""
}

#######################################################
# Main Monitoring Loop
#######################################################

run_monitoring() {
    # Trap signals for clean shutdown
    trap 'log_message "Watchdog stopping..."; exit 0' SIGTERM SIGINT
    
    # Main monitoring loop
    log_message "${BLUE}🚀 AdGuard Home Watchdog started (checking every ${CHECK_INTERVAL}s)${NC}"
    
    while true; do
        if check_health; then
            # Reset failure count on success
            if [ $FAILURE_COUNT -gt 0 ]; then
                log_message "${GREEN}✅ AdGuard Home recovered and is responsive${NC}"
                FAILURE_COUNT=0
            fi
        else
            # Increment failure count
            FAILURE_COUNT=$((FAILURE_COUNT + 1))
            log_message "${YELLOW}⚠️  Health check failed ($FAILURE_COUNT/$MAX_CONSECUTIVE_FAILURES)${NC}"
            
            # Restart if threshold reached
            if [ $FAILURE_COUNT -ge $MAX_CONSECUTIVE_FAILURES ]; then
                restart_adguard
                FAILURE_COUNT=0
            fi
        fi
        
        sleep "$CHECK_INTERVAL"
    done
}

#######################################################
# Main Entry Point
#######################################################

case "">${1:-} in
    install)
        install_watchdog
        ;;
    uninstall)
        uninstall_watchdog
        ;;
    run)
        run_monitoring
        ;;
    *)
        echo "AdGuard Home Watchdog Monitor"
        echo ""
        echo "Usage:"
        echo "  $0 install       - Install and start the watchdog service"
        echo "  $0 uninstall     - Uninstall the watchdog service"
        echo "  $0 run           - Run the monitoring loop (used by systemd)"
        echo ""
        echo "For installation, run:"
        echo "  sudo bash $0 install"
        echo ""
        ;;
esac
