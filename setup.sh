#!/bin/bash

apt update -y >/dev/null 2>&1
apt install -y jq curl wget iptables >/dev/null 2>&1

# ------------------------------
# Cloudflare API Info
# ------------------------------
DOMAIN="mahboubvps.site"
CF_TOKEN="XOYA63kolRF-6_EzxZQ22ESucCdm7zSJl7NEDQtA"
ZONE="8761c8222fe8a4d1249e8563eedf43ee"

# ------------------------------
# Root check
# ------------------------------
if [ "$EUID" -ne 0 ]; then
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
  SUB="ws-$(tr -dc a-z0-9 </dev/urandom | head -c5).$DOMAIN"
  NS_SUB="dns.$SUB"

  curl -s -X POST "https://api.cloudflare.com/client/v4/zones/$ZONE/dns_records" \
    -H "Authorization: Bearer $CF_TOKEN" \
    -H "Content-Type: application/json" \
    --data "{\"type\":\"A\",\"name\":\"$SUB\",\"content\":\"$IP\",\"ttl\":120,\"proxied\":false}" >/dev/null

  curl -s -X POST "https://api.cloudflare.com/client/v4/zones/$ZONE/dns_records" \
    -H "Authorization: Bearer $CF_TOKEN" \
    -H "Content-Type: application/json" \
    --data "{\"type\":\"NS\",\"name\":\"$NS_SUB\",\"content\":\"$SUB\",\"ttl\":120}" >/dev/null

  echo "$NS_SUB" > /root/nsdomain
  ;;
2)
  SUB="ws-$(tr -dc a-z0-9 </dev/urandom | head -c5).$DOMAIN"
  curl -s -X POST "https://api.cloudflare.com/client/v4/zones/$ZONE/dns_records" \
    -H "Authorization: Bearer $CF_TOKEN" \
    -H "Content-Type: application/json" \
    --data "{\"type\":\"A\",\"name\":\"$SUB\",\"content\":\"$IP\",\"ttl\":120,\"proxied\":false}" >/dev/null
  ;;
3)
  read -rp "Enter your domain (A only): " SUB
  ;;
4)
  read -rp "Enter your domain (A+NS): " SUB
  NS_SUB="dns.$SUB"

  curl -s -X POST "https://api.cloudflare.com/client/v4/zones/$ZONE/dns_records" \
    -H "Authorization: Bearer $CF_TOKEN" \
    -H "Content-Type: application/json" \
    --data "{\"type\":\"NS\",\"name\":\"$NS_SUB\",\"content\":\"$SUB\",\"ttl\":120}" >/dev/null

  echo "$NS_SUB" > /root/nsdomain
  ;;
*)
  echo "Invalid option"
  exit 1
  ;;
esac

echo "$SUB" | tee /root/scdomain /etc/xray/domain /etc/v2ray/domain >/dev/null

echo "Domain setup done → $SUB"

# ------------------------------
# Install Services
# ------------------------------
wget -q -O /root/ssh-vpn.sh https://raw.githubusercontent.com/Mahboub-power-is-back/multiws/master/ssh/ssh-vpn.sh
chmod +x /root/ssh-vpn.sh
bash /root/ssh-vpn.sh

wget -q -O /root/ins-xray.sh https://raw.githubusercontent.com/Mahboub-power-is-back/multiws/master/xray/ins-xray.sh
chmod +x /root/ins-xray.sh
bash /root/ins-xray.sh

wget -q -O /root/insshws.sh https://raw.githubusercontent.com/Mahboub-power-is-back/multiws/master/sshws/insshws.sh
chmod +x /root/insshws.sh
bash /root/insshws.sh

# ------------------------------
# DNSTT (SAFE)
# ------------------------------
if [ -f /root/nsdomain ]; then
  DnsNS=$(cat /root/nsdomain)
else
  DnsNS=""
fi

if [ -n "$DnsNS" ]; then
  wget -q -O /usr/local/bin/dnstt-server https://raw.githubusercontent.com/Mahboub-power-is-back/Myapp/main/dnstt-server
  chmod +x /usr/local/bin/dnstt-server

  cat <<EOF > /etc/systemd/system/dnstt-service.service
[Unit]
Description=DNSTT Server
After=network.target

[Service]
Type=simple
WorkingDirectory=/root
ExecStartPre=/usr/sbin/iptables -A INPUT -p tcp --dport 5300 -j ACCEPT
ExecStartPre=/usr/sbin/iptables -t nat -A PREROUTING -p udp --dport 53 -j REDIRECT --to-ports 5300
ExecStart=/usr/local/bin/dnstt-server -udp :5300 -privkey e35bb50094b4d06a17a7606ae724db082398a4cf86ad79bcdcf890386eb65a88 $DnsNS 127.0.0.1:443
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

  systemctl daemon-reload
  systemctl enable --now dnstt-service
  echo "DNSTT installed using NS: $DnsNS"
else
  echo "DNSTT skipped (no NS domain)"
fi

# ------------------------------
# Setup .profile (SAFE)
# ------------------------------
cat > /root/.profile <<'EOF'
if [ -f ~/.bashrc ]; then
  . ~/.bashrc
fi
mesg n || true
clear
command -v menu >/dev/null && menu
EOF

chmod 644 /root/.profile

# ------------------------------
# Log services & ports
# ------------------------------
cat <<EOF > /root/log-install.txt
SERVICE & PORTS
OpenSSH        : 22
OpenVPN        : 1194
SSH WS         : 80
SSH SSL WS     : 443
Dropbear       : 109,143
Stunnel        : 222,777
BadVPN         : 7100-7900
Nginx          : 81
XRAY TLS       : 443
XRAY Non TLS   : 80
gRPC           : 443
DNSTT          : 443
Domain         : $SUB
NS             : ${DnsNS:-None}
EOF

# ------------------------------
# Finish
# ------------------------------
history -c
echo "Installation complete. Rebooting in 10 seconds..."
sleep 10
reboot
