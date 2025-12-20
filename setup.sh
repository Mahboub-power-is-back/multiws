#!/bin/bash

# ------------------------------
# Color and styling
# ------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'
BOLD='\033[1m'
ITALIC='\033[3m'

# ------------------------------
# Loading bar function
# ------------------------------
show_progress() {
    local duration=$1
    local steps=50
    local step_delay=$(echo "scale=3; $duration/$steps" | bc -l)
    
    printf "\n${CYAN}[${NC}"
    for ((i=0; i<steps; i++)); do
        printf "▰"
        sleep $step_delay
    done
    printf "${CYAN}]${NC}\n"
}

spin_progress() {
    local pid=$1
    local msg=$2
    local spin=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
    
    printf "${CYAN}${msg}${NC} "
    while kill -0 $pid 2>/dev/null; do
        for i in "${spin[@]}"; do
            printf "\b$i"
            sleep 0.1
        done
    done
    printf "\b${GREEN}✓${NC}\n"
}

run_with_progress() {
    local cmd="$1"
    local msg="$2"
    
    eval "$cmd" >/dev/null 2>&1 &
    local pid=$!
    spin_progress $pid "$msg"
    wait $pid
    return $?
}

# ------------------------------
# Banner
# ------------------------------
clear
echo -e "${BLUE}"
echo "┌──────────────────────────────────────────────────────────┐"
echo "│                   ${GREEN}INSTALLATION WIZARD${BLUE}                    │"
echo "│                 ${YELLOW}Multi-Protocol VPN Server${BLUE}                │"
echo "└──────────────────────────────────────────────────────────┘"
echo -e "${NC}"

# ------------------------------
# Initial setup
# ------------------------------
echo -e "${BOLD}Initializing system...${NC}"

# Root check
if [ "${EUID:-0}" -ne 0 ]; then
    echo -e "${RED}✗ Run this script as root!${NC}"
    exit 1
fi

# Create directories
mkdir -p /etc/xray /etc/v2ray /root/scripts /var/lib 2>/dev/null
touch /etc/xray/domain /etc/v2ray/domain /etc/xray/scdomain /etc/v2ray/scdomain /root/scdomain

# ------------------------------
# Cloudflare API Info
# ------------------------------
DOMAIN="mahboubvps.site"
CF_TOKEN="XOYA63kolRF-6_EzxZQ22ESucCdm7zSJl7NEDQtA"
ZONE="8761c8222fe8a4d1249e8563eedf43ee"

# ------------------------------
# Install Dependencies
# ------------------------------
echo -e "\n${BOLD}Installing dependencies...${NC}"
run_with_progress "apt update -y" "Updating package list"
run_with_progress "apt install -y jq curl wget" "Installing required packages"

# Get IP
IP=$(curl -s ipv4.icanhazip.com)
echo -e "${GREEN}✓ Server IP: $IP${NC}"

# ------------------------------
# Domain Selection Menu
# ------------------------------
echo -e "\n${BOLD}${CYAN}┌──────────────────────────────────────────────────────────┐${NC}"
echo -e "${BOLD}${CYAN}│              DOMAIN CONFIGURATION MENU                   │${NC}"
echo -e "${BOLD}${CYAN}└──────────────────────────────────────────────────────────┘${NC}"
echo -e "${YELLOW}[1] Random A + NS (Cloudflare)${NC}"
echo -e "${YELLOW}[2] Random A only (Cloudflare)${NC}"
echo -e "${YELLOW}[3] Your domain A only${NC}"
echo -e "${YELLOW}[4] Your domain A + NS${NC}"
echo ""

while true; do
    read -rp "Select option (1/2/3/4): " dns
    case "$dns" in
        1|2|3|4) break ;;
        *) echo -e "${RED}Invalid option! Please choose 1-4${NC}" ;;
    esac
done

echo -e "\n${BOLD}Configuring domain...${NC}"

