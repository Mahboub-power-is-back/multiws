#!/bin/bash

# ================== ADD: COLORS ==================
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# ================== ADD: LOADING BAR ==================
progress() {
  for i in {1..20}; do
    printf "\r["
    printf "%0.s▓" $(seq 1 $i)
    printf "%0.s░" $(seq $i 20)
    printf "] %d%%" $((i*5))
    sleep 0.08
  done
  echo ""
}

run_step() {
  echo -e "${YELLOW}➤ $1${NC}"
  shift
  "$@" >/dev/null 2>&1
  progress
}

# ================== ORIGINAL ==================
apt update -y >/dev/null 2>&1
apt install -y jq curl wget >/dev/null 2>&1

# ------------------------------
# Cloudflare API Info
# ------------------------------
DOMAIN="mahboubvps.site"
CF_TOKEN="XOYA63kolRF-6_EzxZQ22ESucCdm7zSJl7NEDQtA"
ZONE="8761c8222fe8a4d1249e8563eedf43ee"

# ------------------------------
# Root check
# ------------------------------
if [ "${EUID:-0}" -ne 0 ]; then
    echo "Run this script as root!"
    exit 1
fi

# ------------------------------
# Create directories
# ------------------------------
run_step "Creating directories" mkdir -p /etc/xray /etc/v2ray /root/scripts /var/lib
touch /etc/xray/domain /etc/v2ray/domain /etc/xray/scdomain /etc/v2ray/scdomain /root/scdomain

# ------------------------------
# Domain Selection Menu
# ------------------------------
clear
echo "┌──────────────────────────────────────────────────────────┐"
echo "│              DOMAIN CONFIGURATION MENU                   │"
echo "└──────────────────────────────────────────────────────────┘"
echo "  [1] Random A + NS (Cloudflare)"
echo "  [2] Random A only (Cloudflare)"
echo "  [3] Your domain A only"
echo "  [4] Your domain A + NS"
read -rp "Select option (1/2/3/4): " dns

IP=$(curl -s ipv4.icanhazip.com)

case "$dns" in
  1)
    SUB="ws-$(tr -dc a-z0-9 </dev/urandom | head -c5).$DOMAIN"
    NS_SUB="dns.$SUB"

    run_step "Creating A record" curl -s -X POST "https://api.cloudflare.com/client/v4/zones/$ZONE/dns_records" \
      -H "Authorization: Bearer $CF_TOKEN" \
      -H "Content-Type: application/json" \
      --data "{\"type\":\"A\",\"name\":\"$SUB\",\"content\":\"$IP\",\"ttl\":120,\"proxied\":false}"

    run_step "Creating NS record" curl -s -X POST "https://api.cloudflare.com/client/v4/zones/$ZONE/dns_records" \
      -H "Authorization: Bearer $CF_TOKEN" \
      -H "Content-Type: application/json" \
      --data "{\"type\":\"NS\",\"name\":\"$NS_SUB\",\"content\":\"$SUB\",\"ttl\":120}"

    echo "$SUB" | tee /root/scdomain /etc/xray/domain /etc/v2ray/domain /etc/xray/scdomain /var/lib/ipvps.conf >/dev/null
    echo "$NS_SUB" | tee /root/nsdomain >/dev/null
    ;;
  2)
    SUB="ws-$(tr -dc a-z0-9 </dev/urandom | head -c5).$DOMAIN"
    run_step "Creating A record" curl -s -X POST "https://api.cloudflare.com/client/v4/zones/$ZONE/dns_records" \
      -H "Authorization: Bearer $CF_TOKEN" \
      -H "Content-Type: application/json" \
      --data "{\"type\":\"A\",\"name\":\"$SUB\",\"content\":\"$IP\",\"ttl\":120,\"proxied\":false}"

    echo "$SUB" | tee /root/scdomain /etc/xray/domain /etc/v2ray/domain >/dev/null
    ;;
  3)
    read -rp "Enter your domain (A only): " dom
    SUB="$dom"
    echo "$dom" | tee /root/scdomain /etc/xray/domain /etc/v2ray/domain >/dev/null
    ;;
  4)
    read -rp "Enter your domain (A+NS): " dom
    SUB="$dom"
    NS_SUB="dns.$SUB"

    run_step "Creating NS record" curl -s -X POST "https://api.cloudflare.com/client/v4/zones/$ZONE/dns_records" \
      -H "Authorization: Bearer $CF_TOKEN" \
      -H "Content-Type: application/json" \
      --data "{\"type\":\"NS\",\"name\":\"$NS_SUB\",\"content\":\"$SUB\",\"ttl\":120}"

    echo "$SUB" | tee /root/scdomain /etc/xray/domain /etc/v2ray/domain >/dev/null
    echo "$NS_SUB" | tee /root/nsdomain >/dev/null
    ;;
esac

echo "✅ Domain setup done!"

# ------------------------------
# Install Services (UNCHANGED)
# ------------------------------
run_step "Installing SSH VPN" bash /root/ssh-vpn.sh
run_step "Installing XRAY" bash /root/ins-xray.sh
run_step "Installing SSH WS" bash /root/insshws.sh

# ------------------------------
# SHOW SERVICE & PORTS (ADD)
# ------------------------------
clear
cat <<EOF
┌───────────────────────────────────────────────────────────────┐
│                    SERVICE & PORTS                            │
└───────────────────────────────────────────────────────────────┘
 OpenSSH                  : 22
 OpenVPN                  : 1194
 SSH Websocket            : 80
 SSH SSL Websocket        : 443
 OVPN Websocket           : 80
 OVPN SSL Websocket       : 443
 Stunnel4                 : 222, 777
 Dropbear                 : 109, 143
 UDP CUSTOM               : 1-65535
 Badvpn                   : 7100-7900
 Nginx                    : 81

 XRAY
 VMESS / VLESS / TROJAN   : 443 / 80
 gRPC                     : 443
 DNSTT Server             : 443

 Domain : $SUB
 NS     : ${NS_SUB:-None}
└───────────────────────────────────────────────────────────────┘
EOF

sleep 5

# ------------------------------
# Finish (ORIGINAL)
# ------------------------------
echo "Installation complete! Rebooting in 10 seconds..."
sleep 10
reboot
