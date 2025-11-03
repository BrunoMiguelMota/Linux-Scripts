#!/bin/bash

set -Eeuo pipefail

#######################################################
# AdGuard Home Continuous Watchdog Monitor
# Automatically detects and restarts frozen AdGuard Home
#
# Author: BrunoMiguelMota
# Repository: https://github.com/BrunoMiguelMota/Linux-Scripts
# Issue: https://github.com/BrunoMiguelMota/Linux-Scripts/issues/4
#
# Usage:
#   sudo bash adguard-watchdog-monitor.sh install    # install service
#   sudo bash adguard-watchdog-monitor.sh uninstall  # uninstall service
#   sudo bash adguard-watchdog-monitor.sh run        # run loop (systemd)
#######################################################

# Configuration
AGH_HOST="127.0.0.1"
AGH_PORT="3000"
CHECK_INTERVAL="30"          # seconds between health checks
TIMEOUT="10"                 # curl/HTTP timeout (seconds)
MAX_CONSECUTIVE_FAILURES="2" # restart after N consecutive failures
LOG_FILE="/var/log/adguard-monitor.log"
SCRIPT_DIR="/opt/adguard-monitor"
SCRIPT_NAME="adguard-watchdog.sh"

# Internal
FAILURE_COUNT=0

# Colors for terminal output (may show in log too)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_message() {
  local msg="[$(date '+%Y-%m-%d %H:%M:%S')] $*"
  echo -e "$msg" | tee -a "$LOG_FILE"
}

check_health() {
  # Returns 0 if healthy, 1 if not
  if timeout "$TIMEOUT" curl -fsS --connect-timeout 5 \
      "http://${AGH_HOST}:${AGH_PORT}/control/status" > /dev/null; then
    return 0
  fi
  return 1
}

is_service_running() {
  systemctl is-active --quiet AdGuardHome
}

restart_adguard() {
  log_message "${RED}FREEZE DETECTED${NC} AdGuard Home unresponsive. Restarting..."

  log_message "Stopping AdGuard Home..."
  systemctl stop AdGuardHome || true
  sleep 2

  # Kill any remaining processes just in case
  pkill -9 AdGuardHome 2>/dev/null || true
  sleep 1

  log_message "Starting AdGuard Home..."
  systemctl start AdGuardHome || true
  sleep 5

  if check_health; then
    log_message "${GREEN}SUCCESS${NC} AdGuard Home is responsive after restart"
    FAILURE_COUNT=0
    return 0
  else
    log_message "${RED}WARNING${NC} AdGuard Home still unresponsive after restart"
    return 1
  fi
}

install_watchdog() {
  echo -e "${BLUE}== Installing AdGuard Home Watchdog ==${NC}"

  if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}Please run as root (use sudo).${NC}"
    exit 1
  fi

  apt-get update -qq
  DEBIAN_FRONTEND=noninteractive apt-get install -y curl systemd >/dev/null 2>&1 || true

  mkdir -p "$SCRIPT_DIR"
  mkdir -p "$(dirname "$LOG_FILE")"

  # Copy this script as the runtime script expected by the unit
  cp "$0" "${SCRIPT_DIR}/${SCRIPT_NAME}"
  chmod +x "${SCRIPT_DIR}/${SCRIPT_NAME}"

  # Create systemd unit
  cat >/etc/systemd/system/adguard-watchdog.service <<'UNIT'
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
UNIT

  # Optional: ensure AdGuardHome service has a small restart delay (override)
  mkdir -p /etc/systemd/system/AdGuardHome.service.d
  cat >/etc/systemd/system/AdGuardHome.service.d/watchdog.conf <<'OVERRIDE'
[Service]
RestartSec=5
OVERRIDE

  # Prepare log file
  touch "$LOG_FILE"
  chmod 644 "$LOG_FILE"

  systemctl daemon-reload
  systemctl enable adguard-watchdog.service
  systemctl start adguard-watchdog.service

  echo
  echo -e "${GREEN}Installation complete.${NC} Watchdog is active."
  echo "- Status:   sudo systemctl status adguard-watchdog"
  echo "- Logs:     sudo journalctl -u adguard-watchdog -f"
  echo "- Log file: sudo tail -f $LOG_FILE"
}

uninstall_watchdog() {
  echo -e "${YELLOW}== Uninstalling AdGuard Home Watchdog ==${NC}"

  if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}Please run as root (use sudo).${NC}"
    exit 1
  fi

  systemctl stop adguard-watchdog.service 2>/dev/null || true
  systemctl disable adguard-watchdog.service 2>/dev/null || true

  rm -f /etc/systemd/system/adguard-watchdog.service
  rm -f /etc/systemd/system/AdGuardHome.service.d/watchdog.conf
  rm -rf "$SCRIPT_DIR"

  systemctl daemon-reload

  echo -e "${GREEN}Uninstalled.${NC} Log file preserved: $LOG_FILE"
}

run_monitoring() {
  trap 'log_message "Watchdog stopping..."; exit 0' SIGTERM SIGINT

  log_message "${BLUE}Watchdog started${NC} (checks every ${CHECK_INTERVAL}s)"

  while true; do
    if check_health; then
      if [[ $FAILURE_COUNT -gt 0 ]]; then
        log_message "${GREEN}Recovered${NC} AdGuard Home responsive again"
        FAILURE_COUNT=0
      fi
    else
      FAILURE_COUNT=$((FAILURE_COUNT + 1))
      log_message "${YELLOW}Health check failed${NC} (${FAILURE_COUNT}/${MAX_CONSECUTIVE_FAILURES})"

      if [[ $FAILURE_COUNT -ge $MAX_CONSECUTIVE_FAILURES ]]; then
        restart_adguard
        FAILURE_COUNT=0
      fi
    fi

    sleep "$CHECK_INTERVAL"
  done
}

case "${1:-}" in
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
    echo
    echo "Usage:"
    echo "  $0 install      Install and start the watchdog service"
    echo "  $0 uninstall    Uninstall the watchdog service"
    echo "  $0 run          Run the monitoring loop (used by systemd)"
    echo
    echo "For installation, run:"
    echo "  sudo bash $0 install"
    echo
    ;;
esac
