#!/bin/bash

# ------------------------------
# Progress Bar Functions
# ------------------------------
show_progress() {
    local pid=$1
    local msg=$2
    local delay=0.1
    local spinstr='|/-\'
    local temp
    
    echo -n "$msg...  "
    while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
        temp=${spinstr#?}
        printf " [%c]  " "$spinstr"
        spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    printf "    \b\b\b\b"
    echo -e "\r✅ $msg completed!"
}

progress_bar() {
    local duration=${1}
    local columns=$(tput cols)
    local space=$((columns - 30))
    local increment=$((duration / space))
    
    for ((i=0; i<=space; i++)); do
        echo -ne "\r["
        for ((j=0; j<i; j++)); do
            echo -ne "#"
        done
        for ((j=i; j<space; j++)); do
            echo -ne " "
        done
        echo -ne "] $(( (i * 100) / space ))%"
        sleep $increment
    done
    echo ""
}

apt_update_install() {
    echo "📦 Updating package list..."
    apt update -y >/dev/null 2>&1 &
    show_progress $! "System update"
    
    echo "📦 Installing dependencies..."
    apt install -y jq curl wget >/dev/null 2>&1 &
    show_progress $! "Dependencies installation"
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

echo ""
echo "┌──────────────────────────────────────────────────────────┐"
echo "│            🚀 STARTING INSTALLATION PROCESS              │"
echo "└──────────────────────────────────────────────────────────┘"
echo ""

# ------------------------------
# Initial setup
# ------------------------------
apt_update_install

echo "📁 Creating necessary directories..."
mkdir -p /etc/xray /etc/v2ray /root/scripts /var/lib 2>/dev/null
touch /etc/xray/domain /etc/v2ray/domain /etc/xray/scdomain /etc/v2ray/scdomain /root/scdomain
echo "✅ Directory structure created"

IP=$(curl -s ipv4.icanhazip.com)

# ------------------------------
# Domain Selection Menu
# ------------------------------
clear
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

echo ""
echo "⏳ Configuring domain settings..."
case "$dns" in
  1)
    # Random A + NS
    SUB="ws-$(tr -dc a-z0-9 </dev/urandom | head -c5).$DOMAIN"
    NS_SUB="dns.$SUB"
    
    echo "  📝 Creating A record: $SUB → $IP"
    curl -s -X POST "https://api.cloudflare.com/client/v4/zones/$ZONE/dns_records" \
      -H "Authorization: Bearer $CF_TOKEN" \
      -H "Content-Type: application/json" \
      --data "{\"type\":\"A\",\"name\":\"$SUB\",\"content\":\"$IP\",\"ttl\":120,\"proxied\":false}" >/dev/null &
    show_progress $! "Creating A record"
    
    echo "  📝 Creating NS record: $NS_SUB → $SUB"
    curl -s -X POST "https://api.cloudflare.com/client/v4/zones/$ZONE/dns_records" \
      -H "Authorization: Bearer $CF_TOKEN" \
      -H "Content-Type: application/json" \
      --data "{\"type\":\"NS\",\"name\":\"$NS_SUB\",\"content\":\"$SUB\",\"ttl\":120}" >/dev/null &
    show_progress $! "Creating NS record"
    
    echo "$SUB" | tee /root/scdomain /etc/xray/domain /etc/v2ray/domain /etc/xray/scdomain /var/lib/ipvps.conf >/dev/null
    echo "$NS_SUB" | tee /root/nsdomain >/dev/null
    ;;
  2)
    SUB="ws-$(tr -dc a-z0-9 </dev/urandom | head -c5).$DOMAIN"
    
    echo "  📝 Creating A record: $SUB → $IP"
    curl -s -X POST "https://api.cloudflare.com/client/v4/zones/$ZONE/dns_records" \
      -H "Authorization: Bearer $CF_TOKEN" \
      -H "Content-Type: application/json" \
      --data "{\"type\":\"A\",\"name\":\"$SUB\",\"content\":\"$IP\",\"ttl\":120,\"proxied\":false}" >/dev/null &
    show_progress $! "Creating A record"
    
    echo "$SUB" | tee /root/scdomain /etc/xray/domain /etc/v2ray/domain >/dev/null
    ;;
  3)
    read -rp "Enter your domain (A only): " dom
    echo ""
    echo "⏳ Setting up domain: $dom"
    progress_bar 2
    echo "$dom" | tee /root/scdomain /etc/xray/domain /etc/v2ray/domain >/dev/null
    SUB="$dom"
    ;;
  4)
    read -rp "Enter your domain (A+NS): " dom
    SUB="$dom"
    NS_SUB="dns.$SUB"
    
    echo ""
    echo "⏳ Configuring domain: $dom"
    echo "  📝 Creating NS record: $NS_SUB → $SUB"
    curl -s -X POST "https://api.cloudflare.com/client/v4/zones/$ZONE/dns_records" \
      -H "Authorization: Bearer $CF_TOKEN" \
      -H "Content-Type: application/json" \
      --data "{\"type\":\"NS\",\"name\":\"$NS_SUB\",\"content\":\"$SUB\",\"ttl\":120}" >/dev/null &
    show_progress $! "Creating NS record"
    
    echo "$SUB" | tee /root/scdomain /etc/xray/domain /etc/v2ray/domain >/dev/null
    echo "$NS_SUB" | tee /root/nsdomain >/dev/null
    ;;
