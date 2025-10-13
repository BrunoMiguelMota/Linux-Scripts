# GL-BE9300 Security Configuration Changes

This document details all configuration changes made by the `openwrt_glinet_be9300_security.sh` script.

## Configuration Files Modified

### 1. /etc/config/firewall

| Setting | Default | After Script | Purpose |
|---------|---------|--------------|---------|
| defaults.input | ACCEPT | REJECT | Block unsolicited inbound traffic |
| defaults.output | ACCEPT | ACCEPT | Allow outbound traffic |
| defaults.forward | ACCEPT | REJECT | Block forwarding by default |
| defaults.synflood_protect | 0 | 1 | Enable SYN flood protection |
| defaults.drop_invalid | 0 | 1 | Drop invalid packets |
| defaults.tcp_syncookies | 0 | 1 | Enable TCP SYN cookies |
| defaults.tcp_ecn | 1 | 0 | Disable ECN (compatibility) |
| defaults.accept_redirects | 1 | 0 | Prevent ICMP redirect attacks |
| defaults.accept_source_route | 1 | 0 | Prevent source routing attacks |
| wan.input | REJECT | REJECT | Keep WAN secure |
| wan.forward | REJECT | REJECT | Block WAN forwarding |
| wan.masq | 1 | 1 | Keep NAT enabled |

### 2. /etc/config/wireless

#### Radio 0 (2.4GHz)
| Setting | Default | After Script | Purpose |
|---------|---------|--------------|---------|
| radio0.disabled | varies | 0 | Enable radio |
| radio0.country | varies | US | Set regulatory domain |
| radio0.channel | varies | auto | Auto channel selection |
| radio0.htmode | varies | HE40 | WiFi 6 (40MHz) |
| radio0.txpower | varies | 20 | Set transmit power |
| default_radio0.encryption | psk2 | sae-mixed | WPA3 with WPA2 fallback |
| default_radio0.ieee80211w | 0 | 2 | Mandatory management frame protection |
| default_radio0.wps_pushbutton | 1 | 0 | Disable WPS |
| default_radio0.wpa_disable_eapol_key_retries | 0 | 1 | KRACK protection |

#### Radio 1 (5GHz)
| Setting | Default | After Script | Purpose |
|---------|---------|--------------|---------|
| radio1.disabled | varies | 0 | Enable radio |
| radio1.country | varies | US | Set regulatory domain |
| radio1.channel | varies | auto | Auto channel selection |
| radio1.htmode | varies | HE80 | WiFi 6 (80MHz) |
| radio1.txpower | varies | 23 | Set transmit power |
| default_radio1.encryption | psk2 | sae-mixed | WPA3 with WPA2 fallback |
| default_radio1.ieee80211w | 0 | 2 | Mandatory management frame protection |
| default_radio1.wps_pushbutton | 1 | 0 | Disable WPS |
| default_radio1.wpa_disable_eapol_key_retries | 0 | 1 | KRACK protection |

#### Radio 2 (6GHz - WiFi 7)
| Setting | Default | After Script | Purpose |
|---------|---------|--------------|---------|
| radio2.disabled | varies | 0 | Enable radio |
| radio2.country | varies | US | Set regulatory domain |
| radio2.channel | varies | auto | Auto channel selection |
| radio2.htmode | varies | EHT160 | WiFi 7 (160MHz) |
| radio2.txpower | varies | 23 | Set transmit power |
| default_radio2.encryption | psk2 | sae | WPA3-only (6GHz requirement) |
| default_radio2.ieee80211w | 0 | 2 | Mandatory management frame protection |
| default_radio2.wps_pushbutton | 1 | 0 | Disable WPS |

### 3. /etc/config/dhcp (DNS)

| Setting | Default | After Script | Purpose |
|---------|---------|--------------|---------|
| dnsmasq.server | ISP DNS | 127.0.0.1#5053, 127.0.0.1#5054 | Use local DoH proxy |
| dnsmasq.noresolv | 0 | 1 | Don't use /etc/resolv.conf |

### 4. /etc/config/https-dns-proxy

| Setting | Value | Purpose |
|---------|-------|---------|
| Resolver 1 | https://cloudflare-dns.com/dns-query | Cloudflare DoH |
| Resolver 2 | https://dns.quad9.net/dns-query | Quad9 DoH backup |
| Listen Port 1 | 5053 | Local DoH proxy port |
| Listen Port 2 | 5054 | Backup DoH proxy port |

