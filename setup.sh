#!/bin/bash

# ------------------------------
# Single Loading Bar Function
# ------------------------------
total_steps=16
current_step=0

update_progress() {
    local step_name="$1"
    current_step=$((current_step + 1))
    local percentage=$((current_step * 100 / total_steps))
    local bar_length=50
    local filled=$((bar_length * current_step / total_steps))
    local empty=$((bar_length - filled))
    
    # Clear line and draw progress bar
    printf "\r\033[K"  # Clear entire line
    printf "┌──────────────────────────────────────────────────────────┐\n"
    printf "│                🚀 INSTALLATION PROGRESS                  │\n"
    printf "├──────────────────────────────────────────────────────────┤\n"
    printf "│ "
    for ((i=0; i<filled; i++)); do printf "█"; done
    for ((i=0; i<empty; i++)); do printf "░"; done
    printf " │ %3d%%\n" "$percentage"
    printf "├──────────────────────────────────────────────────────────┤\n"
    printf "│ %-50s │\n" "$step_name"
    printf "└──────────────────────────────────────────────────────────┘\n"
    echo ""
}

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
    echo "❌ Run this script as root!"
    exit 1
fi

clear
update_progress "Starting installation..."

# ------------------------------
# Initial setup
# ------------------------------
update_progress "Updating system packages..."
apt update -y >/dev/null 2>&1

update_progress "Installing dependencies..."
apt install -y jq curl wget >/dev/null 2>&1

update_progress "Creating directory structure..."
mkdir -p /etc/xray /etc/v2ray /root/scripts /var/lib 2>/dev/null
touch /etc/xray/domain /etc/v2ray/domain /etc/xray/scdomain /etc/v2ray/scdomain /root/scdomain

IP=$(curl -s ipv4.icanhazip.com)

# ------------------------------
# Domain Selection Menu
# ------------------------------
clear
update_progress "Domain configuration..."

echo ""
echo "┌──────────────────────────────────────────────────────────┐"
echo "│              🌐 DOMAIN CONFIGURATION MENU                │"
echo "└──────────────────────────────────────────────────────────┘"
echo "  [1] Random A + NS (Cloudflare)"
echo "  [2] Random A only (Cloudflare)"
echo "  [3] Your domain A only"
echo "  [4] Your domain A + NS"
echo ""

while true; do
    read -rp "Select option (1/2/3/4): " dns
    case $dns in
        1|2|3|4) break ;;
        *) echo "❌ Invalid selection. Please enter 1, 2, 3, or 4." ;;
    esac
done