esac

echo ""
echo "┌──────────────────────────────────────────────────────────┐"
echo "│                     ✅ DOMAIN SUMMARY                    │"
echo "└──────────────────────────────────────────────────────────┘"
echo "  A Record → $SUB → $IP"
[[ ! -z "$NS_SUB" ]] && echo "  NS Record → $NS_SUB → $SUB"
echo ""

# ------------------------------
# Install Services with Progress
# ------------------------------
echo "🚀 Starting main installation process..."
echo ""

echo "📥 Downloading SSH VPN installer..."
wget -q -O /root/ssh-vpn.sh "https://raw.githubusercontent.com/Mahboub-power-is-back/multiws/master/ssh/ssh-vpn.sh" &
show_progress $! "Downloading SSH VPN script"
chmod +x /root/ssh-vpn.sh

echo "🔄 Installing SSH VPN service..."
bash /root/ssh-vpn.sh >/dev/null 2>&1 &
show_progress $! "Installing SSH VPN"

echo "📥 Downloading Xray installer..."
wget -q -O /root/ins-xray.sh "https://raw.githubusercontent.com/Mahboub-power-is-back/multiws/master/xray/ins-xray.sh" &
show_progress $! "Downloading Xray script"
chmod +x /root/ins-xray.sh

echo "🔄 Installing Xray service..."
bash /root/ins-xray.sh >/dev/null 2>&1 &
show_progress $! "Installing Xray"

echo "📥 Downloading SSH Websocket installer..."
wget -q -O /root/insshws.sh "https://raw.githubusercontent.com/Mahboub-power-is-back/multiws/refs/heads/master/sshws/insshws.sh" &
show_progress $! "Downloading SSH Websocket script"
chmod +x /root/insshws.sh

echo "🔄 Installing SSH Websocket..."
bash /root/insshws.sh >/dev/null 2>&1 &
show_progress $! "Installing SSH Websocket"

# ------------------------------
# Install DNSTT Service
# ------------------------------
echo ""
echo "🌐 Configuring DNSTT Service..."
if [ -f /root/nsdomain ]; then
    DnsNS=$(cat /root/nsdomain)
    echo "  Using NS domain: $DnsNS"
else
    echo "  ⚠️ NS domain not found! Skipping DNSTT."
    DnsNS=""
fi

PORT1=443
echo "📥 Downloading DNSTT server..."
wget -q -c https://raw.githubusercontent.com/Mahboub-power-is-back/Myapp/refs/heads/main/dnstt-server -O /usr/local/bin/dnstt-server &
show_progress $! "Downloading DNSTT server"
chmod +x /usr/local/bin/dnstt-server

echo "🔄 Configuring DNSTT service..."
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

echo "⚙️ Starting DNSTT service..."
systemctl daemon-reload >/dev/null 2>&1
systemctl start dnstt-service >/dev/null 2>&1 &
show_progress $! "Starting DNSTT service"
systemctl enable dnstt-service >/dev/null 2>&1

echo "✅ DNSTT server started on TCP/UDP port $PORT1"

# ------------------------------
# Setup .profile
# ------------------------------
echo "⚙️ Configuring user profile..."
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
# Final Configuration
# ------------------------------
echo "📝 Finalizing configuration..."
chmod 644 /etc/systemd/system/ws-stunnel.service
chmod 644 /etc/systemd/system/ws-ovpn.service
chmod 644 /etc/systemd/system/ws-dropbear.service
chmod 644 /etc/systemd/system/xray.service

# ------------------------------
# Installation Summary
# ------------------------------
clear
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
echo "│  • OVPN SSL Websocket       : 443                             │"
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
} > "$LOG"

# Countdown before reboot
for i in {10..1}; do
    echo -ne "\rRebooting in $i seconds... "
    sleep 1
done

echo ""
echo "🔄 Rebooting now..."
rm -f /root/setup.sh
history -c
sleep 2
reboot