### 5. /etc/config/adblock

| Setting | Default | After Script | Purpose |
|---------|---------|--------------|---------|
| global.adb_enabled | 0 | 1 | Enable ad-blocking |
| global.adb_safesearch | 0 | 1 | Enable safe search |
| global.adb_jail | 0 | 1 | Enable jail mode |
| sources | none | adaway, oisd, stevenblack | Multiple blocklists |

### 6. /etc/config/banip

| Setting | Default | After Script | Purpose |
|---------|---------|--------------|---------|
| global.ban_enabled | 0 | 1 | Enable IP blocking |
| global.ban_autodetect | 0 | 1 | Auto-detect interfaces |
| global.ban_logread | 0 | 1 | Monitor system logs |
| global.ban_logterm | - | dropbear | Monitor SSH attempts |
| global.ban_sshlimit | - | 3 | Max failed SSH attempts |
| sources | none | firehol1-3, spamhaus, talos | Threat intelligence feeds |

### 7. /etc/config/dropbear (SSH)

| Setting | Default | After Script | Purpose |
|---------|---------|--------------|---------|
| PasswordAuth | on | off | Disable password login |
| RootPasswordAuth | on | off | Disable root password login |
| Port | 22 | 22 | Keep standard port |
| Interface | all | lan | LAN-only access |
| GatewayPorts | off | off | Disable port forwarding |

### 8. /etc/config/network (WireGuard)

| Setting | Value | Purpose |
|---------|-------|---------|
| wg0.proto | wireguard | WireGuard protocol |
| wg0.private_key | generated | Unique private key |
| wg0.listen_port | 51820 | WireGuard port |
| wg0.addresses | 10.0.0.1/24 | VPN subnet |

### 9. /etc/config/uhttpd (Web Interface)

| Setting | Default | After Script | Purpose |
|---------|---------|--------------|---------|
| main.listen_http | 0.0.0.0:80 | 0.0.0.0:80 | Keep HTTP (for redirect) |
| main.listen_https | 0.0.0.0:443 | 0.0.0.0:443 | HTTPS enabled |
| main.redirect_https | 0 | 1 | Force HTTPS |

### 10. /etc/sysctl.conf (Kernel Parameters)

| Setting | Default | After Script | Purpose |
|---------|---------|--------------|---------|
| net.ipv4.ip_forward | 0 | 1 | Enable routing |
| net.ipv6.conf.all.forwarding | 0 | 1 | Enable IPv6 routing |
| net.ipv4.tcp_syncookies | 0 | 1 | SYN flood protection |
| net.ipv4.tcp_syn_retries | 5 | 2 | Reduce SYN retries |
| net.ipv4.tcp_synack_retries | 5 | 2 | Reduce SYN-ACK retries |
| net.ipv4.tcp_max_syn_backlog | 1024 | 4096 | Increase backlog |
| net.ipv4.icmp_echo_ignore_broadcasts | 0 | 1 | Ignore broadcast pings |
| net.ipv4.icmp_ignore_bogus_error_responses | 0 | 1 | Ignore bogus ICMP |
| net.ipv4.conf.all.accept_redirects | 1 | 0 | Block ICMP redirects |
| net.ipv4.conf.all.secure_redirects | 1 | 0 | Block secure redirects |
| net.ipv4.conf.all.send_redirects | 1 | 0 | Don't send redirects |
| net.ipv4.conf.all.accept_source_route | 1 | 0 | Block source routing |
| net.ipv4.conf.all.rp_filter | 0 | 1 | Enable reverse path filter |
| net.ipv4.conf.all.log_martians | 0 | 1 | Log martian packets |

## Firewall Zones Created

### VPN Zone (new)
- **Name**: vpn
- **Network**: wg0
- **Input**: ACCEPT
- **Output**: ACCEPT
- **Forward**: ACCEPT
- **Masquerade**: Enabled
- **Forwarding to**: lan, wan

## Firewall Rules Created

| Rule Name | Source | Dest | Port | Protocol | Action |
|-----------|--------|------|------|----------|--------|
| Allow-WireGuard | wan | router | 51820 | UDP | ACCEPT |
| (existing rules remain) | - | - | - | - | - |

