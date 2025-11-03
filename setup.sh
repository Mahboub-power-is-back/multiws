#!/bin/bash
# ==========================================
# Multi-service VPS Installer (Xray + SSH + WS)
# Auto-subdomain + Cloudflare
# ==========================================

# Dependencies
apt update -y && apt install -y jq curl git python3 unzip -y

# ---------------------------
# DOMAIN SELECTION
# ---------------------------
echo "======================================"
echo "          DOMAIN SELECTION MENU        "
echo "======================================"
echo "1) Use RANDOM Subdomain"
echo "2) Use YOUR OWN Custom Domain"
read -rp "Choose option (1/2): " DOMAIN_CHOICE

MYIP=$(curl -s ipv4.icanhazip.com)
DEFAULT_DOMAIN="mahboubvps.site"
CF_TOKEN="XOYA63kolRF-6_EzxZQ22ESucCdm7zSJl7NEDQtA"
ZONE="8761c8222fe8a4d1249e8563eedf43ee"

if [[ $DOMAIN_CHOICE == "1" ]]; then
    sub=$(</dev/urandom tr -dc a-z0-9 | head -c5)
    SUB_DOMAIN="ws-${sub}.${DEFAULT_DOMAIN}"
elif [[ $DOMAIN_CHOICE == "2" ]]; then
    read -rp "Enter your full custom domain: " CUSTOM_DOMAIN
    SUB_DOMAIN="$CUSTOM_DOMAIN"
else
    echo "Invalid selection!"
    exit 1
fi

echo "[*] Server IP: $MYIP"
echo "[*] Domain to create: $SUB_DOMAIN"

# ---------------------------
# Create or Update Cloudflare Record
# ---------------------------
RESPONSE=$(curl -sLX GET "https://api.cloudflare.com/client/v4/zones/${ZONE}/dns_records?name=${SUB_DOMAIN}" \
  -H "Authorization: Bearer ${CF_TOKEN}" \
  -H "Content-Type: application/json")

RECORD_ID=$(echo "$RESPONSE" | jq -r '.result[0].id')

if [[ -z "$RECORD_ID" || "$RECORD_ID" == "null" ]]; then
    echo "[*] Record does not exist, creating..."
    curl -sLX POST "https://api.cloudflare.com/client/v4/zones/${ZONE}/dns_records" \
        -H "Authorization: Bearer ${CF_TOKEN}" \
        -H "Content-Type: application/json" \
        --data "{\"type\":\"A\",\"name\":\"${SUB_DOMAIN}\",\"content\":\"${MYIP}\",\"ttl\":120,\"proxied\":false}"
else
    echo "[*] Record exists, updating..."
    curl -sLX PUT "https://api.cloudflare.com/client/v4/zones/${ZONE}/dns_records/${RECORD_ID}" \
        -H "Authorization: Bearer ${CF_TOKEN}" \
        -H "Content-Type: application/json" \
        --data "{\"type\":\"A\",\"name\":\"${SUB_DOMAIN}\",\"content\":\"${MYIP}\",\"ttl\":120,\"proxied\":false}"
fi

# ---------------------------
# Save Subdomain and IP
# ---------------------------
mkdir -p /etc/xray /etc/v2ray
echo "$SUB_DOMAIN" | tee /root/domain /etc/xray/domain /etc/v2ray/domain /root/scdomain > /dev/null
echo "IP=$MYIP" > /var/lib/ipvps.conf

echo "✅ Domain created: $SUB_DOMAIN"

# ---------------------------
# Install SSH Websocket
# ---------------------------
echo "[*] Installing SSH Websocket..."
wget -q https://raw.githubusercontent.com/Mahboub-power-is-back/multiws/master/ssh/ssh-vpn.sh -O ssh-vpn.sh
chmod +x ssh-vpn.sh && ./ssh-vpn.sh

# ---------------------------
# Install Xray
# ---------------------------
echo "[*] Installing Xray..."
wget -q https://raw.githubusercontent.com/Mahboub-power-is-back/multiws/master/xray/ins-xray.sh -O ins-xray.sh
chmod +x ins-xray.sh && ./ins-xray.sh

# ---------------------------
# Install SSH WS
# ---------------------------
echo "[*] Installing SSH Websocket Config..."
wget -q https://raw.githubusercontent.com/Mahboub-power-is-back/multiws/master/sshws/insshws.sh -O insshws.sh
chmod +x insshws.sh && ./insshws.sh

# ---------------------------
# Add Profile to Load Menu
# ---------------------------
cat > /root/.profile << END
# ~/.profile
if [ "\$BASH" ]; then
  if [ -f ~/.bashrc ]; then
    . ~/.bashrc
  fi
fi
mesg n || true
clear
menu
END
chmod 644 /root/.profile

# ---------------------------
# Log Install Info
# ---------------------------
LOG_FILE="/root/log-install.txt"
cat << EOF | tee $LOG_FILE

==================== Installation Complete ====================
Subdomain / Domain: $SUB_DOMAIN
IP VPS             : $MYIP
---------------------------------------------------------------
OpenSSH                  : 22
SSH WS                   : 80
SSH SSL WS               : 443
Stunnel4                 : 222, 777
Dropbear                 : 109, 143
Badvpn                   : 7100-7900
Nginx                    : 81
Vmess WS TLS             : 443
Vless WS TLS             : 443
Trojan WS TLS            : 443
Shadowsocks WS TLS       : 443
Vmess WS none TLS        : 80
Vless WS none TLS        : 80
Trojan WS none TLS       : 80
Shadowsocks WS none TLS  : 80
Vmess gRPC               : 443
Vless gRPC               : 443
Trojan gRPC              : 443
Shadowsocks gRPC         : 443
================================================================
EOF

echo "✅ All done! Log saved in $LOG_FILE"
echo "Server will reboot in 10 seconds..."
sleep 10
reboot