case "$dns" in
  1)
    SUB="ws-$(tr -dc a-z0-9 </dev/urandom | head -c5).$DOMAIN"
    NS_SUB="dns.$SUB"
    
    update_progress "Creating Cloudflare A record..."
    curl -s -X POST "https://api.cloudflare.com/client/v4/zones/$ZONE/dns_records" \
      -H "Authorization: Bearer $CF_TOKEN" \
      -H "Content-Type: application/json" \
      --data "{\"type\":\"A\",\"name\":\"$SUB\",\"content\":\"$IP\",\"ttl\":120,\"proxied\":false}" >/dev/null
    
    update_progress "Creating Cloudflare NS record..."
    curl -s -X POST "https://api.cloudflare.com/client/v4/zones/$ZONE/dns_records" \
      -H "Authorization: Bearer $CF_TOKEN" \
      -H "Content-Type: application/json" \
      --data "{\"type\":\"NS\",\"name\":\"$NS_SUB\",\"content\":\"$SUB\",\"ttl\":120}" >/dev/null
    
    echo "$SUB" | tee /root/scdomain /etc/xray/domain /etc/v2ray/domain /etc/xray/scdomain /var/lib/ipvps.conf >/dev/null
    echo "$NS_SUB" | tee /root/nsdomain >/dev/null
    ;;
  2)
    SUB="ws-$(tr -dc a-z0-9 </dev/urandom | head -c5).$DOMAIN"
    
    update_progress "Creating Cloudflare A record..."
    curl -s -X POST "https://api.cloudflare.com/client/v4/zones/$ZONE/dns_records" \
      -H "Authorization: Bearer $CF_TOKEN" \
      -H "Content-Type: application/json" \
      --data "{\"type\":\"A\",\"name\":\"$SUB\",\"content\":\"$IP\",\"ttl\":120,\"proxied\":false}" >/dev/null
    
    echo "$SUB" | tee /root/scdomain /etc/xray/domain /etc/v2ray/domain >/dev/null
    ;;
  3)
    read -rp "Enter your domain (A only): " dom
    SUB="$dom"
    update_progress "Configuring domain..."
    echo "$dom" | tee /root/scdomain /etc/xray/domain /etc/v2ray/domain >/dev/null
    ;;
  4)
    read -rp "Enter your domain (A+NS): " dom
    SUB="$dom"
    NS_SUB="dns.$SUB"
    
    update_progress "Creating Cloudflare NS record..."
    curl -s -X POST "https://api.cloudflare.com/client/v4/zones/$ZONE/dns_records" \
      -H "Authorization: Bearer $CF_TOKEN" \
      -H "Content-Type: application/json" \
      --data "{\"type\":\"NS\",\"name\":\"$NS_SUB\",\"content\":\"$SUB\",\"ttl\":120}" >/dev/null
    
    echo "$SUB" | tee /root/scdomain /etc/xray/domain /etc/v2ray/domain >/dev/null
    echo "$NS_SUB" | tee /root/nsdomain >/dev/null
    ;;
esac

clear
update_progress "Domain setup complete!"

echo ""
echo "┌──────────────────────────────────────────────────────────┐"
echo "│                     ✅ DOMAIN SUMMARY                    │"
echo "└──────────────────────────────────────────────────────────┘"
echo "  A Record → $SUB → $IP"
[[ ! -z "$NS_SUB" ]] && echo "  NS Record → $NS_SUB → $SUB"
echo ""

# ------------------------------
# Install Services
# ------------------------------
update_progress "Downloading SSH VPN installer..."
wget -q -O /root/ssh-vpn.sh "https://raw.githubusercontent.com/Mahboub-power-is-back/multiws/master/ssh/ssh-vpn.sh"
chmod +x /root/ssh-vpn.sh

update_progress "Installing SSH VPN service..."
bash /root/ssh-vpn.sh >/dev/null 2>&1

update_progress "Downloading Xray installer..."
wget -q -O /root/ins-xray.sh "https://raw.githubusercontent.com/Mahboub-power-is-back/multiws/master/xray/ins-xray.sh"
chmod +x /root/ins-xray.sh

update_progress "Installing Xray service..."
bash /root/ins-xray.sh >/dev/null 2>&1

update_progress "Downloading SSH Websocket installer..."
wget -q -O /root/insshws.sh "https://raw.githubusercontent.com/Mahboub-power-is-back/multiws/refs/heads/master/sshws/insshws.sh"
chmod +x /root/insshws.sh

update_progress "Installing SSH Websocket..."
bash /root/insshws.sh >/dev/null 2>&1

# ------------------------------
# Install DNSTT Service
# ------------------------------
update_progress "Configuring DNSTT Service..."
if [ -f /root/nsdomain ]; then
    DnsNS=$(cat /root/nsdomain)
else
    echo "⚠️ NS domain not found! Skipping DNSTT."
    DnsNS=""
fi

PORT1=443

update_progress "Downloading DNSTT server..."
wget -q -c https://raw.githubusercontent.com/Mahboub-power-is-back/Myapp/refs/heads/main/dnstt-server -O /usr/local/bin/dnstt-server
chmod +x /usr/local/bin/dnstt-server

update_progress "Creating DNSTT service file..."
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

update_progress "Starting DNSTT service..."
systemctl daemon-reload >/dev/null 2>&1
systemctl start dnstt-service >/dev/null 2>&1
systemctl enable dnstt-service >/dev/null 2>&1