case "$dns" in
  1)
    # Random A + NS
    SUB="ws-$(tr -dc a-z0-9 </dev/urandom | head -c5).$DOMAIN"
    NS_SUB="dns.$SUB"
    
    echo -e "${CYAN}Creating A record: $SUB → $IP${NC}"
    curl -s -X POST "https://api.cloudflare.com/client/v4/zones/$ZONE/dns_records" \
      -H "Authorization: Bearer $CF_TOKEN" \
      -H "Content-Type: application/json" \
      --data "{\"type\":\"A\",\"name\":\"$SUB\",\"content\":\"$IP\",\"ttl\":120,\"proxied\":false}" >/dev/null
    
    echo -e "${CYAN}Creating NS record: $NS_SUB → $SUB${NC}"
    curl -s -X POST "https://api.cloudflare.com/client/v4/zones/$ZONE/dns_records" \
      -H "Authorization: Bearer $CF_TOKEN" \
      -H "Content-Type: application/json" \
      --data "{\"type\":\"NS\",\"name\":\"$NS_SUB\",\"content\":\"$SUB\",\"ttl\":120}" >/dev/null
    
    echo "$SUB" | tee /root/scdomain /etc/xray/domain /etc/v2ray/domain /etc/xray/scdomain /var/lib/ipvps.conf >/dev/null
    echo "$NS_SUB" | tee /root/nsdomain >/dev/null
    ;;
    
  2)
    SUB="ws-$(tr -dc a-z0-9 </dev/urandom | head -c5).$DOMAIN"
    echo -e "${CYAN}Creating A record: $SUB → $IP${NC}"
    curl -s -X POST "https://api.cloudflare.com/client/v4/zones/$ZONE/dns_records" \
      -H "Authorization: Bearer $CF_TOKEN" \
      -H "Content-Type: application/json" \
      --data "{\"type\":\"A\",\"name\":\"$SUB\",\"content\":\"$IP\",\"ttl\":120,\"proxied\":false}" >/dev/null
    echo "$SUB" | tee /root/scdomain /etc/xray/domain /etc/v2ray/domain >/dev/null
    ;;
    
  3)
    read -rp "Enter your domain (A only): " dom
    echo "$dom" | tee /root/scdomain /etc/xray/domain /etc/v2ray/domain >/dev/null
    SUB="$dom"
    ;;
    
  4)
    read -rp "Enter your domain (A+NS): " dom
    SUB="$dom"
    NS_SUB="dns.$SUB"
    
    echo -e "${CYAN}Creating NS record: $NS_SUB → $SUB${NC}"
    curl -s -X POST "https://api.cloudflare.com/client/v4/zones/$ZONE/dns_records" \
      -H "Authorization: Bearer $CF_TOKEN" \
      -H "Content-Type: application/json" \
      --data "{\"type\":\"NS\",\"name\":\"$NS_SUB\",\"content\":\"$SUB\",\"ttl\":120}" >/dev/null
    
    echo "$SUB" | tee /root/scdomain /etc/xray/domain /etc/v2ray/domain >/dev/null
    echo "$NS_SUB" | tee /root/nsdomain >/dev/null
    ;;
esac

echo -e "${GREEN}✓ Domain setup complete!${NC}"
echo -e "${CYAN}A Record → $SUB → $IP${NC}"
[[ ! -z "$NS_SUB" ]] && echo -e "${CYAN}NS Record → $NS_SUB → $SUB${NC}"

# ------------------------------
# Installation Progress
# ------------------------------
echo -e "\n${BOLD}${CYAN}┌──────────────────────────────────────────────────────────┐${NC}"
echo -e "${BOLD}${CYAN}│                 INSTALLATION PROGRESS                    │${NC}"
echo -e "${BOLD}${CYAN}└──────────────────────────────────────────────────────────┘${NC}"

# SSH-VPN Installation
echo -e "\n${BOLD}[1/3] Installing SSH-VPN...${NC}"
show_progress 3
wget -q -O /root/ssh-vpn.sh "https://raw.githubusercontent.com/Mahboub-power-is-back/multiws/master/ssh/ssh-vpn.sh"
chmod +x /root/ssh-vpn.sh
run_with_progress "bash /root/ssh-vpn.sh" "Configuring SSH-VPN"
echo -e "${GREEN}✓ SSH-VPN installed${NC}"

# Xray Installation
echo -e "\n${BOLD}[2/3] Installing Xray...${NC}"
show_progress 5
wget -q -O /root/ins-xray.sh "https://raw.githubusercontent.com/Mahboub-power-is-back/multiws/master/xray/ins-xray.sh"
chmod +x /root/ins-xray.sh
run_with_progress "bash /root/ins-xray.sh" "Configuring Xray"
echo -e "${GREEN}✓ Xray installed${NC}"

# SSH Websocket Installation
echo -e "\n${BOLD}[3/3] Installing SSH Websocket...${NC}"
show_progress 4
wget -q -O /root/insshws.sh "https://raw.githubusercontent.com/Mahboub-power-is-back/multiws/refs/heads/master/sshws/insshws.sh"
chmod +x /root/insshws.sh
run_with_progress "bash /root/insshws.sh" "Configuring SSH Websocket"
echo -e "${GREEN}✓ SSH Websocket installed${NC}"

