#!/bin/bash
# ==========================================
# Multi-service VPS Installer (Xray + SSH + WS)
# Auto-subdomain + Cloudflare
# ==========================================

# Dependencies
apt update -y && apt install -y jq curl git python3 unzip

# ---------------------------
# Generate Random Subdomain
# ---------------------------
sub=$(</dev/urandom tr -dc a-z0-9 | head -c5)
DOMAIN="mahboubvps.site"
SUB_DOMAIN="ws-${sub}.${DOMAIN}"
CF_TOKEN="XOYA63kolRF-6_EzxZQ22ESucCdm7zSJl7NEDQtA"
IP=$(curl -s ipv4.icanhazip.com)
ZONE="8761c8222fe8a4d1249e8563eedf43ee"

echo "[*] Server IP: $IP"
echo "[*] Subdomain to create: $SUB_DOMAIN"
echo "[*] Using Zone ID: $ZONE"

# ---------------------------
# Create or Update Cloudflare Record
# ---------------------------
RESPONSE=$(curl -sLX GET "https://api.cloudflare.com/client/v4/zones/${ZONE}/dns_records?name=${SUB_DOMAIN}" \
  -H "Authorization: Bearer ${CF_TOKEN}" \
  -H "Content-Type: application/json")

RECORD_ID=$(echo "$RESPONSE" | jq -r '.result[0].id')

if [[ -z "$RECORD_ID" || "$RECORD_ID" == "null" ]]; then
    echo "[*] Record does not exist, creating..."
    CREATE_RESPONSE=$(curl -sLX POST "https://api.cloudflare.com/client/v4/zones/${ZONE}/dns_records" \
        -H "Authorization: Bearer ${CF_TOKEN}" \
        -H "Content-Type: application/json" \
        --data "{\"type\":\"A\",\"name\":\"${SUB_DOMAIN}\",\"content\":\"${IP}\",\"ttl\":120,\"proxied\":false}")
else
    echo "[*] Record exists, updating..."
    UPDATE_RESPONSE=$(curl -sLX PUT "https://api.cloudflare.com/client/v4/zones/${ZONE}/dns_records/${RECORD_ID}" \
        -H "Authorization: Bearer ${CF_TOKEN}" \
        -H "Content-Type: application/json" \
        --data "{\"type\":\"A\",\"name\":\"${SUB_DOMAIN}\",\"content\":\"${IP}\",\"ttl\":120,\"proxied\":false}")
fi

# ---------------------------
# Save Subdomain and IP
# ---------------------------
mkdir -p /etc/xray /etc/v2ray
echo "$SUB_DOMAIN" | tee /root/domain /etc/xray/domain /etc/v2ray/domain /root/scdomain > /dev/null
echo "IP=$IP" > /var/lib/ipvps.conf

echo "✅ Subdomain created: $SUB_DOMAIN"

# ---------------------------
# Install SSH Websocket
# ---------------------------
echo "[*] Installing SSH Websocket..."
wget https://raw.githubusercontent.com/Mahboub-power-is-back/multiws/master/ssh/ssh-vpn.sh -O ssh-vpn.sh
chmod +x ssh-vpn.sh && ./ssh-vpn.sh

# ---------------------------
# Install Xray
# ---------------------------
echo "[*] Installing Xray..."
wget https://raw.githubusercontent.com/Mahboub-power-is-back/multiws/master/xray/ins-xray.sh -O ins-xray.sh
chmod +x ins-xray.sh && ./ins-xray.sh

# ---------------------------
# Install SSH WS
# ---------------------------
echo "[*] Installing SSH Websocket Config..."
wget https://raw.githubusercontent.com/Mahboub-power-is-back/multiws/master/sshws/insshws.sh -O insshws.sh
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
echo ""
echo "==================== Installation Complete ===================="
echo "Subdomain: $SUB_DOMAIN"
echo "IP VPS   : $IP"
echo "---------------------------------------------------------------"
echo "OpenSSH                  : 22"
echo "SSH WS                   : 80"
echo "SSH SSL WS               : 443"
echo "Stunnel4                 : 222, 777"
echo "Dropbear                 : 109, 143"
echo "Badvpn                   : 7100-7900"
echo "Nginx                    : 81"
echo "Vmess WS TLS             : 443"
echo "Vless WS TLS             : 443"
echo "Trojan WS TLS            : 443"
echo "Shadowsocks WS TLS       : 443"
echo "Vmess WS none TLS        : 80"
echo "Vless WS none TLS        : 80"
echo "Trojan WS none TLS       : 80"
echo "Shadowsocks WS none TLS  : 80"
echo "Vmess gRPC               : 443"
echo "Vless gRPC               : 443"
echo "Trojan gRPC              : 443"
echo "Shadowsocks gRPC         : 443"
echo "================================================================"
echo "✅ All done! Server will reboot in 10 seconds..."
sleep 10
reboot
