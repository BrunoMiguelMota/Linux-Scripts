# GL-BE9300 Security Quick Start Guide

## Pre-Installation Checklist

- [ ] Router is running OpenWRT 23.05+
- [ ] You have SSH access (root@192.168.8.1)
- [ ] Router has internet connection
- [ ] You have your SSH public key ready
- [ ] You've chosen strong WiFi passwords

## Installation Steps

### 1. Download and Run Script

```bash
ssh root@192.168.8.1
cd /tmp
wget https://raw.githubusercontent.com/BrunoMiguelMota/Linux-Scripts/main/openwrt_glinet_be9300_security.sh
chmod +x openwrt_glinet_be9300_security.sh
./openwrt_glinet_be9300_security.sh
```

Wait for completion (5-10 minutes).

### 2. Change WiFi Passwords

```bash
uci set wireless.default_radio0.key='YOUR_STRONG_PASSWORD_HERE'
uci set wireless.default_radio1.key='YOUR_STRONG_PASSWORD_HERE'
uci set wireless.default_radio2.key='YOUR_STRONG_PASSWORD_HERE'
uci commit wireless
wifi reload
```

### 3. Setup SSH Keys

From your computer:

```bash
ssh-copy-id root@192.168.8.1
```

Test SSH key login works!

### 4. Reboot Router

```bash
reboot
```

## Post-Installation

### Access Web Interface

Navigate to: `https://192.168.8.1`

### Check Security Status

```bash
/root/security_check.sh
```

### Configure WireGuard VPN

1. Log into LuCI web interface
2. Go to **Network → VPN → WireGuard**
3. Note the router's public key
4. Add peers for your devices

### Test Everything

- [ ] WiFi connects on all bands
- [ ] Internet works
- [ ] LuCI web interface accessible via HTTPS
- [ ] SSH works with key authentication
- [ ] DNS resolution works
- [ ] VPN connects (if configured)

## Important Firewall Ports

| Port  | Protocol | Purpose           | Access    |
|-------|----------|-------------------|-----------|
| 22    | TCP      | SSH               | LAN only  |
| 80    | TCP      | HTTP (redirects)  | LAN only  |
| 443   | TCP      | HTTPS (LuCI)      | LAN only  |
| 51820 | UDP      | WireGuard VPN     | WAN/LAN   |

## Default Credentials After Setup

- **LuCI**: root / (your router password)
- **SSH**: Key-based authentication only
- **WiFi**: ChangeThisPassword123! (CHANGE THIS!)

## Security Features Enabled

✅ WPA3-SAE encryption on all WiFi bands
✅ DNS-over-HTTPS (Cloudflare + Quad9)
✅ Ad-blocking (AdAway, OISD, Steven Black)
✅ IP threat blocking (Firehol, Spamhaus, Talos)
✅ SSH hardening (keys only, LAN only)
✅ Hardened firewall (strict rules)
✅ HTTPS-only web interface
✅ WireGuard VPN ready
✅ Kernel security hardening
✅ SYN flood protection
✅ Management frame protection

## Common Commands

### Check Firewall

```bash
/etc/init.d/firewall status
nft list ruleset
```

### Monitor Connections

```bash
netstat -tunap
```

### View Blocked IPs

```bash
cat /tmp/ban_data/banip.list
```

### Check DNS

```bash
nslookup google.com
```

### WireGuard Status

```bash
wg show
```

### View Logs

```bash
logread -f
```

### Restart Services

```bash
/etc/init.d/network restart
/etc/init.d/firewall restart
/etc/init.d/dropbear restart
```

## Troubleshooting

### Lost Web Access

```bash
/etc/init.d/uhttpd restart
```

### WiFi Not Working

```bash
wifi status
wifi reload
logread | grep -i wireless
```

### Locked Out

- Connect via serial console
- Or factory reset (hold reset 10 seconds)

### DNS Not Resolving

```bash
/etc/init.d/https-dns-proxy restart
/etc/init.d/dnsmasq restart
```

## Backup Configuration

Before making changes:

```bash
sysupgrade -b /tmp/backup-$(date +%F).tar.gz
```

Download to your computer:

```bash
scp root@192.168.8.1:/tmp/backup-*.tar.gz ~/
```

## Next Steps

1. **Configure VPN Clients**: Add WireGuard peers for remote access
2. **Custom Firewall Rules**: Add any specific rules you need
3. **Monitor Regularly**: Run `/root/security_check.sh` daily
4. **Update Regularly**: `opkg update && opkg list-upgradable`
5. **Review Logs**: Check for intrusion attempts
6. **Test Backups**: Ensure you can restore if needed

## Getting Help

- Full Documentation: [OPENWRT_GL-BE9300_SECURITY_README.md](OPENWRT_GL-BE9300_SECURITY_README.md)
- OpenWRT Docs: https://openwrt.org/docs/start
- GL.iNet Forum: https://forum.gl-inet.com/
- GitHub Issues: https://github.com/BrunoMiguelMota/Linux-Scripts/issues

## Security Reminders

⚠️ **CRITICAL**: Change default WiFi password!
⚠️ **CRITICAL**: Setup SSH keys before disabling password auth!
⚠️ Keep firmware updated
⚠️ Monitor logs regularly
⚠️ Backup configurations
⚠️ Test in non-production first

---

**Created by:** BrunoMiguelMota/Linux-Scripts
**Last Updated:** 2025-10-13