# ------------------------------
# DNSTT Installation
# ------------------------------
if [ -f /root/nsdomain ]; then
    DnsNS=$(cat /root/nsdomain)
    echo -e "\n${BOLD}Installing DNSTT Service...${NC}"
    
    echo -e "${CYAN}Downloading DNSTT server...${NC}"
    wget -q -c https://raw.githubusercontent.com/Mahboub-power-is-back/Myapp/refs/heads/main/dnstt-server -O /usr/local/bin/dnstt-server
    chmod +x /usr/local/bin/dnstt-server
    
    PORT1=443
    echo -e "${CYAN}Configuring DNSTT service on port $PORT1...${NC}"
    
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
    systemctl enable dnstt-service >/dev/null 2>&1
    
    echo -e "${GREEN}✓ DNSTT server started on TCP/UDP port $PORT1${NC}"
    echo -e "${CYAN}Using NS domain: $DnsNS${NC}"
else
    echo -e "${YELLOW}⚠ NS domain not found! Skipping DNSTT installation.${NC}"
fi

# ------------------------------
# Final Configuration
# ------------------------------
echo -e "\n${BOLD}Finalizing setup...${NC}"

# Setup .profile
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

# Log services & ports
LOG="/root/log-install.txt"
{
echo -e "\n${BOLD}${CYAN}┌───────────────────────────────────────────────────────────────┐${NC}"
echo -e "${BOLD}${CYAN}│                         SERVICE & PORTS                        │${NC}"
echo -e "${BOLD}${CYAN}└───────────────────────────────────────────────────────────────┘${NC}"
echo -e "${YELLOW}   - OpenSSH                  : 22${NC}"
echo -e "${YELLOW}   - OpenVPN                  : 1194${NC}"
echo -e "${YELLOW}   - SSH Websocket            : 80${NC}"
echo -e "${YELLOW}   - SSH SSL Websocket        : 443${NC}"
echo -e "${YELLOW}   - OVPN Websocket           : 80${NC}"
echo -e "${YELLOW}   - OVPN SSL Websocket       : 443${NC}"
echo -e "${YELLOW}   - Stunnel4                 : 222, 777${NC}"
echo -e "${YELLOW}   - Dropbear                 : 109, 143${NC}"
echo -e "${YELLOW}   - UDP CUSTOM               : 1-65535${NC}"
echo -e "${YELLOW}   - Badvpn                   : 7100-7900${NC}"
echo -e "${YELLOW}   - Nginx                    : 81${NC}"
echo -e "${YELLOW}   - Vmess WS TLS             : 443${NC}"
echo -e "${YELLOW}   - Vless WS TLS             : 443${NC}"
echo -e "${YELLOW}   - Trojan WS TLS            : 443${NC}"
echo -e "${YELLOW}   - Shadowsocks WS TLS       : 443${NC}"
echo -e "${YELLOW}   - Vmess WS none TLS        : 80${NC}"
echo -e "${YELLOW}   - Vless WS none TLS        : 80${NC}"
echo -e "${YELLOW}   - Trojan WS none TLS       : 80${NC}"
echo -e "${YELLOW}   - Shadowsocks WS none TLS  : 80${NC}"
echo -e "${YELLOW}   - Vmess gRPC               : 443${NC}"
echo -e "${YELLOW}   - Vless gRPC               : 443${NC}"
echo -e "${YELLOW}   - Trojan gRPC              : 443${NC}"
echo -e "${YELLOW}   - Shadowsocks gRPC         : 443${NC}"
[[ ! -z "$DnsNS" ]] && echo -e "${YELLOW}   - DNSTT Server             : 443${NC}"
echo ""
} > "$LOG"

# Fix permissions
chmod 644 /etc/systemd/system/ws-stunnel.service
chmod 644 /etc/systemd/system/ws-ovpn.service
chmod 644 /etc/systemd/system/ws-dropbear.service
chmod 644 /etc/systemd/system/xray.service

# Clear history
history -c

# ------------------------------
# Completion
# ------------------------------
echo -e "\n${BOLD}${GREEN}┌──────────────────────────────────────────────────────────┐${NC}"
echo -e "${BOLD}${GREEN}│          INSTALLATION COMPLETE SUCCESSFULLY!            │${NC}"
echo -e "${BOLD}${GREEN}└──────────────────────────────────────────────────────────┘${NC}"
echo -e "${CYAN}✓ All services installed and configured${NC}"
echo -e "${CYAN}✓ Domain: $SUB${NC}"
echo -e "${CYAN}✓ Server IP: $IP${NC}"
echo -e "${CYAN}✓ Installation log: /root/log-install.txt${NC}"
echo ""
echo -e "${YELLOW}⚠ The system will reboot in 10 seconds...${NC}"
echo -e "${YELLOW}⚠ Please wait for the system to come back online.${NC}"

# Countdown timer
for i in {10..1}; do
    echo -ne "\rRebooting in $i seconds... "
    sleep 1
done

# Cleanup and reboot
rm -f /root/setup.sh /root/ssh-vpn.sh /root/ins-xray.sh /root/insshws.sh
echo -e "\n${GREEN}Rebooting now!${NC}"
reboot
