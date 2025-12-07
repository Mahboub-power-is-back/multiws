#!/bin/bash
apt update -y >/dev/null 2>&1
apt install -y jq curl wget >/dev/null 2>&1

# ------------------------------
# Cloudflare API Info
# ------------------------------
DOMAIN="mahboubvps.site"
CF_TOKEN="XOYA63kolRF-6_EzxZQ22ESucCdm7zSJl7NEDQtA"   # Your API Token
ZONE="8761c8222fe8a4d1249e8563eedf43ee"               # Your Zone ID

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
mkdir -p /etc/xray /etc/v2ray /root/scripts /var/lib 2>/dev/null
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
    # Random A + NS
    SUB="ws-$(tr -dc a-z0-9 </dev/urandom | head -c5).$DOMAIN"
    NS_SUB="dns.$SUB"   # NS points to A record

    # Create A record
    curl -s -X POST "https://api.cloudflare.com/client/v4/zones/$ZONE/dns_records" \
      -H "Authorization: Bearer $CF_TOKEN" \
      -H "Content-Type: application/json" \
      --data "{\"type\":\"A\",\"name\":\"$SUB\",\"content\":\"$IP\",\"ttl\":120,\"proxied\":false}" >/dev/null

    # Create NS record pointing to A
    curl -s -X POST "https://api.cloudflare.com/client/v4/zones/$ZONE/dns_records" \
      -H "Authorization: Bearer $CF_TOKEN" \
      -H "Content-Type: application/json" \
      --data "{\"type\":\"NS\",\"name\":\"$NS_SUB\",\"content\":\"$SUB\",\"ttl\":120}" >/dev/null

    echo "$SUB" | tee /root/scdomain /etc/xray/domain /etc/v2ray/domain /etc/xray/scdomain /var/lib/ipvps.conf >/dev/null
    echo "$NS_SUB" | tee /root/nsdomain >/dev/null
    ;;
  2)
    SUB="ws-$(tr -dc a-z0-9 </dev/urandom | head -c5).$DOMAIN"
    curl -s -X POST "https://api.cloudflare.com/client/v4/zones/$ZONE/dns_records" \
      -H "Authorization: Bearer $CF_TOKEN" \
      -H "Content-Type: application/json" \
      --data "{\"type\":\"A\",\"name\":\"$SUB\",\"content\":\"$IP\",\"ttl\":120,\"proxied\":false}" >/dev/null
    echo "$SUB" | tee /root/scdomain /etc/xray/domain /etc/v2ray/domain >/dev/null
    ;;
  3)
    read -rp "Enter your domain (A only): " dom
    echo "$dom" | tee /root/scdomain /etc/xray/domain /etc/v2ray/domain >/dev/null
    ;;
  4)
    read -rp "Enter your domain (A+NS): " dom
    SUB="$dom"
    NS_SUB="dns.$SUB"   # NS points to A record

    # Create NS record pointing to A
    curl -s -X POST "https://api.cloudflare.com/client/v4/zones/$ZONE/dns_records" \
      -H "Authorization: Bearer $CF_TOKEN" \
      -H "Content-Type: application/json" \
      --data "{\"type\":\"NS\",\"name\":\"$NS_SUB\",\"content\":\"$SUB\",\"ttl\":120}" >/dev/null

    echo "$SUB" | tee /root/scdomain /etc/xray/domain /etc/v2ray/domain >/dev/null
    echo "$NS_SUB" | tee /root/nsdomain >/dev/null
    ;;
  *)
    echo "[ERROR] Invalid selection"
    exit 1
    ;;
esac

echo "✅ Domain setup done!"
echo "A Record → $SUB → $IP"
[[ ! -z "$NS_SUB" ]] && echo "NS Record → $NS_SUB → $SUB"

# ------------------------------
# Install Services
# ------------------------------
wget -q -O /root/ssh-vpn.sh "https://raw.githubusercontent.com/Mahboub-power-is-back/multiws/master/ssh/ssh-vpn.sh"
chmod +x /root/ssh-vpn.sh
bash /root/ssh-vpn.sh

wget -q -O /root/ins-xray.sh "https://raw.githubusercontent.com/Mahboub-power-is-back/multiws/master/xray/ins-xray.sh"
chmod +x /root/ins-xray.sh
bash /root/ins-xray.sh