# ------------------------------
# Final Configuration
# ------------------------------
update_progress "Setting up user profile..."
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

update_progress "Setting file permissions..."
chmod 644 /etc/systemd/system/ws-stunnel.service
chmod 644 /etc/systemd/system/ws-ovpn.service
chmod 644 /etc/systemd/system/ws-dropbear.service
chmod 644 /etc/systemd/system/xray.service

# ------------------------------
# Installation Summary
# ------------------------------
clear
update_progress "Installation complete! Preparing summary..."

# Final 100% display
printf "\r\033[K"  # Clear entire line
printf "┌──────────────────────────────────────────────────────────┐\n"
printf "│                🚀 INSTALLATION PROGRESS                  │\n"
printf "├──────────────────────────────────────────────────────────┤\n"
printf "│ ████████████████████████████████████████████████████████ │ 100%%\n"
printf "├──────────────────────────────────────────────────────────┤\n"
printf "│ ✅ Installation Complete! Ready to reboot.               │\n"
printf "└──────────────────────────────────────────────────────────┘\n"
echo ""

echo "┌───────────────────────────────────────────────────────────────┐"
echo "│                     🎉 INSTALLATION COMPLETE                  │"
echo "├───────────────────────────────────────────────────────────────┤"
echo "│                         SERVICE & PORTS                        │"
echo "├───────────────────────────────────────────────────────────────┤"
echo "│  • OpenSSH                  : 22                              │"
echo "│  • OpenVPN                  : 1194                            │"
echo "│  • SSH Websocket            : 80                              │"
echo "│  • SSH SSL Websocket        : 443                             │"
echo "│  • OVPN Websocket           : 80                              │"
echo "│  • OVPN SSL Websocket       : 443                             │
echo "│  • Stunnel4                 : 222, 777                        │"
echo "│  • Dropbear                 : 109, 143                        │"
echo "│  • UDP CUSTOM               : 1-65535                         │"
echo "│  • Badvpn                   : 7100-7900                       │"
echo "│  • Nginx                    : 81                              │"
echo "│  • Vmess WS TLS             : 443                             │"
echo "│  • Vless WS TLS             : 443                             │"
echo "│  • Trojan WS TLS            : 443                             │"
echo "│  • Shadowsocks WS TLS       : 443                             │"
echo "│  • Vmess WS none TLS        : 80                              │"
echo "│  • Vless WS none TLS        : 80                              │"
echo "│  • Trojan WS none TLS       : 80                              │"
echo "│  • Shadowsocks WS none TLS  : 80                              │"
echo "│  • Vmess gRPC               : 443                             │"
echo "│  • Vless gRPC               : 443                             │"
echo "│  • Trojan gRPC              : 443                             │"
echo "│  • Shadowsocks gRPC         : 443                             │"
echo "│  • DNSTT Server             : 443                             │"
echo "└───────────────────────────────────────────────────────────────┘"
echo ""
echo "🌐 Domain: $SUB"
echo "📡 IP Address: $IP"
echo ""
echo "⏳ System will reboot in 10 seconds..."
echo ""

# Save log
LOG="/root/log-install.txt"
{
echo "Installation completed at: $(date)"
echo "Domain: $SUB"
echo "IP Address: $IP"
echo "Services installed: SSH VPN, Xray, SSH Websocket, DNSTT"
} > "$LOG"

# Countdown with visual bar
echo "Reboot countdown:"
for i in {10..1}; do
    filled=$((10 - i))
    empty=$((i - 1))
    printf "\r["
    for ((j=0; j<filled; j++)); do printf "▰"; done
    for ((j=0; j<empty; j++)); do printf "▱"; done
    printf "] %2d seconds remaining" "$i"
    sleep 1
done

echo ""
echo "🔄 Rebooting now..."
rm -f /root/setup.sh
history -c
sleep 2
reboot
