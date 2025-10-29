#!/bin/bash
# Colors & symbols
GREEN='\033[1;32m'
RED='\033[1;31m'
CYAN='\033[0;36m'
NC='\033[0m'
RUN="🟢"
STOP="🔴"

# FUNCTION TO CHECK SERVICE STATUS
check_service() {
  if systemctl is-active --quiet "$1" 2>/dev/null || service "$1" status >/dev/null 2>&1; then
    echo "$RUN"
  else
    echo "$STOP"
  fi
}

# SERVICE STATUS
ssh_service=$(check_service ssh)
dropbear_service=$(check_service dropbear)
stunnel_service=$(check_service stunnel4)
fail2ban_service=$(check_service fail2ban)
cron_service=$(check_service cron)
vnstat_service=$(check_service vnstat)
v2ray_tls_service=$(check_service xray)        # adjust for TLS
v2ray_nontls_service=$(check_service xray)     # adjust for No TLS
vless_tls_service=$(check_service xray)        # adjust for TLS
vless_nontls_service=$(check_service xray)     # adjust for No TLS
trojan_service=$(check_service xray)           # adjust for Trojan
shadowsocks_service=$(check_service xray)      # adjust for Shadowsocks
ws_tls_service=$(check_service ws-stunnel.service)
ws_drop_service=$(check_service ws-dropbear.service)

# 3D BOX HEADER
echo -e "${CYAN}╔════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║           SERVICE INFORMATION          ║${NC}"
echo -e "${CYAN}╠════════════════════════════════════════╣${NC}"

# PRINT STATUS
printf "║ SSH / TUN            : %-2s %-12s ║\n" "$ssh_service" "SSH"
printf "║ Dropbear             : %-2s %-12s ║\n" "$dropbear_service" "Dropbear"
printf "║ Stunnel4             : %-2s %-12s ║\n" "$stunnel_service" "Stunnel4"
printf "║ Fail2Ban             : %-2s %-12s ║\n" "$fail2ban_service" "Fail2Ban"
printf "║ Crons                : %-2s %-12s ║\n" "$cron_service" "Cron"
printf "║ Vnstat               : %-2s %-12s ║\n" "$vnstat_service" "Vnstat"
printf "║ XRAYS Vmess TLS      : %-2s %-12s ║\n" "$v2ray_tls_service" "Vmess TLS"
printf "║ XRAYS Vmess No TLS   : %-2s %-12s ║\n" "$v2ray_nontls_service" "Vmess No TLS"
printf "║ XRAYS Vless TLS      : %-2s %-12s ║\n" "$vless_tls_service" "Vless TLS"
printf "║ XRAYS Vless No TLS   : %-2s %-12s ║\n" "$vless_nontls_service" "Vless No TLS"
printf "║ XRAYS Trojan         : %-2s %-12s ║\n" "$trojan_service" "Trojan"
printf "║ Shadowsocks          : %-2s %-12s ║\n" "$shadowsocks_service" "Shadowsocks"
printf "║ Websocket TLS        : %-2s %-12s ║\n" "$ws_tls_service" "WS TLS"
printf "║ Websocket No TLS     : %-2s %-12s ║\n" "$ws_drop_service" "WS No TLS"

echo -e "${CYAN}╚════════════════════════════════════════╝${NC}"

echo ""
read -n 1 -s -r -p "Press any key to return to menu"