wget -q -O /root/insshws.sh "https://raw.githubusercontent.com/Mahboub-power-is-back/multiws/refs/heads/master/sshws/insshws.sh"
chmod +x /root/insshws.sh
bash /root/insshws.sh

# ------------------------------
# Install DNSTT Service (Port 443)
# ------------------------------
if [ -f /root/nsdomain ]; then
    DnsNS=$(cat /root/nsdomain)
else
    echo "[ERROR] NS domain not found! Skipping DNSTT."
    DnsNS=""
fi

PORT1=443
wget -q -c https://raw.githubusercontent.com/Mahboub-power-is-back/Myapp/refs/heads/main/dnstt-server -O /usr/local/bin/dnstt-server
chmod +x /usr/local/bin/dnstt-server
clear

echo '=== Installing DNSTT SERVICE ==='

cat <<EOF > /etc/systemd/system/dnstt-service.service
[Unit]
Description=DNSTT Server
After=network.target

[Service]
Type=simple
WorkingDirectory=/root
ExecStartPre=/sbin/iptables -A INPUT -p tcp --dport 5300 -j ACCEPT
ExecStartPre=/sbin/iptables -t nat -A PREROUTING -p udp --dport 53 -j REDIRECT --to-ports 5300
ExecStart=/usr/local/bin/dnstt-server -udp :5300 -privkey e35bb50094b4d06a17a7606ae724db082398a4cf86ad79bcdcf890386eb65a88 $DnsNS 127.0.0.1:$PORT1
StandardOutput=append:/var/log/dnstt.log
StandardError=append:/var/log/dnstt.log
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl start dnstt-service
systemctl enable dnstt-service
echo "✅ DNSTT server started on TCP/UDP port $PORT1 → using NS: $DnsNS"

# ------------------------------
# Setup .profile
# ------------------------------
cat > /root/.profile <<'END_PROFILE'
if [ "$BASH" ]; then
  if [ -f ~/.bashrc ]; then
    . ~/.bashrc
  fi
fi
mesg n || true
clear
menu
END_PROFILE
chmod 644 /root/.profile

# ------------------------------
# Log services & ports
# ------------------------------
LOG="/root/log-install.txt"
{
echo ""
printf "┌───────────────────────────────────────────────────────────────┐\n"
printf "│                         SERVICE & PORTS                        │\n"
printf "└───────────────────────────────────────────────────────────────┘\n"
echo "   - OpenSSH                  : 22"
echo "   - OpenVPN                  : 1194"
echo "   - SSH Websocket            : 80"
echo "   - SSH SSL Websocket        : 443"
echo "   - OVPN Websocket           : 80"
echo "   - OVPN SSL Websocket       : 443"
echo "   - Stunnel4                 : 222, 777"
echo "   - Dropbear                 : 109, 143"
echo "   - UDP CUSTOM               : 1-65535"
echo "   - Badvpn                   : 7100-7900"
echo "   - Nginx                    : 81"
echo "   - Vmess WS TLS             : 443"
echo "   - Vless WS TLS             : 443"
echo "   - Trojan WS TLS            : 443"
echo "   - Shadowsocks WS TLS       : 443"
echo "   - Vmess WS none TLS        : 80"
echo "   - Vless WS none TLS        : 80"
echo "   - Trojan WS none TLS       : 80"
echo "   - Shadowsocks WS none TLS  : 80"
echo "   - Vmess gRPC               : 443"
echo "   - Vless gRPC               : 443"
echo "   - Trojan gRPC              : 443"
echo "   - Shadowsocks gRPC         : 443"
echo "   - DNSTT Server             : 443"
echo ""
} >>"$LOG"

# ------------------------------
# Finish
# ------------------------------
chmod 644 /etc/systemd/system/ws-stunnel.service
chmod 644 /etc/systemd/system/ws-ovpn.service
chmod 644 /etc/systemd/system/ws-dropbear.service
chmod 644 /etc/systemd/system/xray.service
history -c
echo "Installation complete! Rebooting in 10 seconds..."
sleep 10
rm -f /root/setup.sh
chmod 644 /etc/systemd/system/ws-stunnel.service
chmod 644 /etc/systemd/system/ws-ovpn.service
chmod 644 /etc/systemd/system/ws-dropbear.service
chmod 644 /etc/systemd/system/xray.service
reboot