## Services Enabled

| Service | Purpose |
|---------|---------|
| firewall | Packet filtering |
| https-dns-proxy | DNS-over-HTTPS |
| adblock | Ad/tracker blocking |
| banip | IP threat blocking |
| dropbear | SSH server |
| uhttpd | Web server (HTTPS) |
| network (wg0) | WireGuard VPN |

## Services Disabled

| Service | Reason |
|---------|--------|
| odhcpd | Not needed for most setups |

## Packages Installed

| Package | Purpose |
|---------|---------|
| luci-ssl-openssl | HTTPS for web interface |
| wpad-mbedtls | WPA3 support |
| wireguard-tools | WireGuard utilities |
| luci-app-wireguard | WireGuard web UI |
| kmod-wireguard | WireGuard kernel module |
| banip | IP reputation blocking |
| luci-app-banip | BanIP web UI |
| adblock | Ad-blocking |
| luci-app-adblock | Adblock web UI |
| https-dns-proxy | DNS-over-HTTPS proxy |
| luci-app-https-dns-proxy | DoH web UI |
| nano | Text editor |
| curl | HTTP client |
| wget-ssl | HTTPS downloader |
| tcpdump-mini | Network analyzer |
| uhttpd-mod-ubus | Web interface enhancement |

## Files Created

| File | Purpose |
|------|---------|
| /root/security_check.sh | Security status monitoring script |
| /etc/config/firewall.backup | Backup of original firewall config |

## Security Improvements Summary

### Before Script
- ✗ WPA2-PSK encryption (vulnerable to attacks)
- ✗ Open firewall policies
- ✗ Plaintext DNS queries
- ✗ No threat intelligence
- ✗ Password-based SSH
- ✗ HTTP web interface
- ✗ Default kernel parameters
- ✗ WPS enabled (vulnerable)

### After Script
- ✓ WPA3-SAE encryption (modern security)
- ✓ Hardened firewall with strict rules
- ✓ Encrypted DNS-over-HTTPS
- ✓ Active threat blocking (BanIP)
- ✓ Key-based SSH only
- ✓ HTTPS-only web interface
- ✓ Security-optimized kernel
- ✓ WPS disabled
- ✓ Management frame protection
- ✓ KRACK attack mitigation
- ✓ Ad-blocking enabled
- ✓ WireGuard VPN ready

## Reversion Instructions

To revert specific changes:

### Firewall
```bash
cp /etc/config/firewall.backup /etc/config/firewall
/etc/init.d/firewall restart
```

### Wireless
```bash
uci set wireless.default_radio0.encryption='psk2'
uci set wireless.default_radio1.encryption='psk2'
uci commit wireless
wifi reload
```

### SSH
```bash
uci set dropbear.@dropbear[0].PasswordAuth='on'
uci set dropbear.@dropbear[0].RootPasswordAuth='on'
uci commit dropbear
/etc/init.d/dropbear restart
```

### Complete Factory Reset
```bash
firstboot -y && reboot
```

## Performance Impact

| Resource | Typical Usage | Notes |
|----------|---------------|-------|
| CPU | +2-5% | Minimal impact on quad-core BE9300 |
| RAM | +30-50MB | Out of 1GB total |
| Flash | +15-20MB | For installed packages |
| Latency | +1-3ms | Due to DoH and filtering |
| Throughput | <1% | Negligible on gigabit |

## Compatibility Notes

- **OpenWRT Version**: Requires 23.05 or newer
- **Router Model**: Optimized for GL-BE9300
- **WiFi 7**: EHT modes require compatible clients
- **WPA3**: Older devices may need WPA2 fallback (sae-mixed)
- **6GHz**: Requires WPA3-only (regulatory requirement)

## Additional Resources

- [OpenWRT Firewall Documentation](https://openwrt.org/docs/guide-user/firewall/start)
- [WPA3 Security](https://www.wi-fi.org/discover-wi-fi/security)
- [WireGuard Protocol](https://www.wireguard.com/)
- [DNS-over-HTTPS RFC 8484](https://tools.ietf.org/html/rfc8484)
- [BanIP Documentation](https://github.com/openwrt/packages/tree/master/net/banip)

---

**Last Updated**: 2025-10-13
**Script Version**: 1.0.0
